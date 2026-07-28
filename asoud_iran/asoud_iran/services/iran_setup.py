from __future__ import annotations

from contextlib import contextmanager
from typing import Any

DEFAULT_TEMPLATE_CODE = "ASOUD-IR-GENERAL"
DEFAULT_TEMPLATE_VERSION = "1.1.0"
DEFAULT_TEMPLATE_NAME = f"{DEFAULT_TEMPLATE_CODE}-V{DEFAULT_TEMPLATE_VERSION}"

DEFAULT_ACCOUNTS = (
    ("100000", "Assets Control", "", "Asset", 1, "", 0),
    ("110000", "Current Assets", "100000", "Asset", 1, "", 0),
    ("111000", "Cash and Banks", "110000", "Asset", 1, "", 0),
    ("111001", "Cash", "111000", "Asset", 0, "Cash", 0),
    ("111002", "Petty Cash", "111000", "Asset", 0, "Cash", 0),
    ("111003", "Current Bank Accounts", "111000", "Asset", 0, "Bank", 0),
    ("111004", "Short-term Bank Deposits", "111000", "Asset", 0, "Bank", 0),
    ("112000", "Trade Receivables", "110000", "Asset", 1, "", 0),
    ("112001", "Accounts Receivable", "112000", "Asset", 0, "Receivable", 1),
    ("112002", "Notes Receivable", "112000", "Asset", 0, "", 1),
    ("112003", "Other Receivables", "112000", "Asset", 0, "", 1),
    ("112004", "Employee Receivables", "112000", "Asset", 0, "", 1),
    ("113000", "Inventories", "110000", "Asset", 1, "", 0),
    ("113001", "Merchandise Inventory", "113000", "Asset", 0, "Stock", 0),
    ("113002", "Raw Material Inventory", "113000", "Asset", 0, "Stock", 0),
    ("113003", "Work in Process Inventory", "113000", "Asset", 0, "Stock", 0),
    ("113004", "Finished Goods Inventory", "113000", "Asset", 0, "Stock", 0),
    ("113005", "Parts and Supplies Inventory", "113000", "Asset", 0, "Stock", 0),
    ("114000", "Prepayments and Deposits", "110000", "Asset", 1, "", 0),
    ("114001", "Prepaid Expenses", "114000", "Asset", 0, "", 1),
    ("114002", "Purchase Advances", "114000", "Asset", 0, "", 1),
    ("114003", "Guarantee Deposits", "114000", "Asset", 0, "", 1),
    ("120000", "Non-current Assets", "100000", "Asset", 1, "", 0),
    ("121000", "Property Plant and Equipment", "120000", "Asset", 1, "", 0),
    ("121001", "Land", "121000", "Asset", 0, "Fixed Asset", 0),
    ("121002", "Buildings", "121000", "Asset", 0, "Fixed Asset", 0),
    ("121003", "Machinery and Equipment", "121000", "Asset", 0, "Fixed Asset", 0),
    ("121004", "Vehicles", "121000", "Asset", 0, "Fixed Asset", 0),
    ("121005", "Furniture and Fixtures", "121000", "Asset", 0, "Fixed Asset", 0),
    ("121006", "Computer Equipment", "121000", "Asset", 0, "Fixed Asset", 0),
    ("122000", "Accumulated Depreciation", "120000", "Asset", 1, "", 0),
    (
        "122002",
        "Accumulated Depreciation Buildings",
        "122000",
        "Asset",
        0,
        "Accumulated Depreciation",
        0,
    ),
    (
        "122003",
        "Accumulated Depreciation Machinery",
        "122000",
        "Asset",
        0,
        "Accumulated Depreciation",
        0,
    ),
    (
        "122004",
        "Accumulated Depreciation Vehicles",
        "122000",
        "Asset",
        0,
        "Accumulated Depreciation",
        0,
    ),
    (
        "122005",
        "Accumulated Depreciation Furniture",
        "122000",
        "Asset",
        0,
        "Accumulated Depreciation",
        0,
    ),
    (
        "122006",
        "Accumulated Depreciation Computers",
        "122000",
        "Asset",
        0,
        "Accumulated Depreciation",
        0,
    ),
    ("123000", "Long-term Investments", "120000", "Asset", 1, "", 0),
    ("123001", "Long-term Investment", "123000", "Asset", 0, "", 1),
    ("200000", "Liabilities Control", "", "Liability", 1, "", 0),
    ("210000", "Current Liabilities", "200000", "Liability", 1, "", 0),
    ("211000", "Trade Payables", "210000", "Liability", 1, "", 0),
    ("211001", "Accounts Payable", "211000", "Liability", 0, "Payable", 1),
    ("211002", "Notes Payable", "211000", "Liability", 0, "", 1),
    ("211003", "Other Payables", "211000", "Liability", 0, "", 1),
    ("212000", "Tax and Statutory Liabilities", "210000", "Liability", 1, "", 0),
    ("212001", "Value Added Tax Payable", "212000", "Liability", 0, "Tax", 0),
    ("212002", "Withholding Tax Payable", "212000", "Liability", 0, "Tax", 0),
    ("212003", "Payroll Tax Payable", "212000", "Liability", 0, "Tax", 0),
    ("212004", "Social Security Payable", "212000", "Liability", 0, "", 0),
    ("213000", "Employee Liabilities", "210000", "Liability", 1, "", 0),
    ("213001", "Salaries Payable", "213000", "Liability", 0, "", 1),
    ("213002", "Employee Benefits Payable", "213000", "Liability", 0, "", 1),
    ("214000", "Advances and Deposits Received", "210000", "Liability", 1, "", 0),
    ("214001", "Customer Advances", "214000", "Liability", 0, "", 1),
    ("214002", "Guarantee Deposits Received", "214000", "Liability", 0, "", 1),
    ("220000", "Non-current Liabilities", "200000", "Liability", 1, "", 0),
    ("221001", "Long-term Bank Loans", "220000", "Liability", 0, "", 1),
    ("221002", "Long-term Other Payables", "220000", "Liability", 0, "", 1),
    ("300000", "Equity Control", "", "Equity", 1, "", 0),
    ("310001", "Capital", "300000", "Equity", 0, "Equity", 0),
    ("310002", "Legal Reserve", "300000", "Equity", 0, "Equity", 0),
    ("310003", "Retained Earnings", "300000", "Equity", 0, "Equity", 0),
    ("310004", "Current Year Profit or Loss", "300000", "Equity", 0, "Equity", 0),
    ("400000", "Income Control", "", "Income", 1, "", 0),
    ("410000", "Operating Revenue", "400000", "Income", 1, "", 0),
    ("410001", "Goods Sales Revenue", "410000", "Income", 0, "Income Account", 0),
    ("410002", "Service Revenue", "410000", "Income", 0, "Income Account", 0),
    ("410003", "Production Revenue", "410000", "Income", 0, "Income Account", 0),
    ("420000", "Other Operating Income", "400000", "Income", 1, "", 0),
    ("420001", "Other Operating Income", "420000", "Income", 0, "Income Account", 0),
    ("430000", "Non-operating Income", "400000", "Income", 1, "", 0),
    ("430001", "Finance and Investment Income", "430000", "Income", 0, "Income Account", 0),
    ("430002", "Other Non-operating Income", "430000", "Income", 0, "Income Account", 0),
    ("500000", "Expense Control", "", "Expense", 1, "", 0),
    ("510000", "Cost of Revenue", "500000", "Expense", 1, "", 0),
    ("510001", "Cost of Goods Sold", "510000", "Expense", 0, "Cost of Goods Sold", 0),
    ("510002", "Cost of Services", "510000", "Expense", 0, "Cost of Goods Sold", 0),
    ("510003", "Cost of Production", "510000", "Expense", 0, "Cost of Goods Sold", 0),
    ("520000", "Selling and Distribution Expenses", "500000", "Expense", 1, "", 0),
    ("520001", "Sales Salaries and Commissions", "520000", "Expense", 0, "Expense Account", 1),
    ("520002", "Advertising and Marketing", "520000", "Expense", 0, "Expense Account", 1),
    ("520003", "Freight and Distribution", "520000", "Expense", 0, "Expense Account", 1),
    ("530000", "General and Administrative Expenses", "500000", "Expense", 1, "", 0),
    ("530001", "Salaries and Wages", "530000", "Expense", 0, "Expense Account", 1),
    ("530002", "Rent Expense", "530000", "Expense", 0, "Expense Account", 1),
    ("530003", "Utilities Expense", "530000", "Expense", 0, "Expense Account", 1),
    ("530004", "Office and Supplies Expense", "530000", "Expense", 0, "Expense Account", 1),
    ("530005", "Repairs and Maintenance", "530000", "Expense", 0, "Expense Account", 1),
    ("530006", "Insurance Expense", "530000", "Expense", 0, "Expense Account", 1),
    ("530007", "Depreciation Expense", "530000", "Expense", 0, "Depreciation", 1),
    ("530008", "Professional Fees", "530000", "Expense", 0, "Expense Account", 1),
    ("540000", "Finance Costs", "500000", "Expense", 1, "", 0),
    ("540001", "Bank Charges", "540000", "Expense", 0, "Expense Account", 1),
    ("540002", "Interest Expense", "540000", "Expense", 0, "Expense Account", 1),
    ("550000", "Other Expenses", "500000", "Expense", 1, "", 0),
    ("550001", "Other Non-operating Expenses", "550000", "Expense", 0, "Expense Account", 1),
)


