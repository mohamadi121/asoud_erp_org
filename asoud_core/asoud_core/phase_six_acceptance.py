from __future__ import annotations

from asoud_core.phase_five_acceptance import CUSTOMER, SUPPLIER
from asoud_core.phase_one_demo import (
    COMPANY_A,
    HOLDING_CODE,
    USERS,
    ensure_phase_one_demo,
)

POSTING_DATE = "2027-05-10"


def _account(code: str) -> str:
    import frappe

    account = frappe.db.get_value(
        "Account", {"company": COMPANY_A, "account_number": code}, "name"
    )
    if not account:
        raise AssertionError(f"Phase-six account {code} is missing")
    return account


def _ensure_treasury_ledger(
    code: str, title: str, account_type: str
) -> str:
    import frappe

    existing = frappe.db.get_value(
        "Account", {"company": COMPANY_A, "account_number": code}, "name"
    )
    if existing:
        return existing
    parent = _account("111000")
    return frappe.get_doc(
        {
            "doctype": "Account",
            "account_name": title,
            "account_number": code,
            "parent_account": parent,
            "company": COMPANY_A,
            "root_type": "Asset",
            "report_type": "Balance Sheet",
            "account_type": account_type,
            "is_group": 0,
        }
    ).insert(ignore_permissions=True).name


def _detail(detail_type: str = "Other") -> str:
    import frappe

    matches = frappe.db.sql(
        """
        select fdc.parent
          from `tabASOUD Floating Detail Company` fdc
          join `tabASOUD Floating Detail` fd on fd.name=fdc.parent
         where fdc.company=%s
           and fdc.enabled=1
           and fd.enabled=1
           and fd.detail_type=%s
         order by fd.creation
         limit 1
        """,
        (COMPANY_A, detail_type),
    )
    if matches:
        return matches[0][0]

    title = f"Phase Six {detail_type}"
    existing = frappe.db.exists(
        "ASOUD Floating Detail",
        {"holding": HOLDING_CODE, "detail_title": title},
    )
    if existing:
        doc = frappe.get_doc("ASOUD Floating Detail", existing)
        doc.enabled = 1
        doc.detail_type = detail_type
        if not any(row.company == COMPANY_A for row in doc.company_codes):
            doc.append(
                "company_codes",
                {
                    "company": COMPANY_A,
                    "detail_code": f"P6-{detail_type[:3].upper()}",
                    "enabled": 1,
                },
            )
        else:
            for row in doc.company_codes:
                if row.company == COMPANY_A:
                    row.enabled = 1
        doc.save(ignore_permissions=True)
        return doc.name

    return (
        frappe.get_doc(
            {
                "doctype": "ASOUD Floating Detail",
                "detail_title": title,
                "holding": HOLDING_CODE,
                "detail_type": detail_type,
                "enabled": 1,
                "company_codes": [
                    {
                        "company": COMPANY_A,
                        "detail_code": f"P6-{detail_type[:3].upper()}",
                        "enabled": 1,
                    }
                ],
            }
        )
        .insert(ignore_permissions=True)
        .name
    )


def _ensure_detail_rule(account: str, detail: str) -> None:
    import frappe

    detail_type = frappe.db.get_value("ASOUD Floating Detail", detail, "detail_type")
    existing = frappe.db.exists(
        "ASOUD Account Detail Rule",
        {"company": COMPANY_A, "account": account, "detail_type": detail_type},
    )
    if existing:
        return
    frappe.get_doc(
        {
            "doctype": "ASOUD Account Detail Rule",
            "company": COMPANY_A,
            "account": account,
            "detail_type": detail_type,
            "required": 1,
            "enabled": 1,
        }
    ).insert(ignore_permissions=True)


def _branch() -> str:
    import frappe

    branch = frappe.db.get_value(
        "ASOUD Branch", {"company": COMPANY_A, "branch_code": "HQ", "enabled": 1}, "name"
    )
    if not branch:
        raise AssertionError("Phase-six HQ branch is missing")
    return branch


