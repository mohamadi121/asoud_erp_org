from __future__ import annotations

from typing import Any


def _treasury_account(name: str | None):
    import frappe

    if not name:
        return None
    return frappe.db.get_value(
        "ASOUD Treasury Account",
        name,
        [
            "name",
            "company",
            "branch",
            "treasury_type",
            "ledger_account",
            "floating_detail",
            "maximum_balance",
            "enabled",
            "custodian",
        ],
        as_dict=True,
    )


def _validate_context(doc) -> None:
    import frappe

    from asoud_core.permissions import can_access_context

    branch = doc.get("branch")
    if not can_access_context(frappe.session.user, doc.company, branch):
        frappe.throw("You do not have access to this treasury company and branch")
    branch_company = frappe.db.get_value("ASOUD Branch", branch, "company")
    if branch_company != doc.company:
        frappe.throw("Treasury branch does not belong to the selected company")


def _validate_account(account: str | None, company: str) -> None:
    import frappe

    row = frappe.db.get_value(
        "Account", account, ["company", "is_group"], as_dict=True
    )
    if not row or row.company != company or row.is_group:
        frappe.throw("Account must be a leaf account of the selected company")


def _validate_detail(detail: str | None, company: str) -> None:
    import frappe

    if detail and not frappe.db.exists(
        "ASOUD Floating Detail Company",
        {"parent": detail, "company": company, "enabled": 1},
    ):
        frappe.throw("Floating detail is not enabled for the selected company")


def ledger_balance(account: str, company: str, posting_date: str) -> float:
    import frappe
    from frappe.utils import flt

    result = frappe.db.sql(
        """
        select coalesce(sum(debit-credit), 0)
          from `tabGL Entry`
         where company=%s and account=%s and posting_date<=%s and is_cancelled=0
        """,
        (company, account, posting_date),
    )[0][0]
    return flt(result)


def _row(
    account: str,
    amount: float,
    *,
    debit: bool,
    detail: str | None = None,
    party_type: str | None = None,
    party: str | None = None,
) -> dict[str, Any]:
    values: dict[str, Any] = {
        "account": account,
        "debit_in_account_currency" if debit else "credit_in_account_currency": amount,
    }
    if detail:
        values["asoud_floating_detail"] = detail
    if party_type and party:
        values.update({"party_type": party_type, "party": party})
    return values


def create_journal(
    *,
    company: str,
    branch: str,
    posting_date: str,
    remark: str,
    rows: list[dict[str, Any]],
) -> str:
    import frappe

    existing = frappe.db.exists(
        "Journal Entry", {"company": company, "user_remark": remark, "docstatus": 1}
    )
    if existing:
        return existing
    entry = frappe.get_doc(
        {
            "doctype": "Journal Entry",
            "voucher_type": "Journal Entry",
            "company": company,
            "posting_date": posting_date,
            "asoud_branch": branch,
            "user_remark": remark,
            "accounts": rows,
        }
    ).insert(ignore_permissions=True)
    entry.submit()
    return entry.name


def cancel_linked_journal(journal_entry: str | None) -> None:
    import frappe

    if not journal_entry:
        return
    journal = frappe.get_doc("Journal Entry", journal_entry)
    if journal.docstatus == 1:
        journal.cancel()


