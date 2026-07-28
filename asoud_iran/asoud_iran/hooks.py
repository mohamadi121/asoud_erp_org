"""Frappe v15 application hooks."""

app_name = "asoud_iran"
app_title = "ASOUD Iran"
app_publisher = "ASOUD"
app_description = "Iranian accounting compliance for ASOUD"
app_email = "engineering@asoud.local"
app_license = "Proprietary"
required_apps = ["erpnext", "asoud_core"]

after_install = "asoud_iran.install.after_install"
after_migrate = "asoud_iran.install.after_migrate"

override_doctype_class = {
    "Journal Entry": "asoud_iran.overrides.journal_entry.ASOUDJournalEntry",
}

doc_events = {
    "Journal Entry": {
        "validate": "asoud_iran.services.floating_detail.validate_journal_entry_details",
    },
}

permission_query_conditions = {
    "ASOUD Floating Detail": "asoud_iran.permissions.floating_detail_query",
    "ASOUD Opening Balance Import": "asoud_iran.permissions.opening_import_query",
    "ASOUD Tax Settings": "asoud_iran.permissions.tax_settings_query",
    "ASOUD Tax Submission": "asoud_iran.permissions.tax_submission_query",
    "ASOUD Tax Event": "asoud_iran.permissions.tax_event_query",
}

has_permission = {
    "ASOUD Floating Detail": "asoud_iran.permissions.floating_detail_permission",
    "ASOUD Opening Balance Import": "asoud_iran.permissions.opening_import_permission",
    "ASOUD Tax Settings": "asoud_iran.permissions.tax_document_permission",
    "ASOUD Tax Submission": "asoud_iran.permissions.tax_document_permission",
    "ASOUD Tax Event": "asoud_iran.permissions.tax_document_permission",
}
