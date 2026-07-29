"""Frappe v15 application hooks.

Keep this module declarative. Business rules belong to application services.
"""

app_name = "asoud_core"
app_title = "ASOUD Core"
app_publisher = "ASOUD"
app_description = "Shared ASOUD ERP services"
app_email = "engineering@asoud.local"
app_license = "Proprietary"
required_apps = ["erpnext"]

after_install = "asoud_core.install.after_install"
after_migrate = "asoud_core.install.after_migrate"
boot_session = "asoud_core.boot.boot_session"

doc_events = {
    "Company": {
        "on_update": "asoud_core.services.user_permissions.sync_holding_managers",
    },
    "Customer": {"validate": "asoud_core.services.operations.validate_shared_master"},
    "Supplier": {"validate": "asoud_core.services.operations.validate_shared_master"},
    "Item": {"validate": "asoud_core.services.operations.validate_shared_master"},
    "Warehouse": {"validate": "asoud_core.services.operations.validate_warehouse"},
    "Journal Entry": {
        "before_validate": "asoud_core.services.organization_context.apply_active_context",
        "validate": "asoud_core.services.organization_context.validate_document_context",
        "before_submit": [
            "asoud_core.services.approval.assert_document_approved",
            "asoud_core.services.journal_numbering.assign_temporary_number",
        ],
        "on_submit": "asoud_core.services.journal_numbering.register_submitted_document",
        "before_cancel": [
            "asoud_core.services.organization_context.assert_period_open",
            "asoud_core.services.journal_numbering.assert_numbering_allows_cancel",
        ],
        "on_cancel": "asoud_core.services.journal_numbering.mark_cancelled",
        "on_update": "asoud_core.services.approval.invalidate_changed_requests",
    },
    "Sales Invoice": {
        "before_validate": [
            "asoud_core.services.organization_context.apply_active_context",
            "asoud_core.services.operations.apply_operational_defaults",
        ],
        "validate": [
            "asoud_core.services.organization_context.validate_document_context",
            "asoud_core.services.operations.validate_operational_document",
        ],
        "before_submit": [
            "asoud_core.services.approval.assert_document_approved",
            "asoud_core.services.journal_numbering.assign_temporary_number",
        ],
        "on_submit": "asoud_core.services.journal_numbering.register_submitted_document",
        "before_cancel": ["asoud_core.services.organization_context.assert_period_open", "asoud_core.services.journal_numbering.assert_numbering_allows_cancel"],
        "on_cancel": "asoud_core.services.journal_numbering.mark_cancelled",
        "on_update": "asoud_core.services.approval.invalidate_changed_requests",
    },
    "Purchase Invoice": {
        "before_validate": [
            "asoud_core.services.organization_context.apply_active_context",
            "asoud_core.services.operations.apply_operational_defaults",
        ],
        "validate": [
            "asoud_core.services.organization_context.validate_document_context",
            "asoud_core.services.operations.validate_operational_document",
        ],
        "before_submit": [
            "asoud_core.services.approval.assert_document_approved",
            "asoud_core.services.journal_numbering.assign_temporary_number",
        ],
        "on_submit": "asoud_core.services.journal_numbering.register_submitted_document",
        "before_cancel": ["asoud_core.services.organization_context.assert_period_open", "asoud_core.services.journal_numbering.assert_numbering_allows_cancel"],
        "on_cancel": "asoud_core.services.journal_numbering.mark_cancelled",
        "on_update": "asoud_core.services.approval.invalidate_changed_requests",
    },
    "Payment Entry": {
        "before_validate": "asoud_core.services.organization_context.apply_active_context",
        "validate": "asoud_core.services.organization_context.validate_document_context",
        "before_submit": [
            "asoud_core.services.approval.assert_document_approved",
            "asoud_core.services.journal_numbering.assign_temporary_number",
        ],
        "on_submit": "asoud_core.services.journal_numbering.register_submitted_document",
        "before_cancel": ["asoud_core.services.organization_context.assert_period_open", "asoud_core.services.journal_numbering.assert_numbering_allows_cancel"],
        "on_cancel": "asoud_core.services.journal_numbering.mark_cancelled",
        "on_update": "asoud_core.services.approval.invalidate_changed_requests",
    },
    "Stock Entry": {
        "before_validate": "asoud_core.services.organization_context.apply_active_context",
        "validate": [
            "asoud_core.services.organization_context.validate_document_context",
            "asoud_core.services.operations.validate_operational_document",
        ],
        "before_submit": [
            "asoud_core.services.approval.assert_document_approved",
            "asoud_core.services.journal_numbering.assign_temporary_number",
        ],
        "on_submit": "asoud_core.services.journal_numbering.register_submitted_document",
        "before_cancel": ["asoud_core.services.organization_context.assert_period_open", "asoud_core.services.journal_numbering.assert_numbering_allows_cancel"],
        "on_cancel": "asoud_core.services.journal_numbering.mark_cancelled",
        "on_update": "asoud_core.services.approval.invalidate_changed_requests",
    },
    "Delivery Note": {
        "before_validate": [
            "asoud_core.services.organization_context.apply_active_context",
            "asoud_core.services.operations.apply_operational_defaults",
        ],
        "validate": [
            "asoud_core.services.organization_context.validate_document_context",
            "asoud_core.services.operations.validate_operational_document",
        ],
        "before_submit": [
            "asoud_core.services.approval.assert_document_approved",
            "asoud_core.services.journal_numbering.assign_temporary_number",
        ],
        "on_submit": "asoud_core.services.journal_numbering.register_submitted_document",
        "before_cancel": ["asoud_core.services.organization_context.assert_period_open", "asoud_core.services.journal_numbering.assert_numbering_allows_cancel"],
        "on_cancel": "asoud_core.services.journal_numbering.mark_cancelled",
        "on_update": "asoud_core.services.approval.invalidate_changed_requests",
    },
    "Purchase Receipt": {
        "before_validate": [
            "asoud_core.services.organization_context.apply_active_context",
            "asoud_core.services.operations.apply_operational_defaults",
        ],
        "validate": [
            "asoud_core.services.organization_context.validate_document_context",
            "asoud_core.services.operations.validate_operational_document",
        ],
        "before_submit": [
            "asoud_core.services.approval.assert_document_approved",
            "asoud_core.services.journal_numbering.assign_temporary_number",
        ],
        "on_submit": "asoud_core.services.journal_numbering.register_submitted_document",
        "before_cancel": ["asoud_core.services.organization_context.assert_period_open", "asoud_core.services.journal_numbering.assert_numbering_allows_cancel"],
        "on_cancel": "asoud_core.services.journal_numbering.mark_cancelled",
        "on_update": "asoud_core.services.approval.invalidate_changed_requests",
    },
    "Stock Reconciliation": {
        "before_validate": "asoud_core.services.organization_context.apply_active_context",
        "validate": [
            "asoud_core.services.organization_context.validate_document_context",
            "asoud_core.services.operations.validate_operational_document",
        ],
        "before_submit": [
            "asoud_core.services.approval.assert_document_approved",
            "asoud_core.services.journal_numbering.assign_temporary_number",
        ],
        "on_submit": "asoud_core.services.journal_numbering.register_submitted_document",
        "before_cancel": ["asoud_core.services.organization_context.assert_period_open", "asoud_core.services.journal_numbering.assert_numbering_allows_cancel"],
        "on_cancel": "asoud_core.services.journal_numbering.mark_cancelled",
        "on_update": "asoud_core.services.approval.invalidate_changed_requests",
    },
    "Sales Order": {
        "before_validate": [
            "asoud_core.services.organization_context.apply_active_context",
            "asoud_core.services.operations.apply_operational_defaults",
        ],
        "validate": [
            "asoud_core.services.organization_context.validate_document_context",
            "asoud_core.services.operations.validate_operational_document",
        ],
    },
    "Purchase Order": {
        "before_validate": [
            "asoud_core.services.organization_context.apply_active_context",
            "asoud_core.services.operations.apply_operational_defaults",
        ],
        "validate": [
            "asoud_core.services.organization_context.validate_document_context",
            "asoud_core.services.operations.validate_operational_document",
        ],
    },
    "Quotation": {
        "before_validate": [
            "asoud_core.services.organization_context.apply_active_context",
            "asoud_core.services.operations.apply_operational_defaults",
        ],
        "validate": [
            "asoud_core.services.organization_context.validate_document_context",
            "asoud_core.services.operations.validate_operational_document",
        ],
    },
    "Material Request": {
        "before_validate": "asoud_core.services.organization_context.apply_active_context",
        "validate": [
            "asoud_core.services.organization_context.validate_document_context",
            "asoud_core.services.operations.validate_operational_document",
        ],
    },
}

