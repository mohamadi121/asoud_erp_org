from __future__ import annotations


def _custom_fields() -> dict[str, list[dict]]:
    fields = {
        "Company": [
            {
                "fieldname": "asoud_holding",
                "label": "ASOUD Holding",
                "fieldtype": "Link",
                "options": "ASOUD Holding",
                "insert_after": "company_name",
            },
            {
                "fieldname": "asoud_national_id",
                "label": "National ID",
                "fieldtype": "Data",
                "insert_after": "tax_id",
            },
            {
                "fieldname": "asoud_economic_code",
                "label": "Economic Code",
                "fieldtype": "Data",
                "insert_after": "asoud_national_id",
            },
            {
                "fieldname": "asoud_entity_type",
                "label": "Entity Type",
                "fieldtype": "Select",
                "options": "Legal\nNatural",
                "default": "Legal",
                "insert_after": "asoud_economic_code",
            },
            {
                "fieldname": "asoud_registration_number",
                "label": "Registration Number",
                "fieldtype": "Data",
                "insert_after": "asoud_entity_type",
            },
            {
                "fieldname": "asoud_legal_type",
                "label": "Legal Type",
                "fieldtype": "Data",
                "insert_after": "asoud_registration_number",
            },
            {
                "fieldname": "asoud_phone",
                "label": "Organization Phone",
                "fieldtype": "Data",
                "insert_after": "asoud_legal_type",
            },
            {
                "fieldname": "asoud_email",
                "label": "Organization Email",
                "fieldtype": "Data",
                "options": "Email",
                "insert_after": "asoud_phone",
            },
            {
                "fieldname": "asoud_website",
                "label": "Website",
                "fieldtype": "Data",
                "insert_after": "asoud_email",
            },
            {
                "fieldname": "asoud_province",
                "label": "Province",
                "fieldtype": "Data",
                "insert_after": "asoud_website",
            },
            {
                "fieldname": "asoud_city",
                "label": "City",
                "fieldtype": "Data",
                "insert_after": "asoud_province",
            },
            {
                "fieldname": "asoud_legal_address",
                "label": "Legal Address",
                "fieldtype": "Small Text",
                "insert_after": "asoud_city",
            },
            {
                "fieldname": "asoud_postal_code",
                "label": "Postal Code",
                "fieldtype": "Data",
                "insert_after": "asoud_legal_address",
            },
            {
                "fieldname": "asoud_logo",
                "label": "Organization Logo",
                "fieldtype": "Attach Image",
                "insert_after": "asoud_postal_code",
            },
            {
                "fieldname": "asoud_first_name",
                "label": "Natural Person First Name",
                "fieldtype": "Data",
                "insert_after": "asoud_logo",
            },
            {
                "fieldname": "asoud_last_name",
                "label": "Natural Person Last Name",
                "fieldtype": "Data",
                "insert_after": "asoud_first_name",
            },
            {
                "fieldname": "asoud_birth_date",
                "label": "Birth Date",
                "fieldtype": "Date",
                "insert_after": "asoud_last_name",
            },
            {
                "fieldname": "asoud_activity_type",
                "label": "Activity Type",
                "fieldtype": "Data",
                "insert_after": "asoud_birth_date",
            },
        ],
        "User Permission": [
            {
                "fieldname": "asoud_managed",
                "label": "Managed by ASOUD",
                "fieldtype": "Check",
                "default": "0",
                "hidden": 1,
                "read_only": 1,
                "no_copy": 1,
                "insert_after": "hide_descendants",
            }
        ],
        "Customer": [
            {
                "fieldname": "asoud_holding",
                "label": "ASOUD Holding",
                "fieldtype": "Link",
                "options": "ASOUD Holding",
                "insert_after": "customer_name",
                "in_standard_filter": 1,
            }
        ],
        "Supplier": [
            {
                "fieldname": "asoud_holding",
                "label": "ASOUD Holding",
                "fieldtype": "Link",
                "options": "ASOUD Holding",
                "insert_after": "supplier_name",
                "in_standard_filter": 1,
            }
        ],
        "Item": [
            {
                "fieldname": "asoud_holding",
                "label": "ASOUD Holding",
                "fieldtype": "Link",
                "options": "ASOUD Holding",
                "insert_after": "item_name",
                "in_standard_filter": 1,
            },
            {
                "fieldname": "asoud_item_kind",
                "label": "Item Kind",
                "fieldtype": "Select",
                "options": "Goods\nService",
                "default": "Goods",
                "insert_after": "asoud_holding",
                "in_standard_filter": 1,
            },
        ],
        "Warehouse": [
            {
                "fieldname": "asoud_branch",
                "label": "ASOUD Branch",
                "fieldtype": "Link",
                "options": "ASOUD Branch",
                "insert_after": "company",
                "in_standard_filter": 1,
            }
        ],
        "Journal Entry": [
            {
                "fieldname": "asoud_intercompany_transfer",
                "label": "ASOUD Intercompany Transfer",
                "fieldtype": "Link",
                "options": "ASOUD Intercompany Transfer",
                "read_only": 1,
                "no_copy": 1,
                "insert_after": "asoud_numbering_status",
                "in_standard_filter": 1,
            },
            {
                "fieldname": "asoud_counterparty_company",
                "label": "Counterparty Company",
                "fieldtype": "Link",
                "options": "Company",
                "read_only": 1,
                "no_copy": 1,
                "insert_after": "asoud_intercompany_transfer",
            },
        ],
    }
    accounting_doctypes = (
        "Journal Entry",
        "Sales Invoice",
        "Purchase Invoice",
        "Payment Entry",
        "Stock Entry",
        "Delivery Note",
        "Purchase Receipt",
        "Stock Reconciliation",
    )
    for doctype in accounting_doctypes:
        target = fields.setdefault(doctype, [])
        target.append({
                "fieldname": "asoud_branch",
                "label": "ASOUD Branch",
                "fieldtype": "Link",
                "options": "ASOUD Branch",
                "insert_after": "company",
                "in_standard_filter": 1,
                "in_list_view": 1,
            })
        target.extend(
            [
                {
                    "fieldname": "asoud_approval_section",
                    "label": "ASOUD Approval",
                    "fieldtype": "Section Break",
                    "insert_after": "asoud_branch",
                },
                {
                    "fieldname": "asoud_approval_request",
                    "label": "Approval Request",
                    "fieldtype": "Link",
                    "options": "ASOUD Approval Request",
                    "read_only": 1,
                    "no_copy": 1,
                    "in_standard_filter": 1,
                    "insert_after": "asoud_approval_section",
                },
                {
                    "fieldname": "asoud_approval_status",
                    "label": "Approval Status",
                    "fieldtype": "Select",
                    "options": "\nPending\nApproved\nRejected\nReturned\nCancelled\nInvalidated",
                    "read_only": 1,
                    "no_copy": 1,
                    "in_standard_filter": 1,
                    "insert_after": "asoud_approval_request",
                },
                {
                    "fieldname": "asoud_numbering_section",
                    "label": "ASOUD Numbering",
                    "fieldtype": "Section Break",
                    "insert_after": "asoud_approval_status",
                },
                {
                    "fieldname": "asoud_temporary_number",
                    "label": "Temporary Number",
                    "fieldtype": "Data",
                    "read_only": 1,
                    "no_copy": 1,
                    "in_standard_filter": 1,
                    "insert_after": "asoud_numbering_section",
                },
                {
                    "fieldname": "asoud_final_number",
                    "label": "Final Number",
                    "fieldtype": "Int",
                    "read_only": 1,
                    "no_copy": 1,
                    "in_standard_filter": 1,
                    "insert_after": "asoud_temporary_number",
                },
                {
                    "fieldname": "asoud_numbering_status",
                    "label": "Numbering Status",
                    "fieldtype": "Select",
                    "options": "Temporary\nFinal\nLocked\nCancelled",
                    "default": "Temporary",
                    "read_only": 1,
                    "no_copy": 1,
                    "insert_after": "asoud_final_number",
                },
            ]
        )
    for doctype in ("Quotation", "Sales Order", "Purchase Order", "Material Request"):
        fields.setdefault(doctype, []).append(
            {
                "fieldname": "asoud_branch",
                "label": "ASOUD Branch",
                "fieldtype": "Link",
                "options": "ASOUD Branch",
                "insert_after": "company",
                "in_standard_filter": 1,
                "in_list_view": 1,
            }
        )
    return fields


def sync_custom_fields() -> None:
    from frappe.custom.doctype.custom_field.custom_field import create_custom_fields

    create_custom_fields(_custom_fields(), update=True)


def after_install() -> None:
    sync_custom_fields()


def after_migrate() -> None:
    sync_custom_fields()
    from asoud_core.services.journal_numbering import backfill_legacy_documents

    backfill_legacy_documents()
