from __future__ import annotations

from datetime import time, timedelta
from typing import Any


def time_to_seconds(value: Any) -> int | None:
    if value in (None, ""):
        return None
    if isinstance(value, timedelta):
        return int(value.total_seconds())
    if isinstance(value, time):
        return value.hour * 3600 + value.minute * 60 + value.second
    parsed = time.fromisoformat(str(value))
    return parsed.hour * 3600 + parsed.minute * 60 + parsed.second


def calculated_minutes(start: Any, end: Any) -> int | None:
    start_seconds = time_to_seconds(start)
    end_seconds = time_to_seconds(end)
    if start_seconds is None or end_seconds is None:
        return None
    if end_seconds < start_seconds:
        end_seconds += 24 * 3600
    return (end_seconds - start_seconds) // 60


def prepare_report(doc, method: str | None = None) -> None:
    import frappe

    if not doc.employee:
        doc.employee = frappe.db.get_value("Employee", {"user_id": frappe.session.user}, "name")
    employee = frappe.db.get_value(
        "Employee",
        doc.employee,
        ["user_id", "company", "department", "asoud_branch"],
        as_dict=True,
    )
    if not employee:
        frappe.throw("A work report must belong to an employee")
    doc.user = employee.user_id
    doc.company = employee.company
    doc.department = employee.department
    doc.branch = employee.asoud_branch
    doc.total_minutes = sum(int(row.duration_minutes or 0) for row in doc.activities)


def validate_report(doc, method: str | None = None) -> None:
    import frappe
    from frappe.utils import getdate, nowdate

    if not doc.activities:
        frappe.throw("A daily work report must contain at least one activity")
    if getdate(doc.report_date) > getdate(nowdate()):
        frappe.throw("A daily work report cannot be created for a future date")
    duplicate = frappe.db.exists(
        "ASOUD Daily Work Report",
        {
            "employee": doc.employee,
            "report_date": doc.report_date,
            "name": ["!=", doc.name or ""],
            "docstatus": ["<", 2],
        },
    )
    if duplicate:
        frappe.throw("Only one active daily work report is allowed per employee and date")
    for row in doc.activities:
        derived = calculated_minutes(row.started_at, row.ended_at)
        if derived is not None:
            if derived <= 0:
                frappe.throw("Activity end time must be after its start time")
            if row.duration_minutes and abs(int(row.duration_minutes) - derived) > 5:
                frappe.throw("Activity duration conflicts with its start and end time")
            row.duration_minutes = derived
        if int(row.duration_minutes or 0) <= 0:
            frappe.throw("Every activity must have a positive duration")
        if float(row.progress or 0) < 0 or float(row.progress or 0) > 100:
            frappe.throw("Activity progress must be between zero and one hundred")
    doc.total_minutes = sum(int(row.duration_minutes or 0) for row in doc.activities)
    if doc.total_minutes > 24 * 60:
        frappe.throw("Daily activity duration cannot exceed 24 hours")
    if int(doc.docstatus or 0) == 0 and doc.asoud_approval_status == "Approved":
        doc.workflow_status = "Approved"

