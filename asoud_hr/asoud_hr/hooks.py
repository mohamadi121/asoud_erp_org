"""Frappe v15 hooks for the ASOUD HR domain."""

app_name = "asoud_hr"
app_title = "ASOUD HR"
app_publisher = "ASOUD"
app_description = "Human resources and organizational work for ASOUD ERP"
app_email = "engineering@asoud.local"
app_license = "Proprietary"
required_apps = ["erpnext", "asoud_core", "asoud_iran"]

after_install = "asoud_hr.install.after_install"
after_migrate = "asoud_hr.install.after_migrate"

doc_events = {
    "Employee": {
        "validate": "asoud_hr.services.organization.validate_employee",
        "on_update": "asoud_hr.services.organization.record_employee_status_change",
    },
    "ASOUD Daily Work Report": {
        "before_validate": "asoud_hr.services.work_reports.prepare_report",
        "validate": "asoud_hr.services.work_reports.validate_report",
        "before_submit": "asoud_core.services.approval.assert_document_approved",
        "on_update": "asoud_core.services.approval.invalidate_changed_requests",
    },
    "ASOUD Internal Communication": {
        "before_validate": "asoud_hr.services.communications.prepare_communication",
        "validate": "asoud_hr.services.communications.validate_communication",
        "before_submit": "asoud_core.services.approval.assert_document_approved",
        "on_submit": "asoud_hr.services.communications.deliver_communication",
        "on_update": "asoud_core.services.approval.invalidate_changed_requests",
    },
    "ASOUD Communication Reply": {
        "validate": "asoud_hr.services.communications.validate_reply",
        "after_insert": "asoud_hr.services.communications.notify_reply",
    },
    "ASOUD Communication Action": {
        "validate": "asoud_hr.services.communications.validate_action",
    },
}

permission_query_conditions = {
    "Employee": "asoud_hr.permissions.employee_query",
    "ASOUD Organization Position": "asoud_hr.permissions.company_scoped_query",
    "ASOUD Employee Assignment": "asoud_hr.permissions.employee_assignment_query",
    "ASOUD Employee Document": "asoud_hr.permissions.employee_owned_query",
    "ASOUD Employment Status History": "asoud_hr.permissions.employee_owned_query",
    "ASOUD Daily Work Report": "asoud_hr.permissions.employee_owned_query",
    "ASOUD Internal Communication": "asoud_hr.permissions.communication_query",
    "ASOUD Communication Reply": "asoud_hr.permissions.reply_query",
    "ASOUD Communication Action": "asoud_hr.permissions.action_query",
    "ASOUD Communication View Log": "asoud_hr.permissions.view_log_query",
    "ASOUD HR Notification Preference": "asoud_hr.permissions.preference_query",
}

has_permission = {
    "Employee": "asoud_hr.permissions.employee_permission",
    "ASOUD Organization Position": "asoud_hr.permissions.company_scoped_permission",
    "ASOUD Employee Assignment": "asoud_hr.permissions.employee_document_permission",
    "ASOUD Employee Document": "asoud_hr.permissions.employee_document_permission",
    "ASOUD Employment Status History": "asoud_hr.permissions.employee_document_permission",
    "ASOUD Daily Work Report": "asoud_hr.permissions.employee_document_permission",
    "ASOUD Internal Communication": "asoud_hr.permissions.communication_permission",
    "ASOUD Communication Reply": "asoud_hr.permissions.reply_permission",
    "ASOUD Communication Action": "asoud_hr.permissions.action_permission",
    "ASOUD Communication View Log": "asoud_hr.permissions.view_log_permission",
    "ASOUD HR Notification Preference": "asoud_hr.permissions.preference_permission",
}