def _ensure_treasury_account(
    code: str,
    title: str,
    treasury_type: str,
    ledger_account: str,
    branch: str,
    detail: str,
    *,
    custodian: str | None = None,
    maximum_balance: int = 0,
) -> str:
    import frappe

    key = f"{COMPANY_A}|{branch}|{code}"
    if not frappe.db.exists("ASOUD Treasury Account", key):
        frappe.get_doc(
            {
                "doctype": "ASOUD Treasury Account",
                "account_title": title,
                "account_code": code,
                "treasury_type": treasury_type,
                "company": COMPANY_A,
                "branch": branch,
                "ledger_account": ledger_account,
                "custodian": custodian,
                "floating_detail": detail,
                "maximum_balance": maximum_balance,
                "enabled": 1,
            }
        ).insert(ignore_permissions=True)
    return key


def _ensure_transaction(
    marker: str,
    transaction_type: str,
    branch: str,
    amount: int,
    *,
    source: str | None = None,
    target: str | None = None,
    counter_account: str | None = None,
) -> str:
    import frappe

    existing = frappe.db.exists(
        "ASOUD Treasury Transaction", {"remarks": marker, "docstatus": 1}
    )
    if existing:
        return existing
    transaction = frappe.get_doc(
        {
            "doctype": "ASOUD Treasury Transaction",
            "transaction_type": transaction_type,
            "company": COMPANY_A,
            "branch": branch,
            "posting_date": POSTING_DATE,
            "source_treasury_account": source,
            "target_treasury_account": target,
            "counter_account": counter_account,
            "amount": amount,
            "reference_no": marker,
            "remarks": marker,
        }
    ).insert(ignore_permissions=True)
    transaction.submit()
    return transaction.name


def _ensure_claim(petty: str, branch: str, detail: str) -> str:
    import frappe

    marker = "ASOUD-P6-PETTY-CLAIM"
    existing = frappe.db.exists(
        "ASOUD Petty Cash Claim", {"remarks": marker, "docstatus": 1}
    )
    if existing:
        return existing
    claim = frappe.get_doc(
        {
            "doctype": "ASOUD Petty Cash Claim",
            "company": COMPANY_A,
            "branch": branch,
            "petty_cash_account": petty,
            "custodian": USERS["company_manager"],
            "posting_date": POSTING_DATE,
            "remarks": marker,
            "expenses": [
                {
                    "expense_date": POSTING_DATE,
                    "expense_account": _account("530002"),
                    "floating_detail": detail,
                    "description": "Phase-six controlled rent receipt",
                    "amount": 700,
                    "receipt_no": "P6-R-001",
                },
                {
                    "expense_date": POSTING_DATE,
                    "expense_account": _account("530003"),
                    "floating_detail": detail,
                    "description": "Phase-six controlled utility receipt",
                    "amount": 300,
                    "receipt_no": "P6-R-002",
                },
            ],
        }
    ).insert(ignore_permissions=True)
    claim.submit()
    return claim.name


def _ensure_cheque(
    cheque_type: str,
    number: str,
    branch: str,
    bank: str,
    detail: str,
    *,
    amount: int,
) -> str:
    import frappe

    key = f"{COMPANY_A}|{cheque_type}|ASOUD Test Bank|{number}"
    if frappe.db.exists("ASOUD Cheque", key):
        return key
    incoming = cheque_type == "Incoming"
    return frappe.get_doc(
        {
            "doctype": "ASOUD Cheque",
            "cheque_type": cheque_type,
            "company": COMPANY_A,
            "branch": branch,
            "cheque_number": number,
            "bank_name": "ASOUD Test Bank",
            "account_number": "CONTROLLED",
            "due_date": "2027-05-20",
            "amount": amount,
            "party_type": "Customer" if incoming else "Supplier",
            "party": CUSTOMER if incoming else SUPPLIER,
            "party_account": _account("112001") if incoming else _account("211001"),
            "cheque_account": _account("112002") if incoming else _account("211002"),
            "bank_treasury_account": bank,
            "floating_detail": detail,
            "remarks": f"Phase-six {cheque_type.lower()} cheque",
        }
    ).insert(ignore_permissions=True).name


def _advance_cheque(cheque_name: str, targets: tuple[str, ...]) -> list[str]:
    import frappe

    from asoud_core.services.treasury import transition_cheque

    events = frappe.get_all(
        "ASOUD Cheque Event",
        filters={"cheque": cheque_name},
        fields=["name", "to_status"],
        order_by="creation",
    )
    completed = {row.to_status for row in events}
    names = [row.name for row in events]
    current = frappe.db.get_value("ASOUD Cheque", cheque_name, "current_status")
    if current in {"Cleared", "Cancelled"}:
        return names
    for target in targets:
        current = frappe.db.get_value("ASOUD Cheque", cheque_name, "current_status")
        if current == target or target in completed and target in {"Returned"}:
            continue
        names.append(
            transition_cheque(
                cheque_name,
                target,
                POSTING_DATE,
                f"Phase-six controlled transition to {target}",
            )
        )
    return names


