from __future__ import annotations

from typing import Any

from asoud_core.phase_one_demo import COMPANY_A, COMPANY_B, HOLDING_CODE, USERS
from asoud_iran.services.iran_setup import (
    DEFAULT_TEMPLATE_NAME,
    apply_iran_setup,
    ensure_default_template,
)

MARKER = "ASOUD-PHASE2-FLOATING-DETAIL"
MERGE_MARKER = "ASOUD-PHASE2-DISTINCT-DETAILS"


def _account(company: str, account_number: str) -> str:
    import frappe

    account = frappe.db.get_value(
        "Account",
        {"company": company, "account_number": account_number},
        "name",
    )
    if not account:
        frappe.throw(f"Phase-two account {account_number} does not exist in {company}")
    return account


def _ensure_floating_detail() -> str:
    import frappe

    existing = frappe.db.exists(
        "ASOUD Floating Detail",
        {"holding": HOLDING_CODE, "detail_title": "Phase Two Control Detail"},
    )
    if existing:
        detail = frappe.get_doc("ASOUD Floating Detail", existing)
    else:
        detail = frappe.get_doc(
            {
                "doctype": "ASOUD Floating Detail",
                "detail_title": "Phase Two Control Detail",
                "holding": HOLDING_CODE,
                "detail_type": "Other",
                "enabled": 1,
                "company_codes": [
                    {"company": COMPANY_A, "detail_code": "ADT-T-0001", "enabled": 1},
                    {"company": COMPANY_B, "detail_code": "ADS-T-0001", "enabled": 1},
                ],
            }
        ).insert(ignore_permissions=True)
    return detail.name


def _ensure_company_only_detail() -> str:
    import frappe

    existing = frappe.db.exists(
        "ASOUD Floating Detail",
        {"holding": HOLDING_CODE, "detail_title": "Trading Company Only Detail"},
    )
    if existing:
        return existing
    return frappe.get_doc(
        {
            "doctype": "ASOUD Floating Detail",
            "detail_title": "Trading Company Only Detail",
            "holding": HOLDING_CODE,
            "detail_type": "Other",
            "enabled": 1,
            "company_codes": [
                {"company": COMPANY_A, "detail_code": "ADT-T-ONLY", "enabled": 1},
            ],
        }
    ).insert(ignore_permissions=True).name


def _assert_permission_matrix(company_only_detail: str) -> None:
    import frappe

    expected = {
        USERS["holding_manager"]: True,
        USERS["company_manager"]: True,
        USERS["branch_manager"]: True,
        USERS["accountant"]: False,
    }
    for user, visible in expected.items():
        frappe.set_user(user)
        actual = bool(
            frappe.get_list(
                "ASOUD Floating Detail",
                filters={"name": company_only_detail},
                pluck="name",
            )
        )
        if actual is not visible:
            raise AssertionError(f"Floating-detail permission mismatch for {user}")

    from asoud_iran.api import company_accounting_settings

    frappe.set_user(USERS["accountant"])
    if company_accounting_settings(COMPANY_B)["setup_status"] != "Completed":
        raise AssertionError("Accountant could not read the permitted company settings")
    try:
        company_accounting_settings(COMPANY_A)
    except frappe.PermissionError:
        pass
    else:
        raise AssertionError("Accountant read settings of a forbidden company")
    try:
        apply_iran_setup(COMPANY_B)
    except frappe.PermissionError:
        pass
    else:
        raise AssertionError("Accounts User executed privileged Iranian setup")
    frappe.set_user("Administrator")


