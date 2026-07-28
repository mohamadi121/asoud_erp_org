from __future__ import annotations

import json
from decimal import Decimal

from asoud_iran.closing_opening.engine import AccountBalance, AccountKind, FiscalClosingEngine


class ClosingAdapterError(ValueError):
    pass


def _trial_balance(company: str, closing_date) -> list[AccountBalance]:
    import frappe

    rows = frappe.db.sql(
        """
        select gle.account, acc.root_type, gle.party_type, gle.party,
               gle.cost_center, gle.project, gle.finance_book,
               gle.asoud_branch, gle.asoud_floating_detail,
               sum(gle.debit - gle.credit) as balance
          from `tabGL Entry` gle
          join `tabAccount` acc on acc.name=gle.account
         where gle.company=%s and gle.posting_date<=%s and gle.is_cancelled=0
           and acc.is_group=0
         group by gle.account, acc.root_type, gle.party_type, gle.party,
                  gle.cost_center, gle.project, gle.finance_book,
                  gle.asoud_branch, gle.asoud_floating_detail
        having abs(sum(gle.debit - gle.credit)) > 0.000001
         order by gle.account, gle.party_type, gle.party, gle.cost_center,
                  gle.project, gle.finance_book, gle.asoud_branch,
                  gle.asoud_floating_detail
        """,
        (company, closing_date),
        as_dict=True,
    )
    kinds = {"Income": AccountKind.REVENUE, "Expense": AccountKind.EXPENSE}
    return [
        AccountBalance(
            account=row.account,
            kind=kinds.get(row.root_type, AccountKind.PERMANENT),
            balance=Decimal(str(row.balance)),
            party_type=row.party_type,
            party=row.party,
            cost_center=row.cost_center,
            project=row.project,
            finance_book=row.finance_book,
            branch=row.asoud_branch,
            floating_detail=row.asoud_floating_detail,
        )
        for row in rows
    ]


def preflight(run_name: str, *, persist: bool = True) -> dict:
    """Return deterministic blockers/warnings without creating ledger entries."""
    import frappe
    from erpnext.accounts.utils import get_fiscal_year

    run = frappe.get_doc("ASOUD Closing Run", run_name)
    run.check_permission("read")
    if run.status == "Completed" and run.preflight_report:
        # The historical preflight is part of the legal run evidence. A fresh
        # trial balance after closing is expected to differ and must not replace it.
        return json.loads(run.preflight_report)
    blockers: list[dict[str, str]] = []
    warnings: list[dict[str, str]] = []

    next_year = get_fiscal_year(run.opening_date, company=run.company)
    if not next_year:
        blockers.append({"code": "NEXT_FISCAL_YEAR", "message": "No fiscal year covers the opening date"})
    drafts = []
    for doctype in ("Journal Entry", "Sales Invoice", "Purchase Invoice", "Payment Entry", "Stock Entry"):
        date_field = "transaction_date" if doctype == "Stock Entry" else "posting_date"
        if frappe.db.has_column(doctype, date_field):
            name = frappe.db.get_value(
                doctype,
                {"company": run.company, date_field: ["<=", run.closing_date], "docstatus": 0},
                "name",
            )
            if name:
                drafts.append(f"{doctype}: {name}")
    if drafts:
        blockers.append({"code": "DRAFT_DOCUMENTS", "message": "; ".join(drafts)})

    unnumbered = frappe.db.get_value(
        "ASOUD Accounting Document",
        {
            "company": run.company,
            "posting_date": ["<=", run.closing_date],
            "numbering_status": "Temporary",
        },
        "name",
    )
    if unnumbered:
        blockers.append(
            {"code": "UNFINALIZED_NUMBERING", "message": f"Accounting registry row {unnumbered} is not final"}
        )
    balances = _trial_balance(run.company, run.closing_date)
    total = sum((row.balance for row in balances), Decimal("0"))
    if abs(total) > Decimal("0.000001"):
        blockers.append({"code": "UNBALANCED_LEDGER", "message": f"Trial balance difference is {total}"})

    reserved = {
        run.retained_earnings_account,
        run.closing_control_account,
        run.opening_control_account,
    }
    if any(row.account in {run.closing_control_account, run.opening_control_account} for row in balances):
        blockers.append(
            {"code": "CONTROL_ACCOUNT_BALANCE", "message": "Opening/closing control accounts must be zero before the run"}
        )
    if len(reserved) != 3:
        blockers.append({"code": "CONTROL_ACCOUNTS", "message": "Control accounts must be distinct"})

    party_count = len([row for row in balances if row.party])
    dimension_count = len(
        [row for row in balances if row.cost_center or row.project or row.finance_book or row.branch or row.floating_detail]
    )
    report = {
        "passed": not blockers,
        "blockers": blockers,
        "warnings": warnings,
        "balance_row_count": len(balances),
        "party_balance_count": party_count,
        "dimension_balance_count": dimension_count,
        "next_fiscal_year": next_year[0] if next_year else None,
    }
    if persist and run.docstatus == 1:
        run.db_set(
            {
                "preflight_status": "Passed" if report["passed"] else "Failed",
                "preflight_report": json.dumps(report, ensure_ascii=False, default=str),
                "status": "Preflight Passed" if report["passed"] else "Failed",
            }
        )
    return report