def _ensure_cash_count(cash: str, branch: str, detail: str) -> str:
    import frappe

    from asoud_core.services.treasury import ledger_balance

    marker = "ASOUD-P6-CASH-COUNT"
    existing = frappe.db.exists(
        "ASOUD Cash Count", {"remarks": marker, "docstatus": 1}
    )
    if existing:
        return existing
    ledger = frappe.db.get_value("ASOUD Treasury Account", cash, "ledger_account")
    system_balance = ledger_balance(ledger, COMPANY_A, POSTING_DATE)
    count = frappe.get_doc(
        {
            "doctype": "ASOUD Cash Count",
            "company": COMPANY_A,
            "branch": branch,
            "treasury_account": cash,
            "count_date": POSTING_DATE,
            "counted_balance": system_balance - 100,
            "difference_account": _account("530004"),
            "floating_detail": detail,
            "remarks": marker,
        }
    ).insert(ignore_permissions=True)
    count.submit()
    return count.name


def _ensure_bank_reconciliation(bank: str, branch: str) -> str:
    import frappe

    from asoud_core.services.treasury import ledger_balance

    reference = "ASOUD-P6-BANK-STATEMENT"
    existing = frappe.db.exists(
        "ASOUD Bank Reconciliation", {"reference": reference, "docstatus": 1}
    )
    if existing:
        return existing
    ledger = frappe.db.get_value("ASOUD Treasury Account", bank, "ledger_account")
    balance = ledger_balance(ledger, COMPANY_A, POSTING_DATE)
    reconciliation = frappe.get_doc(
        {
            "doctype": "ASOUD Bank Reconciliation",
            "company": COMPANY_A,
            "branch": branch,
            "treasury_account": bank,
            "from_date": POSTING_DATE,
            "to_date": POSTING_DATE,
            "statement_balance": balance,
            "reference": reference,
            "remarks": "Phase-six exact bank statement control",
        }
    ).insert(ignore_permissions=True)
    reconciliation.submit()
    return reconciliation.name


def _assert_gl_balanced(journals: list[str]) -> None:
    import frappe

    for journal in journals:
        debit, credit = frappe.db.sql(
            """
            select coalesce(sum(debit), 0), coalesce(sum(credit), 0)
              from `tabGL Entry`
             where voucher_type='Journal Entry' and voucher_no=%s and is_cancelled=0
            """,
            journal,
        )[0]
        if round(float(debit), 2) != round(float(credit), 2):
            raise AssertionError(f"Unbalanced phase-six journal: {journal}")


def _assert_invalid_transition(cheque: str) -> None:
    import frappe

    from asoud_core.services.treasury import transition_cheque

    current = frappe.db.get_value("ASOUD Cheque", cheque, "current_status")
    if current != "Draft":
        return
    try:
        transition_cheque(cheque, "Cleared", POSTING_DATE, "Must fail")
    except frappe.ValidationError:
        return
    raise AssertionError("Invalid cheque transition was accepted")