permission_query_conditions = {
    "Customer": "asoud_core.permissions.customer_query",
    "Supplier": "asoud_core.permissions.supplier_query",
    "Item": "asoud_core.permissions.item_query",
    "ASOUD Branch": "asoud_core.permissions.branch_query",
    "ASOUD User Access": "asoud_core.permissions.user_access_query",
    "Journal Entry": "asoud_core.permissions.journal_entry_query",
    "Sales Invoice": "asoud_core.permissions.sales_invoice_query",
    "Purchase Invoice": "asoud_core.permissions.purchase_invoice_query",
    "Payment Entry": "asoud_core.permissions.payment_entry_query",
    "Stock Entry": "asoud_core.permissions.stock_entry_query",
    "Delivery Note": "asoud_core.permissions.delivery_note_query",
    "Purchase Receipt": "asoud_core.permissions.purchase_receipt_query",
    "Stock Reconciliation": "asoud_core.permissions.stock_reconciliation_query",
    "Sales Order": "asoud_core.permissions.sales_order_query",
    "Purchase Order": "asoud_core.permissions.purchase_order_query",
    "Quotation": "asoud_core.permissions.quotation_query",
    "Material Request": "asoud_core.permissions.material_request_query",
    "ASOUD Party Company Profile": "asoud_core.permissions.party_profile_query",
    "ASOUD Item Company Profile": "asoud_core.permissions.item_profile_query",
    "ASOUD Treasury Account": "asoud_core.permissions.treasury_account_query",
    "ASOUD Treasury Transaction": "asoud_core.permissions.treasury_transaction_query",
    "ASOUD Petty Cash Claim": "asoud_core.permissions.petty_cash_claim_query",
    "ASOUD Cheque": "asoud_core.permissions.cheque_query",
    "ASOUD Cheque Event": "asoud_core.permissions.cheque_event_query",
    "ASOUD Cash Count": "asoud_core.permissions.cash_count_query",
    "ASOUD Bank Reconciliation": "asoud_core.permissions.bank_reconciliation_query",
    "ASOUD Bank Connection": "asoud_core.permissions.bank_connection_query",
    "ASOUD Bank Statement Import": "asoud_core.permissions.bank_statement_import_query",
    "ASOUD Bank Statement Line": "asoud_core.permissions.bank_statement_line_query",
    "ASOUD Sayad Operation": "asoud_core.permissions.sayad_operation_query",
    "ASOUD Sayad Event": "asoud_core.permissions.sayad_event_query",
    "ASOUD Intercompany Transfer": "asoud_core.permissions.intercompany_transfer_query",
    "ASOUD Consolidation Account Map": "asoud_core.permissions.consolidation_map_query",
    "ASOUD Consolidation Adjustment": "asoud_core.permissions.consolidation_adjustment_query",
    "ASOUD FX Policy": "asoud_core.permissions.fx_policy_query",
    "ASOUD FX Rate": "asoud_core.permissions.fx_rate_query",
    "ASOUD Migration Run": "asoud_core.permissions.migration_run_query",
    "ASOUD Cutover Run": "asoud_core.permissions.cutover_run_query",
    "ASOUD Audit Event": "asoud_core.permissions.audit_event_query",
    "ASOUD Approval Policy": "asoud_core.permissions.approval_policy_query",
    "ASOUD Approval Request": "asoud_core.permissions.approval_request_query",
    "ASOUD Approval Action": "asoud_core.permissions.approval_action_query",
    "ASOUD Approval Delegation": "asoud_core.permissions.approval_delegation_query",
    "ASOUD User Access Schedule": "asoud_core.permissions.access_schedule_query",
    "ASOUD Fiscal Period": "asoud_core.permissions.fiscal_period_query",
    "ASOUD Period Lock": "asoud_core.permissions.period_lock_query",
    "ASOUD Party Identity": "asoud_core.permissions.party_identity_query",
    "ASOUD Party Code Series": "asoud_core.permissions.party_code_series_query",
}

