from __future__ import annotations

from typing import Any

HOLDING_CODE = "ASOUD-DEMO"
COMPANY_A = "ASOUD Demo Trading"
COMPANY_B = "ASOUD Demo Services"
FISCAL_YEAR_1405 = "1405"
FISCAL_YEAR_1406 = "1406"
USERS = {
    "holding_manager": "holding.manager@asoud.test",
    "company_manager": "company.manager@asoud.test",
    "branch_manager": "branch.manager@asoud.test",
    "accountant": "accountant@asoud.test",
}
TRANSACTION_DOCTYPES = (
    "Journal Entry",
    "Sales Invoice",
    "Purchase Invoice",
    "Payment Entry",
    "Stock Entry",
    "Delivery Note",
    "Purchase Receipt",
)


def _ensure_required_masters() -> None:
    import frappe

    if not frappe.db.exists("Warehouse Type", "Transit"):
        frappe.get_doc(
            {
                "doctype": "Warehouse Type",
                "name": "Transit",
            }
        ).insert(ignore_permissions=True)


def _ensure_holding() -> str:
    import frappe

    if not frappe.db.exists("ASOUD Holding", HOLDING_CODE):
        frappe.get_doc(
            {
                "doctype": "ASOUD Holding",
                "holding_name": "ASOUD Demo Holding",
                "holding_code": HOLDING_CODE,
                "consolidation_currency": "IRR",
                "enabled": 1,
            }
        ).insert(ignore_permissions=True)
    return HOLDING_CODE


def _ensure_company(
    company_name: str,
    abbr: str,
    holding: str,
    *,
    existing_company: str | None = None,
) -> str:
    import frappe

    if not frappe.db.exists("Company", company_name):
        values: dict[str, Any] = {
            "doctype": "Company",
            "company_name": company_name,
            "abbr": abbr,
            "default_currency": "IRR",
            "country": "Iran",
            "asoud_holding": holding,
            "create_chart_of_accounts_based_on": (
                "Existing Company" if existing_company else "Standard Template"
            ),
        }
        if existing_company:
            values["existing_company"] = existing_company
        else:
            values["chart_of_accounts"] = "Standard"
        frappe.get_doc(values).insert(ignore_permissions=True)
    elif frappe.db.get_value("Company", company_name, "asoud_holding") != holding:
        frappe.db.set_value("Company", company_name, "asoud_holding", holding)
    return company_name


def _ensure_fiscal_year(
    year: str,
    start_date: str,
    end_date: str,
    companies: tuple[str, ...],
) -> str:
    import frappe

    if frappe.db.exists("Fiscal Year", year):
        fiscal_year = frappe.get_doc("Fiscal Year", year)
    else:
        fiscal_year = frappe.get_doc(
            {
                "doctype": "Fiscal Year",
                "year": year,
                "year_start_date": start_date,
                "year_end_date": end_date,
            }
        ).insert(ignore_permissions=True)
    assigned = {row.company for row in fiscal_year.companies}
    changed = False
    for company in companies:
        if company not in assigned:
            fiscal_year.append("companies", {"company": company})
            changed = True
    if changed:
        fiscal_year.save(ignore_permissions=True)
    return fiscal_year.name


def _ensure_accounting_period(company: str, abbr: str) -> str:
    import frappe

    period_name = f"{abbr}-1405-Q1"
    existing = frappe.db.exists(
        "Accounting Period",
        {
            "company": company,
            "start_date": "2026-03-21",
            "end_date": "2026-06-21",
        },
    )
    if existing:
        return existing
    return frappe.get_doc(
        {
            "doctype": "Accounting Period",
            "period_name": period_name,
            "start_date": "2026-03-21",
            "end_date": "2026-06-21",
            "company": company,
            "closed_documents": [
                {"document_type": doctype, "closed": 0}
                for doctype in TRANSACTION_DOCTYPES
            ],
        }
    ).insert(ignore_permissions=True).name


def _ensure_branch(company: str, code: str, title: str) -> str:
    import frappe

    existing = frappe.db.exists(
        "ASOUD Branch",
        {"company": company, "branch_code": code},
    )
    if existing:
        branch = frappe.get_doc("ASOUD Branch", existing)
        if not branch.enabled:
            branch.enabled = 1
            branch.save(ignore_permissions=True)
        return branch.name
    return frappe.get_doc(
        {
            "doctype": "ASOUD Branch",
            "branch_name": title,
            "branch_code": code,
            "company": company,
            "enabled": 1,
        }
    ).insert(ignore_permissions=True).name