@contextmanager
def _company_setup_lock(company: str):
    import frappe

    lock_name = f"asoud-iran-setup:{company}"[:64]
    acquired = frappe.db.sql("SELECT GET_LOCK(%s, 10)", lock_name)[0][0]
    if not acquired:
        frappe.throw(f"Could not acquire Iranian accounting setup lock for {company}")
    try:
        yield
    finally:
        frappe.db.sql("SELECT RELEASE_LOCK(%s)", lock_name)


def ensure_default_template() -> str:
    import frappe

    if frappe.db.exists("ASOUD COA Template", DEFAULT_TEMPLATE_NAME):
        template = frappe.get_doc("ASOUD COA Template", DEFAULT_TEMPLATE_NAME)
    else:
        template = frappe.get_doc(
            {
                "doctype": "ASOUD COA Template",
                "template_title": "ASOUD Iran General Chart of Accounts",
                "template_code": DEFAULT_TEMPLATE_CODE,
                "version": DEFAULT_TEMPLATE_VERSION,
                "business_scope": "General",
                "base_currency": "IRR",
                "accounts": [
                    {
                        "account_code": code,
                        "account_name": title,
                        "parent_account_code": parent,
                        "root_type": root,
                        "is_group": is_group,
                        "account_type": account_type,
                        "requires_floating_detail": requires_detail,
                    }
                    for (
                        code,
                        title,
                        parent,
                        root,
                        is_group,
                        account_type,
                        requires_detail,
                    ) in DEFAULT_ACCOUNTS
                ],
            }
        ).insert(ignore_permissions=True)
    if template.docstatus == 0:
        template.submit()
    return template.name


