from __future__ import annotations


def _custom_fields() -> dict[str, list[dict]]:
    return {
        "Employee": [
            {
                "fieldname": "asoud_hr_section",
                "label": "ASOUD HR",
                "fieldtype": "Section Break",
                "insert_after": "reports_to",
            },
            {
                "fieldname": "asoud_branch",
                "label": "ASOUD Branch",
                "fieldtype": "Link",
                "options": "ASOUD Branch",
                "insert_after": "asoud_hr_section",
            },
            {
                "fieldname": "asoud_position",
                "label": "Organization Position",
                "fieldtype": "Link",
                "options": "ASOUD Organization Position",
                "insert_after": "asoud_branch",
            },
            {
                "fieldname": "asoud_national_id",
                "label": "Iranian National ID",
                "fieldtype": "Data",
                "unique": 1,
                "permlevel": 1,
                "insert_after": "asoud_position",
            },
            {
                "fieldname": "asoud_profile_visibility",
                "label": "Profile Visibility",
                "fieldtype": "Select",
                "options": "Private\nManager\nOrganization",
                "default": "Manager",
                "insert_after": "asoud_national_id",
            },
            {
                "fieldname": "asoud_permission_version",
                "label": "Permission Version",
                "fieldtype": "Int",
                "default": "1",
                "read_only": 1,
                "hidden": 1,
                "no_copy": 1,
                "insert_after": "asoud_profile_visibility",
            },
        ],
        "Department": [
            {
                "fieldname": "asoud_hr_section",
                "label": "ASOUD HR",
                "fieldtype": "Section Break",
                "insert_after": "company",
            },
            {
                "fieldname": "asoud_branch",
                "label": "ASOUD Branch",
                "fieldtype": "Link",
                "options": "ASOUD Branch",
                "insert_after": "asoud_hr_section",
            },
            {
                "fieldname": "asoud_manager_employee",
                "label": "Department Manager",
                "fieldtype": "Link",
                "options": "Employee",
                "insert_after": "asoud_branch",
            },
        ],
    }


def _install_custom_fields() -> None:
    from frappe.custom.doctype.custom_field.custom_field import create_custom_fields

    create_custom_fields(_custom_fields(), update=True)


def _ensure_roles() -> None:
    import frappe

    for role in ("ASOUD HR Manager", "ASOUD HR User", "ASOUD Employee", "ASOUD HR Auditor"):
        if not frappe.db.exists("Role", role):
            frappe.get_doc({"doctype": "Role", "role_name": role}).insert(ignore_permissions=True)


def _ensure_default_approval_policy() -> None:
    import frappe

    if frappe.db.exists(
        "ASOUD Approval Policy",
        {"document_type": "ASOUD Daily Work Report", "company": ["is", "not set"]},
    ):
        return
    frappe.get_doc(
        {
            "doctype": "ASOUD Approval Policy",
            "policy_title": "Default Daily Work Report Approval",
            "document_type": "ASOUD Daily Work Report",
            "enabled": 1,
            "priority": 10,
            "allow_self_approval": 0,
            "parallel_mode": "Any",
            "stages": [
                {
                    "sequence": 1,
                    "stage_title": "Direct Manager",
                    "approver_type": "Manager",
                    "due_hours": 24,
                },
                {
                    "sequence": 1,
                    "stage_title": "HR Fallback",
                    "approver_type": "Role",
                    "role": "ASOUD HR Manager",
                    "due_hours": 24,
                }
            ],
        }
    ).insert(ignore_permissions=True)


def after_install() -> None:
    _ensure_roles()
    _install_custom_fields()
    _ensure_default_approval_policy()


def after_migrate() -> None:
    _ensure_roles()
    _install_custom_fields()
    _ensure_default_approval_policy()