def run_phase_six_acceptance() -> dict:
    import frappe

    frappe.only_for("System Manager")
    ensure_phase_one_demo()
    frappe.set_user("Administrator")
    branch = _branch()
    detail = _detail()
    cost_detail = _detail("Cost Center")
    customer_detail = _detail("Customer")
    supplier_detail = _detail("Supplier")
    bank_ledger = _ensure_treasury_ledger("111101", "Phase Six Bank", "Bank")
    cash_ledger = _ensure_treasury_ledger("111102", "Phase Six Cash", "Cash")
    petty_ledger = _ensure_treasury_ledger("111103", "Phase Six Petty Cash", "Cash")
    for ledger in (bank_ledger, cash_ledger, petty_ledger):
        _ensure_detail_rule(ledger, detail)
    bank = _ensure_treasury_account(
        "P6-BANK",
        "Phase Six Bank",
        "Bank",
        bank_ledger,
        branch,
        detail,
    )
    cash = _ensure_treasury_account(
        "P6-CASH",
        "Phase Six Cash",
        "Cash",
        cash_ledger,
        branch,
        detail,
        maximum_balance=50_000,
    )
    petty = _ensure_treasury_account(
        "P6-PETTY",
        "Phase Six Petty Cash",
        "Petty Cash",
        petty_ledger,
        branch,
        detail,
        custodian=USERS["company_manager"],
        maximum_balance=10_000,
    )

    seed = _ensure_transaction(
        "ASOUD-P6-BANK-SEED",
        "Receipt",
        branch,
        100_000,
        target=bank,
        counter_account=_account("310001"),
    )
    cash_transfer = _ensure_transaction(
        "ASOUD-P6-BANK-TO-CASH",
        "Transfer",
        branch,
        20_000,
        source=bank,
        target=cash,
    )
    petty_funding = _ensure_transaction(
        "ASOUD-P6-PETTY-FUNDING",
        "Petty Cash Funding",
        branch,
        5_000,
        source=cash,
        target=petty,
    )
    claim = _ensure_claim(petty, branch, cost_detail)

    incoming = _ensure_cheque(
        "Incoming", "P6-IN-001", branch, bank, customer_detail, amount=8_000
    )
    _assert_invalid_transition(incoming)
    incoming_events = _advance_cheque(incoming, ("Received", "Deposited", "Cleared"))
    returned = _ensure_cheque(
        "Incoming", "P6-IN-002", branch, bank, customer_detail, amount=2_000
    )
    returned_events = _advance_cheque(
        returned, ("Received", "Returned", "Received", "Cleared")
    )
    outgoing = _ensure_cheque(
        "Outgoing", "P6-OUT-001", branch, bank, supplier_detail, amount=3_000
    )
    outgoing_events = _advance_cheque(outgoing, ("Issued", "Cleared"))

    cash_count = _ensure_cash_count(cash, branch, cost_detail)
    reconciliation = _ensure_bank_reconciliation(bank, branch)
    if frappe.db.get_value(
        "ASOUD Bank Reconciliation", reconciliation, ["difference", "status"], as_dict=True
    ) != {"difference": 0.0, "status": "Reconciled"}:
        row = frappe.db.get_value(
            "ASOUD Bank Reconciliation",
            reconciliation,
            ["difference", "status"],
            as_dict=True,
        )
        if float(row.difference or 0) != 0 or row.status != "Reconciled":
            raise AssertionError("Exact bank reconciliation was not accepted")

    sources = [seed, cash_transfer, petty_funding, claim, cash_count]
    journals = [
        frappe.db.get_value(doctype, name, "journal_entry")
        for doctype, name in (
            ("ASOUD Treasury Transaction", seed),
            ("ASOUD Treasury Transaction", cash_transfer),
            ("ASOUD Treasury Transaction", petty_funding),
            ("ASOUD Petty Cash Claim", claim),
            ("ASOUD Cash Count", cash_count),
        )
    ]
    event_names = incoming_events + returned_events + outgoing_events
    journals.extend(
        frappe.get_all(
            "ASOUD Cheque Event",
            filters={"name": ["in", event_names], "journal_entry": ["is", "set"]},
            pluck="journal_entry",
        )
    )
    _assert_gl_balanced([journal for journal in journals if journal])
    if any(
        not frappe.db.exists("ASOUD Accounting Document", {"source_name": journal})
        for journal in journals
        if journal
    ):
        raise AssertionError("Treasury journals are missing from the accounting registry")
    if frappe.db.get_value("ASOUD Petty Cash Claim", claim, "total_amount") != 1000:
        raise AssertionError("Petty cash claim total is incorrect")
    if frappe.db.get_value("ASOUD Cash Count", cash_count, "difference") != -100:
        raise AssertionError("Cash count difference is incorrect")
    frappe.db.commit()
    return {
        "status": "passed",
        "treasury_accounts": [bank, cash, petty],
        "transactions": sources[:3],
        "petty_cash_claim": claim,
        "cheques": {
            "incoming_cleared": incoming,
            "incoming_returned_and_recovered": returned,
            "outgoing_cleared": outgoing,
            "events": len(event_names),
        },
        "cash_count": cash_count,
        "bank_reconciliation": reconciliation,
        "balanced_journals": len([journal for journal in journals if journal]),
        "registry": "passed",
    }