def validate_treasury_transaction(doc) -> None:
    import frappe
    from frappe.utils import flt

    _validate_context(doc)
    if flt(doc.amount) <= 0:
        frappe.throw("Treasury transaction amount must be greater than zero")
    source = _treasury_account(doc.source_treasury_account)
    target = _treasury_account(doc.target_treasury_account)
    if doc.transaction_type == "Receipt":
        if not target or not doc.counter_account:
            frappe.throw("Receipt requires target treasury and counter account")
    elif doc.transaction_type == "Payment":
        if not source or not doc.counter_account:
            frappe.throw("Payment requires source treasury and counter account")
    else:
        if not source or not target or source.name == target.name:
            frappe.throw("Transfer requires two different treasury accounts")
        if doc.transaction_type == "Petty Cash Funding" and target.treasury_type != "Petty Cash":
            frappe.throw("Petty Cash Funding target must be a petty cash account")
    for treasury in (source, target):
        if treasury and (
            not treasury.enabled
            or treasury.company != doc.company
            or treasury.branch != doc.branch
        ):
            frappe.throw("Treasury account is disabled or outside the document context")
    if doc.counter_account:
        _validate_account(doc.counter_account, doc.company)
    _validate_detail(doc.counter_floating_detail, doc.company)
    if doc.party and not doc.party_type:
        frappe.throw("Party Type is required when Party is selected")
    if doc.party_type and doc.party and not frappe.db.exists(doc.party_type, doc.party):
        frappe.throw("Selected treasury party does not exist")
    if target and target.maximum_balance:
        projected = ledger_balance(target.ledger_account, doc.company, doc.posting_date) + flt(
            doc.amount
        )
        if projected > flt(target.maximum_balance):
            frappe.throw("Target treasury maximum balance would be exceeded")


def post_treasury_transaction(doc) -> str:
    source = _treasury_account(doc.source_treasury_account)
    target = _treasury_account(doc.target_treasury_account)
    if doc.transaction_type == "Receipt":
        rows = [
            _row(target.ledger_account, doc.amount, debit=True, detail=target.floating_detail),
            _row(
                doc.counter_account,
                doc.amount,
                debit=False,
                party_type=doc.party_type,
                party=doc.party,
                detail=doc.counter_floating_detail,
            ),
        ]
    elif doc.transaction_type == "Payment":
        rows = [
            _row(
                doc.counter_account,
                doc.amount,
                debit=True,
                party_type=doc.party_type,
                party=doc.party,
                detail=doc.counter_floating_detail,
            ),
            _row(source.ledger_account, doc.amount, debit=False, detail=source.floating_detail),
        ]
    else:
        rows = [
            _row(target.ledger_account, doc.amount, debit=True, detail=target.floating_detail),
            _row(source.ledger_account, doc.amount, debit=False, detail=source.floating_detail),
        ]
    return create_journal(
        company=doc.company,
        branch=doc.branch,
        posting_date=doc.posting_date,
        remark=f"ASOUD Treasury Transaction::{doc.name}",
        rows=rows,
    )


def validate_petty_cash_claim(doc) -> None:
    import frappe
    from frappe.utils import flt

    _validate_context(doc)
    treasury = _treasury_account(doc.petty_cash_account)
    if (
        not treasury
        or not treasury.enabled
        or treasury.treasury_type != "Petty Cash"
        or treasury.company != doc.company
        or treasury.branch != doc.branch
    ):
        frappe.throw("Petty cash account is not valid for this company and branch")
    if treasury.custodian and treasury.custodian != doc.custodian:
        frappe.throw("Claim custodian must match the petty cash custodian")
    total = 0.0
    for expense in doc.expenses:
        _validate_account(expense.expense_account, doc.company)
        _validate_detail(expense.floating_detail, doc.company)
        if flt(expense.amount) <= 0:
            frappe.throw("Every petty cash expense amount must be greater than zero")
        total += flt(expense.amount)
    if not total:
        frappe.throw("At least one petty cash expense is required")
    doc.total_amount = total
    if total > ledger_balance(treasury.ledger_account, doc.company, doc.posting_date):
        frappe.throw("Petty cash balance is insufficient for this claim")


def post_petty_cash_claim(doc) -> str:
    treasury = _treasury_account(doc.petty_cash_account)
    rows = [
        _row(
            expense.expense_account,
            expense.amount,
            debit=True,
            detail=expense.floating_detail or treasury.floating_detail,
        )
        for expense in doc.expenses
    ]
    rows.append(
        _row(
            treasury.ledger_account,
            doc.total_amount,
            debit=False,
            detail=treasury.floating_detail,
        )
    )
    return create_journal(
        company=doc.company,
        branch=doc.branch,
        posting_date=doc.posting_date,
        remark=f"ASOUD Petty Cash Claim::{doc.name}",
        rows=rows,
    )


