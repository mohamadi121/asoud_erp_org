from __future__ import annotations

from typing import Any


def date_ranges_overlap(
    first_start: Any,
    first_end: Any,
    second_start: Any,
    second_end: Any,
) -> bool:
    from datetime import date

    maximum = date.max
    return first_start <= (second_end or maximum) and second_start <= (first_end or maximum)


def validate_position(doc) -> None:
    import frappe

    if int(doc.capacity or 0) < 1:
        frappe.throw("Position capacity must be at least one")
    if doc.branch:
        branch_company = frappe.db.get_value("ASOUD Branch", doc.branch, "company")
        if branch_company != doc.company:
            frappe.throw("Position branch must belong to its company")
    department_company = frappe.db.get_value("Department", doc.department, "company")
    if department_company and department_company != doc.company:
        frappe.throw("Position department must belong to its company")
    if doc.reports_to_position:
        if doc.reports_to_position == doc.name:
            frappe.throw("A position cannot report to itself")
        parent_company = frappe.db.get_value(
            "ASOUD Organization Position", doc.reports_to_position, "company"
        )
        if parent_company != doc.company:
            frappe.throw("Parent position must belong to the same company")
        _assert_no_position_cycle(doc.name, doc.reports_to_position)


def _assert_no_position_cycle(name: str | None, parent: str | None) -> None:
    import frappe

    if not name or not parent:
        return
    visited = {name}
    current = parent
    while current:
        if current in visited:
            frappe.throw("Organization position hierarchy contains a cycle")
        visited.add(current)
        current = frappe.db.get_value(
            "ASOUD Organization Position", current, "reports_to_position"
        )


def validate_assignment(doc) -> None:
    import frappe

    if doc.to_date and doc.to_date < doc.from_date:
        frappe.throw("Assignment end date cannot be before its start date")
    employee = frappe.db.get_value(
        "Employee",
        doc.employee,
        ["company", "status"],
        as_dict=True,
    )
    if not employee or employee.company != doc.company:
        frappe.throw("Employee must belong to the assignment company")
    position = frappe.db.get_value(
        "ASOUD Organization Position",
        doc.position,
        ["company", "branch", "department", "capacity", "enabled"],
        as_dict=True,
    )
    if not position or not position.enabled or position.company != doc.company:
        frappe.throw("Assignment position must be enabled and belong to its company")
    if (position.branch or None) != (doc.branch or None):
        frappe.throw("Assignment branch must match the position branch")
    if position.department != doc.department:
        frappe.throw("Assignment department must match the position department")
    if doc.manager_employee == doc.employee:
        frappe.throw("An employee cannot be their own manager")

    overlaps = frappe.get_all(
        "ASOUD Employee Assignment",
        filters={"employee": doc.employee, "name": ["!=", doc.name or ""]},
        fields=["name", "from_date", "to_date"],
        limit_page_length=0,
    )
    if any(
        date_ranges_overlap(doc.from_date, doc.to_date, row.from_date, row.to_date)
        for row in overlaps
    ):
        frappe.throw("Employee assignment dates cannot overlap")

    if doc.active:
        occupied = frappe.db.count(
            "ASOUD Employee Assignment",
            {
                "position": doc.position,
                "active": 1,
                "name": ["!=", doc.name or ""],
            },
        )
        if occupied >= int(position.capacity or 1):
            frappe.throw("Organization position capacity has been reached")


def apply_active_assignment(doc) -> None:
    import frappe

    frappe.db.set_value(
        "Employee",
        doc.employee,
        {
            "company": doc.company,
            "department": doc.department,
            "reports_to": doc.manager_employee,
            "asoud_branch": doc.branch,
            "asoud_position": doc.position,
            "asoud_permission_version": (
                int(
                    frappe.db.get_value(
                        "Employee", doc.employee, "asoud_permission_version"
                    )
                    or 0
                )
                + 1
            ),
        },
    )
    frappe.db.set_value(
        "ASOUD Organization Position",
        doc.position,
        "manager_employee",
        doc.employee,
        update_modified=False,
    )
    from asoud_core.services.audit import append_event

    append_event(
        "hr.assignment.activated",
        resource_doctype=doc.doctype,
        resource_name=doc.name,
        company=doc.company,
        branch=doc.branch,
        after={
            "employee": doc.employee,
            "department": doc.department,
            "position": doc.position,
            "manager": doc.manager_employee,
        },
    )


def validate_employee(doc, method: str | None = None) -> None:
    import frappe

    from asoud_iran.services.identity import normalize_digits, validate_employee_national_id

    doc.asoud_national_id = normalize_digits(doc.asoud_national_id)
    validate_employee_national_id(doc.asoud_national_id)
    if doc.asoud_branch:
        company = frappe.db.get_value("ASOUD Branch", doc.asoud_branch, "company")
        if company != doc.company:
            frappe.throw("Employee branch must belong to the employee company")
    if doc.asoud_position:
        position = frappe.db.get_value(
            "ASOUD Organization Position",
            doc.asoud_position,
            ["company", "branch", "department"],
            as_dict=True,
        )
        if not position or position.company != doc.company:
            frappe.throw("Employee position must belong to the employee company")
        if (position.branch or None) != (doc.asoud_branch or None):
            frappe.throw("Employee position and branch do not match")
        if position.department != doc.department:
            frappe.throw("Employee position and department do not match")
    if doc.reports_to == doc.name:
        frappe.throw("An employee cannot report to themselves")
    _assert_no_manager_cycle(doc.name, doc.reports_to)


def _assert_no_manager_cycle(employee: str | None, manager: str | None) -> None:
    import frappe

    if not employee or not manager:
        return
    visited = {employee}
    current = manager
    while current:
        if current in visited:
            frappe.throw("Employee reporting hierarchy contains a cycle")
        visited.add(current)
        current = frappe.db.get_value("Employee", current, "reports_to")


def record_employee_status_change(doc, method: str | None = None) -> None:
    import frappe
    from frappe.utils import now_datetime

    previous = doc.get_doc_before_save()
    if not previous or previous.status == doc.status:
        return
    history = frappe.get_doc(
        {
            "doctype": "ASOUD Employment Status History",
            "employee": doc.name,
            "company": doc.company,
            "effective_on": now_datetime(),
            "previous_status": previous.status,
            "new_status": doc.status,
            "changed_by": frappe.session.user,
        }
    ).insert(ignore_permissions=True)
    from asoud_core.services.audit import append_event

    append_event(
        "hr.employee.status.changed",
        resource_doctype="Employee",
        resource_name=doc.name,
        company=doc.company,
        before={"status": previous.status},
        after={"status": doc.status, "history": history.name},
    )


def validate_employee_document(doc) -> None:
    import frappe

    employee_company = frappe.db.get_value("Employee", doc.employee, "company")
    if not employee_company:
        frappe.throw("Employee does not exist")
    doc.company = employee_company
    if doc.expires_on and doc.issued_on and doc.expires_on < doc.issued_on:
        frappe.throw("Document expiry cannot be before issue date")
    if doc.file:
        is_private = frappe.db.get_value("File", {"file_url": doc.file}, "is_private")
        if not is_private:
            frappe.throw("Employee attachments must be stored as private files")
