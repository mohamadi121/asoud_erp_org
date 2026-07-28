from __future__ import annotations

import json
from typing import Any


def _whitelist(*args, **kwargs):
    import frappe

    return frappe.whitelist(*args, **kwargs)


def _payload(value: str | dict | list) -> Any:
    return json.loads(value) if isinstance(value, str) else value


def _assert_context(company: str, branch: str | None = None) -> None:
    import frappe
    from asoud_core.permissions import can_access_context

    if not can_access_context(frappe.session.user, company, branch or None):
        frappe.throw("Not permitted", frappe.PermissionError)


@_whitelist(methods=["GET"])
def dashboard(company: str, branch: str | None = None) -> dict:
    from asoud_hr.services.dashboard import snapshot

    return snapshot(company, branch or None)


@_whitelist(methods=["GET"])
def organization(company: str, branch: str | None = None) -> dict:
    import frappe

    branch = branch or None
    _assert_context(company, branch)
    position_filters: dict[str, Any] = {"company": company, "enabled": 1}
    employee_filters: dict[str, Any] = {"company": company, "status": "Active"}
    if branch:
        position_filters["branch"] = branch
        employee_filters["asoud_branch"] = branch
    return {
        "positions": frappe.get_all(
            "ASOUD Organization Position",
            filters=position_filters,
            fields=[
                "name",
                "position_title",
                "position_code",
                "department",
                "designation",
                "reports_to_position",
                "manager_employee",
                "capacity",
            ],
            order_by="position_title",
            limit_page_length=0,
        ),
        "employees": frappe.get_all(
            "Employee",
            filters=employee_filters,
            fields=[
                "name",
                "employee_name",
                "department",
                "designation",
                "reports_to",
                "asoud_branch",
                "asoud_position",
                "user_id",
            ],
            order_by="employee_name",
            limit_page_length=0,
        ),
    }


@_whitelist(methods=["GET"])
def employees(
    company: str,
    branch: str | None = None,
    search: str | None = None,
    page: int = 1,
    page_length: int = 25,
) -> dict:
    import frappe

    branch = branch or None
    _assert_context(company, branch)
    page = max(int(page or 1), 1)
    page_length = min(max(int(page_length or 25), 1), 100)
    filters: dict[str, Any] = {"company": company}
    if branch:
        filters["asoud_branch"] = branch
    or_filters = (
        {"employee_name": ["like", f"%{search.strip()}%"], "name": ["like", f"%{search.strip()}%"]}
        if search and search.strip()
        else None
    )
    rows = frappe.get_list(
        "Employee",
        filters=filters,
        or_filters=or_filters,
        fields=[
            "name",
            "employee_name",
            "status",
            "department",
            "designation",
            "reports_to",
            "asoud_branch",
            "asoud_position",
        ],
        order_by="employee_name",
        start=(page - 1) * page_length,
        page_length=page_length,
    )
    return {"page": page, "page_length": page_length, "items": rows}


@_whitelist(methods=["GET"])
def employee_profile(employee: str) -> dict:
    import frappe

    doc = frappe.get_doc("Employee", employee)
    if not doc.has_permission("read"):
        frappe.throw("Not permitted", frappe.PermissionError)
    roles = set(frappe.get_roles(frappe.session.user))
    sensitive = bool({"System Manager", "ASOUD HR Manager"} & roles)
    national_id = doc.asoud_national_id if sensitive else None
    return {
        "employee": {
            "name": doc.name,
            "employee_name": doc.employee_name,
            "company": doc.company,
            "branch": doc.asoud_branch,
            "department": doc.department,
            "designation": doc.designation,
            "position": doc.asoud_position,
            "reports_to": doc.reports_to,
            "status": doc.status,
            "date_of_joining": doc.date_of_joining,
            "national_id": national_id,
            "national_id_masked": (
                f"******{doc.asoud_national_id[-4:]}"
                if doc.asoud_national_id and not sensitive
                else national_id
            ),
        },
        "assignments": frappe.get_list(
            "ASOUD Employee Assignment",
            filters={"employee": employee},
            fields=["name", "department", "position", "manager_employee", "from_date", "to_date", "active"],
            order_by="from_date desc",
            limit_page_length=0,
        ),
        "status_history": frappe.get_list(
            "ASOUD Employment Status History",
            filters={"employee": employee},
            fields=["effective_on", "previous_status", "new_status", "reason"],
            order_by="effective_on desc",
            limit_page_length=0,
        ),
    }


@_whitelist(methods=["GET"])
def work_reports(
    company: str,
    branch: str | None = None,
    status: str | None = None,
    page: int = 1,
) -> dict:
    import frappe

    branch = branch or None
    _assert_context(company, branch)
    filters: dict[str, Any] = {"company": company}
    if branch:
        filters["branch"] = branch
    if status:
        filters["workflow_status"] = status
    page = max(int(page or 1), 1)
    return {
        "page": page,
        "items": frappe.get_list(
            "ASOUD Daily Work Report",
            filters=filters,
            fields=[
                "name",
                "employee",
                "employee_name",
                "report_date",
                "workflow_status",
                "total_minutes",
                "asoud_approval_status",
                "modified",
            ],
            order_by="report_date desc, modified desc",
            start=(page - 1) * 25,
            page_length=25,
        ),
    }