def _ensure_cash_detail_rule(account: str) -> str:
    import frappe

    existing = frappe.db.exists(
        "ASOUD Account Detail Rule",
        {
            "company": COMPANY_A,
            "account": account,
            "detail_type": "Other",
        },
    )
    if existing:
        rule = frappe.get_doc("ASOUD Account Detail Rule", existing)
        if not rule.enabled or not rule.required:
            rule.enabled = 1
            rule.required = 1
            rule.save(ignore_permissions=True)
        return rule.name
    return frappe.get_doc(
        {
            "doctype": "ASOUD Account Detail Rule",
            "company": COMPANY_A,
            "account": account,
            "detail_type": "Other",
            "required": 1,
            "enabled": 1,
        }
    ).insert(ignore_permissions=True).name


def _assert_required_detail(cash_account: str, equity_account: str) -> None:
    import frappe

    try:
        frappe.get_doc(
            {
                "doctype": "Journal Entry",
                "voucher_type": "Journal Entry",
                "company": COMPANY_A,
                "posting_date": "2026-05-10",
                "user_remark": "ASOUD-PHASE2-MISSING-DETAIL-MUST-FAIL",
                "accounts": [
                    {"account": cash_account, "debit_in_account_currency": 1000},
                    {"account": equity_account, "credit_in_account_currency": 1000},
                ],
            }
        ).insert(ignore_permissions=True)
    except frappe.ValidationError:
        frappe.db.rollback()
    else:
        raise AssertionError("Required floating detail was not enforced")


def _ensure_detail_journal(
    cash_account: str,
    equity_account: str,
    floating_detail: str,
) -> str:
    import frappe

    existing = frappe.db.exists("Journal Entry", {"user_remark": MARKER, "docstatus": 1})
    if existing:
        return existing
    entry = frappe.get_doc(
        {
            "doctype": "Journal Entry",
            "voucher_type": "Journal Entry",
            "company": COMPANY_A,
            "posting_date": "2026-05-11",
            "user_remark": MARKER,
            "accounts": [
                {
                    "account": cash_account,
                    "debit_in_account_currency": 12505,
                    "asoud_floating_detail": floating_detail,
                },
                {
                    "account": equity_account,
                    "credit_in_account_currency": 12505,
                },
            ],
        }
    ).insert(ignore_permissions=True)
    entry.submit()
    return entry.name


def _ensure_distinct_detail_journal(
    cash_account: str,
    equity_account: str,
    first_detail: str,
    second_detail: str,
) -> str:
    import frappe

    existing = frappe.db.exists(
        "Journal Entry",
        {"user_remark": MERGE_MARKER, "docstatus": 1},
    )
    if existing:
        entry_name = existing
    else:
        entry = frappe.get_doc(
            {
                "doctype": "Journal Entry",
                "voucher_type": "Journal Entry",
                "company": COMPANY_A,
                "posting_date": "2026-05-12",
                "user_remark": MERGE_MARKER,
                "accounts": [
                    {
                        "account": cash_account,
                        "debit_in_account_currency": 1001,
                        "asoud_floating_detail": first_detail,
                    },
                    {
                        "account": cash_account,
                        "debit_in_account_currency": 1002,
                        "asoud_floating_detail": second_detail,
                    },
                    {
                        "account": equity_account,
                        "credit_in_account_currency": 2003,
                    },
                ],
            }
        ).insert(ignore_permissions=True)
        entry.submit()
        entry_name = entry.name
    rows = frappe.get_all(
        "GL Entry",
        filters={
            "voucher_type": "Journal Entry",
            "voucher_no": entry_name,
            "account": cash_account,
            "is_cancelled": 0,
        },
        fields=["asoud_floating_detail", "debit"],
    )
    if len(rows) != 2:
        raise AssertionError("Different floating details were merged in GL")
    if {row.asoud_floating_detail for row in rows} != {first_detail, second_detail}:
        raise AssertionError("GL lost one of the distinct floating details")
    return entry_name


