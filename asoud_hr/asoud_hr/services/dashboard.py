from __future__ import annotations

from typing import Any


def snapshot(company: str, branch: str | None = None) -> dict[str, Any]:
    import frappe
    from frappe.utils import nowdate

    from asoud_core.permissions import can_access_context

    if not can_access_context(frappe.session.user, company, branch):
        frappe.throw("Not permitted", frappe.PermissionError)
    employee_filters: dict[str, Any] = {"company": company, "status": "Active"}
    report_filters: dict[str, Any] = {"company": company, "report_date": nowdate()}
    communication_filters: dict[str, Any] = {"company": company, "status": ["!=", "Archived"]}
    action_filters: dict[str, Any] = {"company": company, "status": ["in", ["Open", "In Progress", "Blocked"]]}
    if branch:
        employee_filters["asoud_branch"] = branch
        report_filters["branch"] = branch
        communication_filters["branch"] = branch
        action_filters["branch"] = branch
    employee_count = frappe.db.count("Employee", employee_filters)
    report_count = frappe.db.count("ASOUD Daily Work Report", report_filters)
    return {
        "company": company,
        "branch": branch,
        "cards": {
            "active_employees": employee_count,
            "today_reports": report_count,
            "missing_reports": max(employee_count - report_count, 0),
            "open_communications": frappe.db.count(
                "ASOUD Internal Communication", communication_filters
            ),
            "open_actions": frappe.db.count("ASOUD Communication Action", action_filters),
        },
        "my": {
            "open_actions": frappe.db.count(
                "ASOUD Communication Action",
                {**action_filters, "assigned_to": frappe.session.user},
            ),
            "unread_notifications": frappe.db.count(
                "Notification Log",
                {"for_user": frappe.session.user, "read": 0},
            ),
        },
    }