def validate_cheque(doc) -> None:
    import frappe

    _validate_context(doc)
    expected_party = "Customer" if doc.cheque_type == "Incoming" else "Supplier"
    if doc.party_type != expected_party:
        frappe.throw(f"{doc.cheque_type} cheque party type must be {expected_party}")
    if not frappe.db.exists(doc.party_type, doc.party):
        frappe.throw("Cheque party does not exist")
    for account in (doc.party_account, doc.cheque_account):
        _validate_account(account, doc.company)
    bank = _treasury_account(doc.bank_treasury_account)
    if (
        not bank
        or not bank.enabled
        or bank.treasury_type != "Bank"
        or bank.company != doc.company
        or bank.branch != doc.branch
    ):
        frappe.throw("Cheque Bank Treasury Account is invalid")
    _validate_detail(doc.floating_detail, doc.company)
    if not doc.is_new():
        previous = frappe.db.get_value(
            "ASOUD Cheque", doc.name, ["amount", "company", "cheque_type"], as_dict=True
        )
        if previous and doc.current_status != "Draft" and (
            previous.amount != doc.amount
            or previous.company != doc.company
            or previous.cheque_type != doc.cheque_type
        ):
            frappe.throw("Posted cheque identity and amount are immutable")


INCOMING_TRANSITIONS = {
    ("Draft", "Received"),
    ("Received", "Deposited"),
    ("Received", "Cleared"),
    ("Deposited", "Cleared"),
    ("Received", "Returned"),
    ("Deposited", "Returned"),
    ("Returned", "Received"),
    ("Received", "Cancelled"),
}
OUTGOING_TRANSITIONS = {
    ("Draft", "Issued"),
    ("Issued", "Cleared"),
    ("Issued", "Cancelled"),
}


def transition_cheque(
    cheque_name: str,
    target_status: str,
    event_date: str,
    reason: str,
) -> str:
    import frappe

    frappe.only_for(("Accounts Manager", "System Manager"))
    frappe.db.sql("select name from `tabASOUD Cheque` where name=%s for update", cheque_name)
    cheque = frappe.get_doc("ASOUD Cheque", cheque_name)
    _validate_context(cheque)
    if cheque.current_status == target_status and cheque.last_event:
        return cheque.last_event
    allowed = INCOMING_TRANSITIONS if cheque.cheque_type == "Incoming" else OUTGOING_TRANSITIONS
    transition = (cheque.current_status, target_status)
    if transition not in allowed:
        frappe.throw(f"Invalid cheque transition: {transition[0]} -> {transition[1]}")
    journal = _post_cheque_transition(cheque, target_status, event_date)
    frappe.flags.asoud_cheque_transition = True
    try:
        event = frappe.get_doc(
            {
                "doctype": "ASOUD Cheque Event",
                "cheque": cheque.name,
                "company": cheque.company,
                "branch": cheque.branch,
                "event_date": event_date,
                "from_status": cheque.current_status,
                "to_status": target_status,
                "reason": reason,
                "journal_entry": journal,
            }
        ).insert(ignore_permissions=True)
    finally:
        frappe.flags.asoud_cheque_transition = False
    frappe.db.set_value(
        "ASOUD Cheque",
        cheque.name,
        {"current_status": target_status, "last_event": event.name},
    )
    return event.name


