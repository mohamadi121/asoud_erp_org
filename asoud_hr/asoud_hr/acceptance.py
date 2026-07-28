from __future__ import annotations


REQUIRED_DOCTYPES = (
    "ASOUD Organization Position",
    "ASOUD Employee Assignment",
    "ASOUD Employee Document",
    "ASOUD Employment Status History",
    "ASOUD Daily Work Report",
    "ASOUD Work Report Activity",
    "ASOUD Internal Communication",
    "ASOUD Communication Recipient",
    "ASOUD Communication Reply",
    "ASOUD Communication Action",
    "ASOUD Communication View Log",
    "ASOUD HR Notification Preference",
)


def run_hr_acceptance() -> dict:
    import frappe

    missing = [name for name in REQUIRED_DOCTYPES if not frappe.db.exists("DocType", name)]
    if missing:
        raise AssertionError(f"Missing ASOUD HR DocTypes: {missing}")
    employee_meta = frappe.get_meta("Employee")
    required_employee_fields = {
        "asoud_branch",
        "asoud_position",
        "asoud_national_id",
        "asoud_profile_visibility",
        "asoud_permission_version",
    }
    missing_fields = sorted(
        field for field in required_employee_fields if not employee_meta.has_field(field)
    )
    if missing_fields:
        raise AssertionError(f"Missing Employee HR fields: {missing_fields}")
    policy = frappe.db.get_value(
        "ASOUD Approval Policy",
        {"document_type": "ASOUD Daily Work Report", "enabled": 1},
        "name",
    )
    if not policy:
        raise AssertionError("Default daily work report approval policy is missing")
    return {
        "status": "passed",
        "app_version": __import__("asoud_hr").__version__,
        "doctype_count": len(REQUIRED_DOCTYPES),
        "approval_policy": policy,
        "employee_fields": sorted(required_employee_fields),
        "mobile_deferred": True,
        "hrms_operational_modules_deferred": True,
    }