def _root_account(company: str, root_type: str) -> str:
    import frappe

    roots = frappe.get_all(
        "Account",
        filters={
            "company": company,
            "root_type": root_type,
            "is_group": 1,
        },
        fields=["name", "parent_account"],
        order_by="lft asc",
    )
    for row in roots:
        if not row.parent_account:
            return row.name
    frappe.throw(f"No {root_type} root account exists for {company}")


def _existing_account(company: str, account_code: str):
    import frappe

    rows = frappe.get_all(
        "Account",
        filters={"company": company, "account_number": account_code},
        fields=["name", "root_type", "is_group", "account_type"],
        limit=2,
    )
    if len(rows) > 1:
        frappe.throw(f"Account number {account_code} is duplicated in {company}")
    return rows[0] if rows else None


def setup_plan(company: str, template_name: str | None = None) -> dict[str, Any]:
    import frappe

    template_name = template_name or ensure_default_template()
    template = frappe.get_doc("ASOUD COA Template", template_name)
    if template.docstatus != 1:
        frappe.throw("COA template must be submitted")
    if frappe.db.get_value("Company", company, "default_currency") != "IRR":
        frappe.throw(f"Company {company} must use IRR as default currency")
    missing: list[str] = []
    existing: list[str] = []
    conflicts: list[str] = []
    for row in template.accounts:
        account = _existing_account(company, row.account_code)
        if not account:
            missing.append(row.account_code)
        elif account.root_type != row.root_type or int(account.is_group) != int(row.is_group):
            conflicts.append(row.account_code)
        else:
            existing.append(row.account_code)
    return {
        "company": company,
        "template": template.name,
        "template_hash": template.content_hash,
        "missing_accounts": missing,
        "existing_accounts": existing,
        "conflicts": conflicts,
    }


