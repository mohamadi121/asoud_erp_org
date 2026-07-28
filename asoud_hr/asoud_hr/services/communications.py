from __future__ import annotations

import re


_UNSAFE_HTML = re.compile(
    r"<\s*script|javascript\s*:|on(?:error|load|click)\s*=",
    flags=re.IGNORECASE,
)


def prepare_communication(doc, method: str | None = None) -> None:
    import frappe

    if doc.is_new():
        doc.sender = frappe.session.user


def validate_communication(doc, method: str | None = None) -> None:
    import frappe

    if doc.branch:
        company = frappe.db.get_value("ASOUD Branch", doc.branch, "company")
        if company != doc.company:
            frappe.throw("Communication branch must belong to its company")
    if _UNSAFE_HTML.search(doc.body or ""):
        frappe.throw("Communication body contains unsafe HTML")
    if not doc.recipients:
        frappe.throw("A communication must have at least one recipient")
    seen: set[tuple[str, str, str]] = set()
    has_primary = False
    for row in doc.recipients:
        if row.recipient_type == "User":
            if not row.user or row.department:
                frappe.throw("User recipients must identify exactly one user")
            target = row.user
        elif row.recipient_type == "Department":
            if not row.department or row.user:
                frappe.throw("Department recipients must identify exactly one department")
            if doc.confidentiality == "Strictly Confidential":
                frappe.throw("Strictly confidential communications require explicit users")
            target = row.department
        else:
            frappe.throw("Unsupported communication recipient type")
        key = (row.recipient_type, target, row.delivery_mode)
        if key in seen:
            frappe.throw("Duplicate communication recipient")
        seen.add(key)
        has_primary = has_primary or row.delivery_mode == "To"
    if not has_primary:
        frappe.throw("A communication must have at least one primary recipient")
    if doc.thread_parent:
        parent_company = frappe.db.get_value(
            "ASOUD Internal Communication", doc.thread_parent, "company"
        )
        if parent_company != doc.company:
            frappe.throw("Communication thread must stay within one company")


def recipient_users(doc) -> set[str]:
    import frappe

    users: set[str] = set()
    for row in doc.recipients:
        if row.recipient_type == "User" and row.user:
            users.add(row.user)
        elif row.recipient_type == "Department" and row.department:
            users.update(
                frappe.get_all(
                    "Employee",
                    filters={
                        "department": row.department,
                        "status": "Active",
                        "user_id": ["is", "set"],
                    },
                    pluck="user_id",
                    limit_page_length=0,
                )
            )
    return {user for user in users if user and user != "Guest"}


def deliver_communication(doc, method: str | None = None) -> None:
    import frappe

    doc.db_set("status", "Sent")
    for user in sorted(recipient_users(doc)):
        preference = frappe.db.get_value(
            "ASOUD HR Notification Preference",
            user,
            ["in_app_enabled", "communication_enabled"],
            as_dict=True,
        )
        if preference and not (
            int(preference.in_app_enabled or 0)
            and int(preference.communication_enabled or 0)
        ):
            continue
        frappe.get_doc(
            {
                "doctype": "Notification Log",
                "subject": f"مکاتبه جدید: {doc.subject}",
                "for_user": user,
                "type": "Alert",
                "document_type": doc.doctype,
                "document_name": doc.name,
                "email_content": (
                    "یک مکاتبه محرمانه برای شما ثبت شد."
                    if doc.confidentiality != "Normal"
                    else doc.subject
                ),
            }
        ).insert(ignore_permissions=True)
    from asoud_core.services.audit import append_event

    append_event(
        "hr.communication.sent",
        resource_doctype=doc.doctype,
        resource_name=doc.name,
        company=doc.company,
        branch=doc.branch,
        after={"recipients": sorted(recipient_users(doc)), "priority": doc.priority},
    )


def validate_reply(doc, method: str | None = None) -> None:
    import frappe
    from frappe.utils import now_datetime

    communication = frappe.get_doc("ASOUD Internal Communication", doc.communication)
    if not communication.has_permission("read"):
        frappe.throw("Not permitted", frappe.PermissionError)
    if _UNSAFE_HTML.search(doc.body or ""):
        frappe.throw("Reply contains unsafe HTML")
    doc.company = communication.company
    doc.author = frappe.session.user
    doc.created_on = now_datetime()


def notify_reply(doc, method: str | None = None) -> None:
    import frappe

    communication = frappe.get_doc("ASOUD Internal Communication", doc.communication)
    users = recipient_users(communication) | {communication.sender}
    users.discard(frappe.session.user)
    for user in sorted(users):
        frappe.get_doc(
            {
                "doctype": "Notification Log",
                "subject": f"پاسخ جدید به: {communication.subject}",
                "for_user": user,
                "type": "Alert",
                "document_type": communication.doctype,
                "document_name": communication.name,
            }
        ).insert(ignore_permissions=True)


def validate_action(doc, method: str | None = None) -> None:
    import frappe
    from frappe.utils import now_datetime

    communication = frappe.get_doc("ASOUD Internal Communication", doc.communication)
    if not communication.has_permission("read"):
        frappe.throw("Not permitted", frappe.PermissionError)
    doc.company = communication.company
    doc.branch = communication.branch
    from asoud_core.permissions import can_access_context

    if not can_access_context(doc.assigned_to, doc.company, doc.branch):
        frappe.throw("Assigned user does not have access to the communication context")
    if doc.status == "Completed":
        if not (doc.result or "").strip():
            frappe.throw("A completed action requires a result")
        doc.completed_on = doc.completed_on or now_datetime()
    elif doc.completed_on:
        doc.completed_on = None


def register_view(communication_name: str) -> None:
    import frappe
    from frappe.utils import now_datetime

    communication = frappe.get_doc("ASOUD Internal Communication", communication_name)
    if not communication.has_permission("read"):
        frappe.throw("Not permitted", frappe.PermissionError)
    exists = frappe.db.exists(
        "ASOUD Communication View Log",
        {"communication": communication.name, "user": frappe.session.user},
    )
    if not exists:
        frappe.get_doc(
            {
                "doctype": "ASOUD Communication View Log",
                "communication": communication.name,
                "company": communication.company,
                "user": frappe.session.user,
                "viewed_on": now_datetime(),
                "ip_address": getattr(frappe.local, "request_ip", None),
            }
        ).insert(ignore_permissions=True)