def _assert_gl_and_reports(entry_name: str, floating_detail: str) -> dict[str, int]:
    import frappe

    from asoud_iran.services.floating_detail import detail_ledger, trial_balance

    gl_row = frappe.db.get_value(
        "GL Entry",
        {
            "voucher_type": "Journal Entry",
            "voucher_no": entry_name,
            "asoud_floating_detail": floating_detail,
        },
        ["asoud_detail_code", "asoud_detail_type", "debit", "credit"],
        as_dict=True,
    )
    if not gl_row:
        raise AssertionError("Floating detail was not copied to GL Entry")
    if gl_row.asoud_detail_code != "ADT-T-0001" or gl_row.asoud_detail_type != "Other":
        raise AssertionError("Floating detail snapshot in GL is incorrect")
    detail_rows = detail_ledger(
        company=COMPANY_A,
        from_date="2026-05-01",
        to_date="2026-05-31",
        floating_detail=floating_detail,
    )
    if entry_name not in {row.voucher_no for row in detail_rows}:
        raise AssertionError("Detail ledger omitted the accepted Journal Entry")
    balance_rows = trial_balance(COMPANY_A, "2026-05-01", "2026-05-31")
    total_debit = round(sum(row.debit for row in balance_rows))
    total_credit = round(sum(row.credit for row in balance_rows))
    if total_debit != total_credit:
        raise AssertionError("Trial balance does not reconcile to GL")
    return {"debit": total_debit, "credit": total_credit}


def run_phase_two_acceptance() -> dict[str, Any]:
    """Run repeatable phase-two checks against real ERPNext accounts and GL."""
    import frappe

    from asoud_core.phase_one_demo import ensure_phase_one_demo
    from asoud_iran.accounting.currency import normalize_api_amount
    from asoud_iran.accounting.jalali import format_jalali, parse_jalali

    frappe.only_for("System Manager")
    ensure_phase_one_demo()
    frappe.set_user("Administrator")
    template = ensure_default_template()
    first_a = apply_iran_setup(COMPANY_A, template, "TOMAN", "Jalali")
    first_b = apply_iran_setup(COMPANY_B, template, "IRR", "Jalali")
    repeated_a = apply_iran_setup(COMPANY_A, template, "TOMAN", "Jalali")
    if repeated_a["created_accounts"]:
        raise AssertionError("Repeated Iranian setup created duplicate accounts")
    if first_a["account_count"] != first_b["account_count"]:
        raise AssertionError("Shared COA template produced inconsistent company charts")
    settings = frappe.get_doc("ASOUD Iran Company Settings", COMPANY_A)
    if (
        settings.coa_template != DEFAULT_TEMPLATE_NAME
        or settings.base_currency != "IRR"
        or settings.amount_input_unit != "TOMAN"
        or settings.setup_status != "Completed"
    ):
        raise AssertionError("Iranian company settings are incomplete")
    cash = _account(COMPANY_A, "111001")
    equity = _account(COMPANY_A, "310001")
    detail = _ensure_floating_detail()
    company_only_detail = _ensure_company_only_detail()
    _ensure_cash_detail_rule(cash)
    frappe.db.commit()
    _assert_permission_matrix(company_only_detail)
    _assert_required_detail(cash, equity)
    entry = _ensure_detail_journal(cash, equity, detail)
    merge_entry = _ensure_distinct_detail_journal(
        cash,
        equity,
        detail,
        company_only_detail,
    )
    totals = _assert_gl_and_reports(entry, detail)
    if normalize_api_amount("1250.5", "TOMAN")["ledger_amount"] != "12505":
        raise AssertionError("Toman conversion contract failed")
    if format_jalali(parse_jalali("1405-01-01")) != "1405-01-01":
        raise AssertionError("Jalali round-trip failed")
    frappe.db.commit()
    return {
        "status": "passed",
        "template": template,
        "companies": [COMPANY_A, COMPANY_B],
        "account_count": first_a["account_count"],
        "idempotency": "passed",
        "floating_detail": detail,
        "journal_entry": entry,
        "merge_journal_entry": merge_entry,
        "trial_balance": totals,
        "currency": "passed",
        "jalali": "passed",
    }