def _ensure_account(company: str, row, resolved: dict[str, str]) -> tuple[str, bool]:
    import frappe

    existing = _existing_account(company, row.account_code)
    if existing:
        if existing.root_type != row.root_type or int(existing.is_group) != int(row.is_group):
            frappe.throw(f"Existing account conflicts with template: {row.account_code}")
        expected_type = row.account_type or ""
        if expected_type and not existing.account_type:
            frappe.db.set_value(
                "Account",
                existing.name,
                "account_type",
                expected_type,
                update_modified=False,
            )
        return existing.name, False
    parent = (
        resolved[row.parent_account_code]
        if row.parent_account_code
        else _root_account(company, row.root_type)
    )
    report_type = "Profit and Loss" if row.root_type in {"Income", "Expense"} else "Balance Sheet"
    account = frappe.get_doc(
        {
            "doctype": "Account",
            "account_name": row.account_name,
            "account_number": row.account_code,
            "parent_account": parent,
            "company": company,
            "root_type": row.root_type,
            "report_type": report_type,
            "account_currency": "IRR",
            "is_group": row.is_group,
            "account_type": row.account_type or "",
        }
    ).insert(ignore_permissions=True)
    return account.name, True


def _detail_type_for_account(account_type: str, account_name: str) -> str:
    normalized = account_name.lower()
    if account_type == "Receivable":
        return "Customer"
    if account_type == "Payable":
        return "Supplier"
    if "employee" in normalized or "salar" in normalized or "wage" in normalized:
        return "Employee"
    if "customer" in normalized or "receivable" in normalized:
        return "Customer"
    if (
        "supplier" in normalized
        or "purchase" in normalized
        or "payable" in normalized
    ):
        return "Supplier"
    if (
        "expense" in normalized
        or account_type
        in {"Cost of Goods Sold", "Depreciation", "Expense Account"}
    ):
        return "Cost Center"
    return "Other"


def _ensure_detail_rule(
    company: str,
    account: str,
    account_type: str,
    account_name: str,
) -> str:
    import frappe

    detail_type = _detail_type_for_account(account_type, account_name)
    existing = frappe.db.exists(
        "ASOUD Account Detail Rule",
        {
            "company": company,
            "account": account,
            "detail_type": detail_type,
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
            "company": company,
            "account": account,
            "detail_type": detail_type,
            "required": 1,
            "enabled": 1,
        }
    ).insert(ignore_permissions=True).name


def apply_iran_setup(
    company: str,
    template_name: str | None = None,
    amount_input_unit: str = "IRR",
    calendar_display: str = "Jalali",
) -> dict[str, Any]:
    """Install or upgrade the Iranian accounting baseline for one Company."""
    import frappe
    from frappe.utils import now_datetime

    frappe.only_for(("System Manager", "Accounts Manager"))
    company_doc = frappe.get_doc("Company", company)
    if not company_doc.has_permission("read"):
        frappe.throw("Not permitted for the selected company", frappe.PermissionError)
    template_name = template_name or ensure_default_template()
    with _company_setup_lock(company):
        plan = setup_plan(company, template_name)
        if plan["conflicts"]:
            frappe.throw(
                "Conflicting account numbers: " + ", ".join(plan["conflicts"])
            )
        template = frappe.get_doc("ASOUD COA Template", template_name)
        resolved: dict[str, str] = {}
        created: list[str] = []
        rules: list[str] = []
        for row in template.accounts:
            account, was_created = _ensure_account(company, row, resolved)
            resolved[row.account_code] = account
            if was_created:
                created.append(account)
            if row.requires_floating_detail:
                rules.append(
                    _ensure_detail_rule(
                        company,
                        account,
                        row.account_type,
                        row.account_name,
                    )
                )

        if frappe.db.exists("ASOUD Iran Company Settings", company):
            settings = frappe.get_doc("ASOUD Iran Company Settings", company)
        else:
            settings = frappe.get_doc(
                {
                    "doctype": "ASOUD Iran Company Settings",
                    "company": company,
                    "coa_template": template.name,
                }
            )
        settings.coa_template = template.name
        settings.base_currency = "IRR"
        settings.amount_input_unit = amount_input_unit.upper()
        settings.calendar_display = calendar_display
        settings.timezone = "Asia/Tehran"
        settings.setup_version = template.version
        settings.setup_hash = template.content_hash
        settings.setup_status = "Completed"
        settings.installed_on = now_datetime()
        settings.save(ignore_permissions=True)
        frappe.db.commit()
        return {
            "status": "completed",
            "company": company,
            "template": template.name,
            "template_hash": template.content_hash,
            "created_accounts": created,
            "account_count": len(resolved),
            "detail_rules": rules,
        }
