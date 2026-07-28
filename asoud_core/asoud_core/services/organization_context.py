from __future__ import annotations


def apply_active_context(doc, method: str | None = None) -> None:
    import frappe

    if not getattr(doc, "company", None):
        return
    context = frappe.db.get_value(
        "ASOUD User Context",
        {"user": frappe.session.user},
        ["company", "branch"],
        as_dict=True,
    )
    if context and context.company == doc.company and not doc.get("asoud_branch"):
        doc.asoud_branch = context.branch


def validate_document_context(doc, method: str | None = None) -> None:
    import frappe

    from asoud_core.permissions import can_access_context

    company = getattr(doc, "company", None)
    branch = doc.get("asoud_branch")
    if not company:
        return
    if branch:
        branch_row = frappe.db.get_value(
            "ASOUD Branch",
            branch,
            ["company", "enabled"],
            as_dict=True,
        )
        if not branch_row or not branch_row.enabled:
            frappe.throw("The selected ASOUD branch is disabled or does not exist")
        if branch_row.company != company:
            frappe.throw("The selected ASOUD branch does not belong to the document company")
    if not can_access_context(frappe.session.user, company, branch):
        frappe.throw("You do not have access to the selected company and branch")
    assert_period_open(doc)


def assert_period_open(doc, method: str | None = None) -> None:
    import frappe

    company = getattr(doc, "company", None)
    posting_date = getattr(doc, "posting_date", None)
    if not company or not posting_date:
        return
    lock = frappe.db.exists(
        "ASOUD Period Lock",
        {
            "company": company,
            "from_date": ["<=", posting_date],
            "to_date": [">=", posting_date],
            "docstatus": 1,
        },
    )
    if lock:
        frappe.throw(f"Posting date is inside locked period {lock}")
