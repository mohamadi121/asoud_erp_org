from __future__ import annotations

from typing import Any

from asoud_core.phase_one_demo import COMPANY_A, FISCAL_YEAR_1405


def _ensure_control_account(account_name: str) -> str:
    import frappe

    existing = frappe.db.exists(
        "Account",
        {"company": COMPANY_A, "account_name": account_name},
    )
    if existing:
        return existing
    parents = frappe.get_all(
        "Account",
        filters={
            "company": COMPANY_A,
            "root_type": "Equity",
            "is_group": 1,
        },
        pluck="name",
        order_by="lft desc",
        limit=1,
    )
    if not parents:
        frappe.throw(f"No Equity account group exists for {COMPANY_A}")
    return frappe.get_doc(
        {
            "doctype": "Account",
            "account_name": account_name,
            "parent_account": parents[0],
            "company": COMPANY_A,
            "root_type": "Equity",
            "report_type": "Balance Sheet",
            "account_currency": "IRR",
            "is_group": 0,
        }
    ).insert(ignore_permissions=True).name


def _ensure_closing_run() -> str:
    import frappe

    existing = frappe.db.exists(
        "ASOUD Closing Run",
        {
            "company": COMPANY_A,
            "fiscal_year": FISCAL_YEAR_1405,
            "docstatus": ["!=", 2],
        },
    )
    if existing:
        return existing
    retained = _ensure_control_account("ASOUD Retained Earnings")
    closing = _ensure_control_account("ASOUD Closing Control")
    opening = _ensure_control_account("ASOUD Opening Control")
    run = frappe.get_doc(
        {
            "doctype": "ASOUD Closing Run",
            "company": COMPANY_A,
            "fiscal_year": FISCAL_YEAR_1405,
            "closing_date": "2027-03-20",
            "opening_date": "2027-03-21",
            "retained_earnings_account": retained,
            "closing_control_account": closing,
            "opening_control_account": opening,
        }
    ).insert(ignore_permissions=True)
    run.submit()
    return run.name


def run_phase_one_acceptance() -> dict[str, Any]:
    """Create and verify real fiscal closing/opening Journal Entries."""
    import frappe

    from asoud_core.phase_one_demo import ensure_phase_one_demo
    from asoud_iran.services.fiscal_closing import execute

    frappe.only_for("System Manager")
    ensure_phase_one_demo()
    frappe.set_user("Administrator")
    run_name = _ensure_closing_run()
    run = frappe.get_doc("ASOUD Closing Run", run_name)
    if run.status != "Completed":
        execute(run_name)
    run.reload()
    linked = [
        run.profit_loss_journal_entry,
        run.permanent_closing_journal_entry,
        run.opening_journal_entry,
    ]
    created = [name for name in linked if name]
    if not run.permanent_closing_journal_entry or not run.opening_journal_entry:
        raise AssertionError("Permanent closing and opening Journal Entries are required")
    for name in created:
        entry = frappe.get_doc("Journal Entry", name)
        if entry.docstatus != 1:
            raise AssertionError(f"Generated Journal Entry is not submitted: {name}")
        if entry.asoud_closing_run != run.name:
            raise AssertionError(f"Generated Journal Entry lost its closing-run link: {name}")
        if not entry.asoud_temporary_number:
            raise AssertionError(f"Generated Journal Entry has no temporary number: {name}")
        debit = sum(row.debit for row in entry.accounts)
        credit = sum(row.credit for row in entry.accounts)
        if abs(debit - credit) > 0.000001:
            raise AssertionError(f"Generated Journal Entry is unbalanced: {name}")
    repeated = execute(run_name)
    expected = {
        "profit_loss_journal_entry": run.profit_loss_journal_entry,
        "permanent_closing_journal_entry": run.permanent_closing_journal_entry,
        "opening_journal_entry": run.opening_journal_entry,
    }
    if repeated != expected:
        raise AssertionError("Completed closing run retry changed generated vouchers")
    frappe.db.commit()
    return {
        "status": "passed",
        "closing_run": run.name,
        "journal_entries": created,
        "idempotency": "passed",
    }