def _post_cheque_transition(cheque, target_status: str, event_date: str) -> str | None:
    bank = _treasury_account(cheque.bank_treasury_account)
    transition = (cheque.current_status, target_status)
    debit: tuple[str, str | None, str | None]
    credit: tuple[str, str | None, str | None]
    if cheque.cheque_type == "Incoming":
        if transition in {("Draft", "Received"), ("Returned", "Received")}:
            debit = (cheque.cheque_account, None, None)
            credit = (cheque.party_account, cheque.party_type, cheque.party)
        elif target_status == "Cleared":
            debit = (bank.ledger_account, None, None)
            credit = (cheque.cheque_account, None, None)
        elif target_status in {"Returned", "Cancelled"}:
            debit = (cheque.party_account, cheque.party_type, cheque.party)
            credit = (cheque.cheque_account, None, None)
        else:
            return None
    else:
        if transition == ("Draft", "Issued"):
            debit = (cheque.party_account, cheque.party_type, cheque.party)
            credit = (cheque.cheque_account, None, None)
        elif target_status == "Cleared":
            debit = (cheque.cheque_account, None, None)
            credit = (bank.ledger_account, None, None)
        else:
            debit = (cheque.cheque_account, None, None)
            credit = (cheque.party_account, cheque.party_type, cheque.party)
    rows = [
        _row(
            debit[0],
            cheque.amount,
            debit=True,
            party_type=debit[1],
            party=debit[2],
            detail=bank.floating_detail if debit[0] == bank.ledger_account else cheque.floating_detail,
        ),
        _row(
            credit[0],
            cheque.amount,
            debit=False,
            party_type=credit[1],
            party=credit[2],
            detail=bank.floating_detail if credit[0] == bank.ledger_account else cheque.floating_detail,
        ),
    ]
    return create_journal(
        company=cheque.company,
        branch=cheque.branch,
        posting_date=event_date,
        remark=f"ASOUD Cheque::{cheque.name}::{cheque.current_status}->{target_status}",
        rows=rows,
    )


def validate_cash_count(doc) -> None:
    import frappe
    from frappe.utils import flt

    _validate_context(doc)
    treasury = _treasury_account(doc.treasury_account)
    if (
        not treasury
        or treasury.treasury_type not in {"Cash", "Petty Cash"}
        or treasury.company != doc.company
        or treasury.branch != doc.branch
    ):
        frappe.throw("Cash count treasury account is invalid")
    doc.system_balance = ledger_balance(treasury.ledger_account, doc.company, doc.count_date)
    doc.difference = flt(doc.counted_balance) - flt(doc.system_balance)
    if doc.difference and not doc.difference_account:
        frappe.throw("Difference Account is required for a cash count difference")
    if doc.difference_account:
        _validate_account(doc.difference_account, doc.company)
    _validate_detail(doc.floating_detail, doc.company)


def post_cash_count(doc) -> str | None:
    if not doc.difference:
        return None
    treasury = _treasury_account(doc.treasury_account)
    positive = doc.difference > 0
    amount = abs(doc.difference)
    rows = [
        _row(
            treasury.ledger_account if positive else doc.difference_account,
            amount,
            debit=True,
            detail=treasury.floating_detail if positive else doc.floating_detail,
        ),
        _row(
            doc.difference_account if positive else treasury.ledger_account,
            amount,
            debit=False,
            detail=doc.floating_detail if positive else treasury.floating_detail,
        ),
    ]
    return create_journal(
        company=doc.company,
        branch=doc.branch,
        posting_date=doc.count_date,
        remark=f"ASOUD Cash Count::{doc.name}",
        rows=rows,
    )


def validate_bank_reconciliation(doc) -> None:
    import frappe
    from frappe.utils import flt

    _validate_context(doc)
    treasury = _treasury_account(doc.treasury_account)
    if (
        not treasury
        or treasury.treasury_type != "Bank"
        or treasury.company != doc.company
        or treasury.branch != doc.branch
    ):
        frappe.throw("Bank reconciliation requires a Bank treasury account")
    if doc.from_date > doc.to_date:
        frappe.throw("Bank reconciliation From Date cannot be after To Date")
    doc.system_balance = ledger_balance(treasury.ledger_account, doc.company, doc.to_date)
    doc.difference = flt(doc.statement_balance) - flt(doc.system_balance)