@_whitelist(methods=["POST"])
def save_work_report(request_key: str, data: str | dict) -> dict:
    import frappe
    from asoud_core.services.idempotency import execute_once

    values = _payload(data)

    def create() -> dict:
        doc = frappe.get_doc({"doctype": "ASOUD Daily Work Report", **values})
        doc.insert()
        return {"name": doc.name, "status": doc.workflow_status, "modified": str(doc.modified)}

    return execute_once(request_key, "hr.work_report.create", values, create)


@_whitelist(methods=["POST"])
def request_work_report_approval(name: str, request_key: str) -> dict:
    from asoud_core.services.idempotency import execute_once
    from asoud_core.services.approval import start_request

    return execute_once(
        request_key,
        "hr.work_report.request_approval",
        {"name": name},
        lambda: start_request("ASOUD Daily Work Report", name),
    )


@_whitelist(methods=["GET"])
def communications(
    company: str,
    branch: str | None = None,
    box: str = "inbox",
    page: int = 1,
) -> dict:
    import frappe

    branch = branch or None
    _assert_context(company, branch)
    filters: dict[str, Any] = {"company": company}
    if branch:
        filters["branch"] = branch
    if box == "sent":
        filters["sender"] = frappe.session.user
    elif box == "archive":
        filters["status"] = "Archived"
    else:
        filters["status"] = ["!=", "Archived"]
    page = max(int(page or 1), 1)
    return {
        "box": box,
        "page": page,
        "items": frappe.get_list(
            "ASOUD Internal Communication",
            filters=filters,
            fields=[
                "name",
                "communication_type",
                "subject",
                "sender",
                "priority",
                "confidentiality",
                "response_due_on",
                "status",
                "modified",
            ],
            order_by="modified desc",
            start=(page - 1) * 25,
            page_length=25,
        ),
    }


@_whitelist(methods=["POST"])
def create_communication(request_key: str, data: str | dict) -> dict:
    import frappe
    from asoud_core.services.idempotency import execute_once

    values = _payload(data)

    def create() -> dict:
        doc = frappe.get_doc({"doctype": "ASOUD Internal Communication", **values})
        doc.insert()
        return {"name": doc.name, "status": doc.status, "modified": str(doc.modified)}

    return execute_once(request_key, "hr.communication.create", values, create)


@_whitelist(methods=["GET"])
def communication_detail(name: str) -> dict:
    import frappe
    from asoud_hr.services.communications import register_view

    doc = frappe.get_doc("ASOUD Internal Communication", name)
    if not doc.has_permission("read"):
        frappe.throw("Not permitted", frappe.PermissionError)
    register_view(name)
    return {
        "communication": doc.as_dict(no_nulls=True),
        "replies": frappe.get_list(
            "ASOUD Communication Reply",
            filters={"communication": name},
            fields=["name", "author", "body", "created_on", "parent_reply"],
            order_by="created_on",
            limit_page_length=0,
        ),
        "actions": frappe.get_list(
            "ASOUD Communication Action",
            filters={"communication": name},
            fields=["name", "action_title", "assigned_to", "due_on", "status", "result", "work_report"],
            order_by="creation",
            limit_page_length=0,
        ),
    }


@_whitelist(methods=["POST"])
def add_reply(request_key: str, communication: str, body: str) -> dict:
    import frappe
    from asoud_core.services.idempotency import execute_once

    payload = {"communication": communication, "body": body}

    def create() -> dict:
        doc = frappe.get_doc(
            {"doctype": "ASOUD Communication Reply", **payload}
        ).insert()
        return {"name": doc.name, "created_on": str(doc.created_on)}

    return execute_once(request_key, "hr.communication.reply", payload, create)


@_whitelist(methods=["POST"])
def create_action(request_key: str, data: str | dict) -> dict:
    import frappe
    from asoud_core.services.idempotency import execute_once

    values = _payload(data)

    def create() -> dict:
        doc = frappe.get_doc({"doctype": "ASOUD Communication Action", **values}).insert()
        return {"name": doc.name, "status": doc.status}

    return execute_once(request_key, "hr.communication.action", values, create)


@_whitelist(methods=["GET"])
def notifications(page: int = 1) -> dict:
    import frappe

    page = max(int(page or 1), 1)
    return {
        "page": page,
        "items": frappe.get_list(
            "Notification Log",
            filters={"for_user": frappe.session.user},
            fields=["name", "subject", "type", "document_type", "document_name", "read", "creation"],
            order_by="creation desc",
            start=(page - 1) * 25,
            page_length=25,
        ),
    }