def _ensure_user(
    email: str,
    first_name: str,
    roles: tuple[str, ...],
    password: str | None,
) -> str:
    import frappe

    if frappe.db.exists("User", email):
        user = frappe.get_doc("User", email)
        changed = False
        if not user.enabled:
            user.enabled = 1
            changed = True
        if user.user_type != "System User":
            user.user_type = "System User"
            changed = True
        if changed:
            user.save(ignore_permissions=True)
    else:
        user = frappe.get_doc(
            {
                "doctype": "User",
                "email": email,
                "first_name": first_name,
                "enabled": 1,
                "user_type": "System User",
                "send_welcome_email": 0,
            }
        ).insert(ignore_permissions=True)
    missing_roles = [role for role in roles if role not in frappe.get_roles(email)]
    if missing_roles:
        user.add_roles(*missing_roles)
    if password:
        from frappe.utils.password import update_password

        update_password(email, password)
    return email


def _ensure_access(
    user: str,
    company: str,
    *,
    branch: str | None = None,
    holding_manager: bool = False,
) -> str:
    import frappe

    existing = frappe.db.exists(
        "ASOUD User Access",
        {
            "user": user,
            "company": company,
            "branch": branch or "",
        },
    )
    if existing:
        access = frappe.get_doc("ASOUD User Access", existing)
        changed = False
        if not access.enabled:
            access.enabled = 1
            changed = True
        if bool(access.holding_manager) != holding_manager:
            access.holding_manager = holding_manager
            changed = True
        if changed:
            access.save(ignore_permissions=True)
        return access.name
    return frappe.get_doc(
        {
            "doctype": "ASOUD User Access",
            "user": user,
            "company": company,
            "branch": branch,
            "holding_manager": holding_manager,
            "enabled": 1,
        }
    ).insert(ignore_permissions=True).name


def ensure_phase_one_demo(password: str | None = None) -> dict[str, Any]:
    """Create repeatable phase-one reference data without embedding a password."""
    import os

    import frappe

    frappe.only_for("System Manager")
    password = password or os.environ.get("ASOUD_DEMO_PASSWORD")
    if password is not None and len(password) < 12:
        frappe.throw("Demo password must contain at least 12 characters")

    _ensure_required_masters()
    holding = _ensure_holding()
    company_a = _ensure_company(COMPANY_A, "ADT", holding)
    company_b = _ensure_company(
        COMPANY_B,
        "ADS",
        holding,
        existing_company=company_a,
    )
    companies = (company_a, company_b)
    _ensure_fiscal_year(
        FISCAL_YEAR_1405,
        "2026-03-21",
        "2027-03-20",
        companies,
    )
    _ensure_fiscal_year(
        FISCAL_YEAR_1406,
        "2027-03-21",
        "2028-03-20",
        companies,
    )
    periods = (
        _ensure_accounting_period(company_a, "ADT"),
        _ensure_accounting_period(company_b, "ADS"),
    )
    branches = {
        "a_hq": _ensure_branch(company_a, "HQ", "دفتر مرکزی بازرگانی"),
        "a_ops": _ensure_branch(company_a, "OPS", "دفتر عملیات بازرگانی"),
        "b_hq": _ensure_branch(company_b, "HQ", "دفتر مرکزی خدمات"),
        "b_ops": _ensure_branch(company_b, "OPS", "دفتر عملیات خدمات"),
    }

    _ensure_user(
        USERS["holding_manager"],
        "Holding Manager",
        ("Accounts Manager", "Stock Manager"),
        password,
    )
    _ensure_user(
        USERS["company_manager"],
        "Company Manager",
        ("Accounts Manager", "Stock Manager"),
        password,
    )
    _ensure_user(
        USERS["branch_manager"],
        "Branch Manager",
        ("Accounts User", "Stock User"),
        password,
    )
    _ensure_user(
        USERS["accountant"],
        "Limited Accountant",
        ("Accounts User",),
        password,
    )

    _ensure_access(
        USERS["holding_manager"],
        company_a,
        holding_manager=True,
    )
    _ensure_access(USERS["company_manager"], company_a)
    _ensure_access(USERS["branch_manager"], company_a, branch=branches["a_hq"])
    _ensure_access(USERS["accountant"], company_b, branch=branches["b_hq"])

    frappe.db.commit()
    return {
        "holding": holding,
        "companies": list(companies),
        "branches": branches,
        "users": USERS,
        "fiscal_years": [FISCAL_YEAR_1405, FISCAL_YEAR_1406],
        "accounting_periods": list(periods),
    }