has_permission = {
    "Customer": "asoud_core.permissions.shared_master_permission",
    "Supplier": "asoud_core.permissions.shared_master_permission",
    "Item": "asoud_core.permissions.shared_master_permission",
    "ASOUD Branch": "asoud_core.permissions.branch_permission",
    "ASOUD User Access": "asoud_core.permissions.user_access_permission",
    "Journal Entry": "asoud_core.permissions.standard_document_permission",
    "Sales Invoice": "asoud_core.permissions.standard_document_permission",
    "Purchase Invoice": "asoud_core.permissions.standard_document_permission",
    "Payment Entry": "asoud_core.permissions.standard_document_permission",
    "Stock Entry": "asoud_core.permissions.standard_document_permission",
    "Delivery Note": "asoud_core.permissions.standard_document_permission",
    "Purchase Receipt": "asoud_core.permissions.standard_document_permission",
    "Stock Reconciliation": "asoud_core.permissions.standard_document_permission",
    "Sales Order": "asoud_core.permissions.standard_document_permission",
    "Purchase Order": "asoud_core.permissions.standard_document_permission",
    "Quotation": "asoud_core.permissions.standard_document_permission",
    "Material Request": "asoud_core.permissions.standard_document_permission",
    "ASOUD Party Company Profile": "asoud_core.permissions.company_profile_permission",
    "ASOUD Item Company Profile": "asoud_core.permissions.company_profile_permission",
    "ASOUD Treasury Account": "asoud_core.permissions.treasury_document_permission",
    "ASOUD Treasury Transaction": "asoud_core.permissions.treasury_document_permission",
    "ASOUD Petty Cash Claim": "asoud_core.permissions.treasury_document_permission",
    "ASOUD Cheque": "asoud_core.permissions.treasury_document_permission",
    "ASOUD Cheque Event": "asoud_core.permissions.treasury_document_permission",
    "ASOUD Cash Count": "asoud_core.permissions.treasury_document_permission",
    "ASOUD Bank Reconciliation": "asoud_core.permissions.treasury_document_permission",
    "ASOUD Bank Connection": "asoud_core.permissions.treasury_document_permission",
    "ASOUD Bank Statement Import": "asoud_core.permissions.treasury_document_permission",
    "ASOUD Bank Statement Line": "asoud_core.permissions.treasury_document_permission",
    "ASOUD Sayad Operation": "asoud_core.permissions.treasury_document_permission",
    "ASOUD Sayad Event": "asoud_core.permissions.treasury_document_permission",
    "ASOUD Intercompany Transfer": "asoud_core.permissions.intercompany_transfer_permission",
    "ASOUD Consolidation Account Map": "asoud_core.permissions.holding_document_permission",
    "ASOUD Consolidation Adjustment": "asoud_core.permissions.holding_document_permission",
    "ASOUD FX Policy": "asoud_core.permissions.holding_document_permission",
    "ASOUD FX Rate": "asoud_core.permissions.holding_document_permission",
    "ASOUD Migration Run": "asoud_core.permissions.company_control_document_permission",
    "ASOUD Cutover Run": "asoud_core.permissions.company_control_document_permission",
    "ASOUD Audit Event": "asoud_core.permissions.audit_event_permission",
    "ASOUD Approval Policy": "asoud_core.permissions.approval_document_permission",
    "ASOUD Approval Request": "asoud_core.permissions.approval_document_permission",
    "ASOUD Approval Action": "asoud_core.permissions.approval_action_permission",
    "ASOUD Approval Delegation": "asoud_core.permissions.approval_delegation_permission",
    "ASOUD User Access Schedule": "asoud_core.permissions.access_schedule_permission",
    "ASOUD Fiscal Period": "asoud_core.permissions.company_profile_permission",
    "ASOUD Period Lock": "asoud_core.permissions.company_profile_permission",
    "ASOUD Party Identity": "asoud_core.permissions.company_profile_permission",
    "ASOUD Party Code Series": "asoud_core.permissions.company_profile_permission",
}
