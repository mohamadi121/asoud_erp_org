from __future__ import annotations


_PRIVILEGED_ROLES = {"System Manager", "ASOUD HR Manager", "ASOUD HR Auditor"}


def _user(user: str | None) -> str:
    import frappe

    return user or frappe.session.user


def _is_privileged(user: str) -> bool:
    import frappe

    return bool(_PRIVILEGED_ROLES & set(frappe.get_roles(user)))


def _company_scope(user: str, field: str = "company") -> str:
    import frappe

    escaped = frappe.db.escape(user)
    return (
        f"exists (select 1 from `tabASOUD User Access` ua "
        f"where ua.user={escaped} and ua.enabled=1 and ua.company={field})"
    )


def _employee_scope(user: str, field: str = "employee") -> str:
    import frappe

    escaped = frappe.db.escape(user)
    return (
        f"{field} in (select e.name from `tabEmployee` e where e.user_id={escaped} "
        f"or e.reports_to in (select m.name from `tabEmployee` m where m.user_id={escaped}))"
    )


def company_scoped_query(user: str | None = None) -> str:
    user = _user(user)
    return "" if _is_privileged(user) else _company_scope(user)


def employee_query(user: str | None = None) -> str:
    import frappe

    user = _user(user)
    if _is_privileged(user):
        return ""
    escaped = frappe.db.escape(user)
    return (
        f"({_company_scope(user, '`tabEmployee`.company')} and "
        f"(`tabEmployee`.user_id={escaped} or `tabEmployee`.reports_to in "
        f"(select m.name from `tabEmployee` m where m.user_id={escaped})))"
    )


def employee_owned_query(user: str | None = None) -> str:
    user = _user(user)
    if _is_privileged(user):
        return ""
    return f"({_company_scope(user)} and {_employee_scope(user)})"


def employee_assignment_query(user: str | None = None) -> str:
    return employee_owned_query(user)


def communication_query(user: str | None = None) -> str:
    import frappe

    user = _user(user)
    if _is_privileged(user):
        return ""
    escaped = frappe.db.escape(user)
    return (
        f"({_company_scope(user, '`tabASOUD Internal Communication`.company')} and ("
        f"`tabASOUD Internal Communication`.sender={escaped} or exists ("
        f"select 1 from `tabASOUD Communication Recipient` cr "
        f"where cr.parent=`tabASOUD Internal Communication`.name "
        f"and cr.parenttype='ASOUD Internal Communication' and (cr.user={escaped} "
        f"or cr.department in (select e.department from `tabEmployee` e "
        f"where e.user_id={escaped}))))))"
    )


def reply_query(user: str | None = None) -> str:
    import frappe

    user = _user(user)
    if _is_privileged(user):
        return ""
    escaped = frappe.db.escape(user)
    return (
        "exists (select 1 from `tabASOUD Internal Communication` c "
        "where c.name=`tabASOUD Communication Reply`.communication and "
        f"(c.sender={escaped} or exists (select 1 from "
        "`tabASOUD Communication Recipient` cr where cr.parent=c.name and "
        f"(cr.user={escaped} or cr.department in (select e.department "
        f"from `tabEmployee` e where e.user_id={escaped})))))"
    )


def action_query(user: str | None = None) -> str:
    import frappe

    user = _user(user)
    if _is_privileged(user):
        return ""
    escaped = frappe.db.escape(user)
    return (
        f"(`tabASOUD Communication Action`.assigned_to={escaped} or "
        f"exists (select 1 from `tabASOUD Internal Communication` c where "
        f"c.name=`tabASOUD Communication Action`.communication and c.sender={escaped}))"
    )


def view_log_query(user: str | None = None) -> str:
    user = _user(user)
    return "" if _is_privileged(user) else "1=0"


def preference_query(user: str | None = None) -> str:
    import frappe

    user = _user(user)
    if _is_privileged(user):
        return ""
    return f"`tabASOUD HR Notification Preference`.user={frappe.db.escape(user)}"


def _can_access_company(user: str, company: str | None, branch: str | None = None) -> bool:
    if _is_privileged(user):
        return True
    if not company:
        return False
    from asoud_core.permissions import can_access_context

    return bool(can_access_context(user, company, branch))


def _employee_is_visible(user: str, employee: str | None) -> bool:
    import frappe

    if _is_privileged(user):
        return True
    if not employee:
        return False
    row = frappe.db.get_value(
        "Employee", employee, ["user_id", "reports_to"], as_dict=True
    )
    if not row:
        return False
    if row.user_id == user:
        return True
    manager_user = frappe.db.get_value("Employee", row.reports_to, "user_id")
    return manager_user == user


def company_scoped_permission(doc, user: str | None = None, permission_type: str | None = None):
    user = _user(user)
    return _can_access_company(user, doc.company, getattr(doc, "branch", None))


def employee_permission(doc, user: str | None = None, permission_type: str | None = None):
    user = _user(user)
    return _can_access_company(user, doc.company, getattr(doc, "asoud_branch", None)) and (
        _is_privileged(user) or _employee_is_visible(user, doc.name)
    )


def employee_document_permission(
    doc, user: str | None = None, permission_type: str | None = None
):
    user = _user(user)
    if not _can_access_company(user, doc.company, getattr(doc, "branch", None)):
        return False
    if _is_privileged(user):
        return True
    if not _employee_is_visible(user, doc.employee):
        return False
    if permission_type in {"write", "create", "submit", "cancel", "delete"}:
        employee_user = __import__("frappe").db.get_value("Employee", doc.employee, "user_id")
        return employee_user == user
    return True


def communication_permission(
    doc, user: str | None = None, permission_type: str | None = None
):
    user = _user(user)
    if not _can_access_company(user, doc.company, getattr(doc, "branch", None)):
        return False
    if _is_privileged(user) or doc.sender == user:
        return True
    recipients = {
        row.user
        for row in getattr(doc, "recipients", [])
        if row.recipient_type == "User" and row.user
    }
    if user in recipients:
        return permission_type in {None, "read", "select"}
    import frappe

    employee_department = frappe.db.get_value("Employee", {"user_id": user}, "department")
    department_recipient = any(
        row.recipient_type == "Department" and row.department == employee_department
        for row in getattr(doc, "recipients", [])
    )
    return department_recipient and permission_type in {None, "read", "select"}


def reply_permission(doc, user: str | None = None, permission_type: str | None = None):
    import frappe

    communication = frappe.get_doc("ASOUD Internal Communication", doc.communication)
    if permission_type in {"write", "delete"}:
        return False
    return communication_permission(communication, user, "read")


def action_permission(doc, user: str | None = None, permission_type: str | None = None):
    import frappe

    user = _user(user)
    if _is_privileged(user) or doc.assigned_to == user:
        return True
    communication = frappe.get_doc("ASOUD Internal Communication", doc.communication)
    return communication.sender == user


def view_log_permission(doc, user: str | None = None, permission_type: str | None = None):
    return _is_privileged(_user(user)) and permission_type in {None, "read", "select"}


def preference_permission(
    doc, user: str | None = None, permission_type: str | None = None
):
    user = _user(user)
    return _is_privileged(user) or doc.user == user