def _journal_entry(run, voucher, posting_date, entry_kind: str):
    import frappe

    accounts = []
    default_cost_center = frappe.db.get_value("Company", run.company, "cost_center")
    for line in voucher.lines:
        root_type = frappe.db.get_value("Account", line.account, "root_type")
        accounts.append(
            {
                "account": line.account,
                "party_type": line.party_type,
                "party": line.party,
                "debit_in_account_currency": line.debit,
                "credit_in_account_currency": line.credit,
                "cost_center": line.cost_center
                or (default_cost_center if root_type in {"Income", "Expense"} else None),
                "project": line.project,
                "finance_book": line.finance_book,
                "asoud_branch": line.branch,
                "asoud_floating_detail": line.floating_detail,
            }
        )
    branches = {line.branch for line in voucher.lines if line.branch}
    return frappe.get_doc(
        {
            "doctype": "Journal Entry",
            "voucher_type": "Journal Entry",
            "company": run.company,
            "posting_date": posting_date,
            "asoud_branch": branches.pop() if len(branches) == 1 else None,
            "user_remark": f"Generated by fiscal closing run {run.name}",
            "asoud_closing_run": run.name,
            "asoud_entry_kind": entry_kind,
            "accounts": accounts,
        }
    )


def _reuse_or_create(run, voucher, posting_date, kind, fieldname):
    import frappe

    existing = run.get(fieldname)
    if existing:
        doc = frappe.get_doc("Journal Entry", existing)
        if doc.docstatus == 2:
            raise ClosingAdapterError(f"Generated voucher {existing} is cancelled")
        if doc.docstatus == 0:
            doc.submit()
        if not frappe.db.exists(
            "ASOUD Accounting Document", {"source_key": f"Journal Entry::{doc.name}"}
        ):
            from asoud_core.services.journal_numbering import backfill_submitted_document

            backfill_submitted_document("Journal Entry", doc.name)
        return doc.name
    if voucher is None:
        return None
    doc = _journal_entry(run, voucher, posting_date, kind)
    doc.insert()
    doc.submit()
    run.db_set(fieldname, doc.name)
    return doc.name


def _reconciliation(result, *, closing_control_account: str, opening_control_account: str) -> dict:
    excluded = {closing_control_account, opening_control_account}
    close = {}
    opening = {}
    if result.permanent_closing:
        close = {
            line.identity: str(line.signed_effect)
            for line in result.permanent_closing.lines
            if line.account not in excluded
        }
    if result.opening:
        opening = {
            line.identity: str(line.signed_effect)
            for line in result.opening.lines
            if line.account not in excluded
        }
    differences = {
        "|".join(key): str(Decimal(value) + Decimal(opening.get(key, "0")))
        for key, value in close.items()
        if Decimal(value) + Decimal(opening.get(key, "0")) != 0
    }
    return {
        "passed": not differences and set(close) == set(opening),
        "closing_row_count": len(close),
        "opening_row_count": len(opening),
        "differences": differences,
    }


def execute(run_name: str) -> dict[str, str | None]:
    """Create actual vouchers exactly once and reconcile their dimensional keys."""
    import frappe

    frappe.db.sql("select name from `tabASOUD Closing Run` where name=%s for update", run_name)
    run = frappe.get_doc("ASOUD Closing Run", run_name)
    run.check_permission("submit")
    if run.docstatus != 1:
        raise ClosingAdapterError("The closing run must be submitted before execution")
    if run.status == "Completed" and run.reconciliation_status == "Passed":
        return {
            "profit_loss_journal_entry": run.profit_loss_journal_entry,
            "permanent_closing_journal_entry": run.permanent_closing_journal_entry,
            "opening_journal_entry": run.opening_journal_entry,
        }
    report = preflight(run_name)
    if not report["passed"]:
        raise ClosingAdapterError("Closing preflight failed: " + "; ".join(x["message"] for x in report["blockers"]))

    run.reload()
    run.db_set({"status": "Running", "attempt_count": (run.attempt_count or 0) + 1})
    balances = _trial_balance(run.company, run.closing_date)
    result = FiscalClosingEngine.generate(
        balances,
        batch_key=run.name,
        retained_earnings_account=run.retained_earnings_account,
        closing_control_account=run.closing_control_account,
        opening_control_account=run.opening_control_account,
    )
    specs = (
        (result.profit_loss_closing, run.closing_date, "Profit and Loss Closing", "profit_loss_journal_entry"),
        (result.permanent_closing, run.closing_date, "Permanent Closing", "permanent_closing_journal_entry"),
        (result.opening, run.opening_date, "Opening", "opening_journal_entry"),
    )
    created = {
        fieldname: _reuse_or_create(run, voucher, posting_date, kind, fieldname)
        for voucher, posting_date, kind, fieldname in specs
    }
    # Closing and opening vouchers are real legal documents and receive their
    # company-wide final numbers in their respective fiscal years.
    from erpnext.accounts.utils import get_fiscal_year
    from asoud_core.services.journal_numbering import run_final_numbering

    run_final_numbering(
        company=run.company,
        fiscal_year=run.fiscal_year,
        from_date=str(run.closing_date),
        to_date=str(run.closing_date),
        reason=f"Fiscal closing {run.name}",
    )
    opening_year = get_fiscal_year(run.opening_date, company=run.company)[0]
    run_final_numbering(
        company=run.company,
        fiscal_year=opening_year,
        from_date=str(run.opening_date),
        to_date=str(run.opening_date),
        reason=f"Fiscal opening {run.name}",
    )
    reconciliation = _reconciliation(
        result,
        closing_control_account=run.closing_control_account,
        opening_control_account=run.opening_control_account,
    )
    if not reconciliation["passed"]:
        raise ClosingAdapterError("Closing/opening dimensional reconciliation failed")
    run.db_set(
        {
            **created,
            "status": "Completed",
            "closing_profit": result.closing_profit,
            "reconciliation_status": "Passed",
            "reconciliation_report": json.dumps(reconciliation, ensure_ascii=False),
        }
    )
    return created
