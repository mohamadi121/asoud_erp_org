from __future__ import annotations


def _validate_context(doc) -> None:
    import frappe

    from asoud_core.permissions import can_access_context

    if not can_access_context(frappe.session.user, doc.company, doc.branch):
        frappe.throw("Not permitted", frappe.PermissionError)
    if frappe.db.get_value("ASOUD Branch", doc.branch, "company") != doc.company:
        frappe.throw("Opening balance branch does not belong to the selected company")


def validate_import(doc) -> None:
    import frappe
    from frappe.utils import flt

    _validate_context(doc)
    duplicate = frappe.db.exists(
        "ASOUD Opening Balance Import",
        {
            "company": doc.company,
            "external_reference": doc.external_reference,
            "docstatus": ["!=", 2],
            "name": ["!=", doc.name or ""],
        },
    )
    if duplicate:
        frappe.throw("Opening balance external reference must be unique per company")
    if not doc.entries:
        frappe.throw("Opening balance import requires at least one entry")
    if len(doc.entries) > 5000:
        frappe.throw("Opening balance import is limited to 5000 rows per batch")
    debit = credit = 0.0
    for index, row in enumerate(doc.entries, start=1):
        account = frappe.db.get_value(
            "Account", row.account, ["company", "is_group"], as_dict=True
        )
        if not account or account.company != doc.company or account.is_group:
            frappe.throw(f"Row {index}: account must be a leaf account of the company")
        row_debit, row_credit = flt(row.debit), flt(row.credit)
        if row_debit < 0 or row_credit < 0:
            frappe.throw(f"Row {index}: debit and credit cannot be negative")
        if bool(row_debit) == bool(row_credit):
            frappe.throw(f"Row {index}: exactly one of debit or credit is required")
        if row.party and not row.party_type:
            frappe.throw(f"Row {index}: Party Type is required")
        if row.party_type and row.party and not frappe.db.exists(row.party_type, row.party):
            frappe.throw(f"Row {index}: selected party does not exist")
        if row.floating_detail and not frappe.db.exists(
            "ASOUD Floating Detail Company",
            {
                "parent": row.floating_detail,
                "company": doc.company,
                "enabled": 1,
            },
        ):
            frappe.throw(f"Row {index}: floating detail is not enabled for the company")
        debit += row_debit
        credit += row_credit
    doc.total_debit = flt(debit, 2)
    doc.total_credit = flt(credit, 2)
    doc.difference = flt(debit - credit, 2)
    if doc.difference:
        frappe.throw("Opening balance debit and credit totals must be equal")
    if doc.docstatus == 0:
        doc.status = "Validated"


def post_import(doc) -> str:
    import frappe

    marker = f"ASOUD Opening Import::{doc.company}::{doc.external_reference}"
    existing = frappe.db.exists(
        "Journal Entry",
        {"company": doc.company, "user_remark": marker, "docstatus": 1},
    )
    if existing:
        return existing
    accounts = []
    for row in doc.entries:
        values = {
            "account": row.account,
            "party_type": row.party_type,
            "party": row.party,
            "asoud_branch": doc.branch,
            "asoud_floating_detail": row.floating_detail,
            "debit_in_account_currency": row.debit,
            "credit_in_account_currency": row.credit,
            "user_remark": row.description,
        }
        accounts.append({key: value for key, value in values.items() if value not in (None, "")})
    journal = frappe.get_doc(
        {
            "doctype": "Journal Entry",
            "voucher_type": "Opening Entry",
            "company": doc.company,
            "posting_date": doc.posting_date,
            "is_opening": "Yes",
            "asoud_branch": doc.branch,
            "user_remark": marker,
            "accounts": accounts,
        }
    ).insert(ignore_permissions=True)
    journal.submit()
    return journal.name
