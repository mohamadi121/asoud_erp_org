from __future__ import annotations


def sync_custom_fields() -> None:
    from frappe.custom.doctype.custom_field.custom_field import create_custom_fields

    create_custom_fields(
        {
            "Account": [
                {
                    "fieldname": "asoud_account_level",
                    "label": "ASOUD Account Level",
                    "fieldtype": "Select",
                    "options": "Group\nLedger\nSubsidiary",
                    "insert_after": "account_number",
                    "in_list_view": 1,
                },
            ],
            "Journal Entry": [
                {
                    "fieldname": "asoud_iran_section",
                    "label": "ASOUD Iran",
                    "fieldtype": "Section Break",
                    "insert_after": "asoud_numbering_status",
                },
                {
                    "fieldname": "asoud_closing_run",
                    "label": "Closing Run",
                    "fieldtype": "Link",
                    "options": "ASOUD Closing Run",
                    "read_only": 1,
                    "no_copy": 1,
                    "insert_after": "asoud_iran_section",
                },
                {
                    "fieldname": "asoud_entry_kind",
                    "label": "Entry Kind",
                    "fieldtype": "Select",
                    "options": "\nProfit and Loss Closing\nPermanent Closing\nOpening",
                    "read_only": 1,
                    "no_copy": 1,
                    "insert_after": "asoud_closing_run",
                },
            ]
            ,
            "Journal Entry Account": [
                {
                    "fieldname": "asoud_branch",
                    "label": "ASOUD Branch",
                    "fieldtype": "Link",
                    "options": "ASOUD Branch",
                    "insert_after": "cost_center",
                    "in_list_view": 1,
                },
                {
                    "fieldname": "asoud_floating_detail",
                    "label": "تفصیلی شناور",
                    "fieldtype": "Link",
                    "options": "ASOUD Floating Detail",
                    "insert_after": "asoud_branch",
                    "in_list_view": 1,
                },
                {
                    "fieldname": "asoud_detail_code",
                    "label": "Floating Detail Code",
                    "fieldtype": "Data",
                    "read_only": 1,
                    "no_copy": 1,
                    "insert_after": "asoud_floating_detail",
                },
                {
                    "fieldname": "asoud_detail_type",
                    "label": "Floating Detail Type",
                    "fieldtype": "Data",
                    "read_only": 1,
                    "no_copy": 1,
                    "insert_after": "asoud_detail_code",
                },
            ],
            "GL Entry": [
                {
                    "fieldname": "asoud_branch",
                    "label": "ASOUD Branch",
                    "fieldtype": "Link",
                    "options": "ASOUD Branch",
                    "read_only": 1,
                    "no_copy": 1,
                    "in_standard_filter": 1,
                    "insert_after": "finance_book",
                },
                {
                    "fieldname": "asoud_floating_detail",
                    "label": "Floating Detail",
                    "fieldtype": "Link",
                    "options": "ASOUD Floating Detail",
                    "read_only": 1,
                    "no_copy": 1,
                    "in_standard_filter": 1,
                    "insert_after": "asoud_branch",
                },
                {
                    "fieldname": "asoud_detail_code",
                    "label": "Floating Detail Code",
                    "fieldtype": "Data",
                    "read_only": 1,
                    "no_copy": 1,
                    "insert_after": "asoud_floating_detail",
                },
                {
                    "fieldname": "asoud_detail_type",
                    "label": "Floating Detail Type",
                    "fieldtype": "Data",
                    "read_only": 1,
                    "no_copy": 1,
                    "insert_after": "asoud_detail_code",
                },
                {
                    "fieldname": "asoud_source_row",
                    "label": "ASOUD Source Row",
                    "fieldtype": "Data",
                    "read_only": 1,
                    "no_copy": 1,
                    "insert_after": "asoud_detail_type",
                },
            ],
            "User": [
                {
                    "fieldname": "asoud_iran_preferences",
                    "label": "ASOUD Iran Preferences",
                    "fieldtype": "Section Break",
                    "insert_after": "time_zone",
                },
                {
                    "fieldname": "asoud_amount_display_unit",
                    "label": "Amount Display Unit",
                    "fieldtype": "Select",
                    "options": "Use Company Default\nIRR\nTOMAN",
                    "default": "Use Company Default",
                    "insert_after": "asoud_iran_preferences",
                },
                {
                    "fieldname": "asoud_calendar_display",
                    "label": "Calendar Display",
                    "fieldtype": "Select",
                    "options": "Use Company Default\nJalali\nGregorian",
                    "default": "Use Company Default",
                    "insert_after": "asoud_amount_display_unit",
                },
            ],
        },
        update=True,
    )


def after_install() -> None:
    sync_custom_fields()
    from asoud_iran.services.iran_setup import ensure_default_template

    ensure_default_template()
    from asoud_iran.services.floating_detail_management import (
        ensure_groups_for_existing_details,
    )

    ensure_groups_for_existing_details()


def after_migrate() -> None:
    sync_custom_fields()
    from asoud_iran.services.iran_setup import ensure_default_template

    ensure_default_template()
    from asoud_iran.services.floating_detail_management import (
        ensure_groups_for_existing_details,
    )

    ensure_groups_for_existing_details()
