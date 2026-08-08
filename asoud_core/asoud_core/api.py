from __future__ import annotations

import json


def _whitelist(*args, **kwargs):
    import frappe

    return frappe.whitelist(*args, **kwargs)


@_whitelist()
def accessible_contexts() -> list[dict]:
    import frappe

    from asoud_core.organization import (
        AccessGrant,
        OrganizationContext,
        resolve_accessible_contexts,
    )
    from asoud_core.permissions import _is_privileged

    user = frappe.session.user
    companies = frappe.get_all(
        "Company",
        filters={"is_group": 0},
        fields=["name", "asoud_holding"],
    )
    branches = frappe.get_all(
        "ASOUD Branch",
        filters={"enabled": 1},
        fields=["name", "branch_name", "company", "holding"],
    )
    holding_by_company = {row.name: row.asoud_holding for row in companies}
    contexts = [
        OrganizationContext(company=row.name, holding=row.asoud_holding)
        for row in companies
    ]
    contexts.extend(
        OrganizationContext(
            company=row.company,
            branch=row.name,
            holding=row.holding or holding_by_company.get(row.company),
            branch_name=row.branch_name,
        )
        for row in branches
    )
    grant_rows = frappe.get_all(
        "ASOUD User Access",
        filters={"user": user, "enabled": 1},
        fields=["company", "branch", "holding_manager", "enabled"],
    )
    grants = [
        AccessGrant(
            company=row.company,
            branch=row.branch,
            holding=holding_by_company.get(row.company),
            holding_manager=bool(row.holding_manager),
            enabled=bool(row.enabled),
        )
        for row in grant_rows
    ]
    return [
        {
            "company": row.company,
            "branch": row.branch,
            "branch_name": row.branch_name,
            "holding": row.holding,
        }
        for row in resolve_accessible_contexts(
            grants,
            contexts,
            privileged=_is_privileged(user),
        )
    ]


@_whitelist()
def active_context() -> dict | None:
    import frappe

    return frappe.db.get_value(
        "ASOUD User Context",
        {"user": frappe.session.user},
        ["company", "branch"],
        as_dict=True,
    )


@_whitelist(methods=["GET"])
def session_security_context() -> dict:
    import frappe
    from frappe.sessions import get_csrf_token

    if frappe.session.user == "Guest":
        frappe.throw("Authentication required", frappe.AuthenticationError)
    return {
        "user": frappe.session.user,
        "csrf_token": get_csrf_token(),
    }


@_whitelist(methods=["POST"])
def set_active_context(company: str, branch: str | None = None) -> dict:
    import frappe

    from asoud_core.permissions import can_access_context

    user = frappe.session.user
    branch = branch or None
    if branch:
        branch_row = frappe.db.get_value(
            "ASOUD Branch",
            branch,
            ["company", "enabled"],
            as_dict=True,
        )
        if not branch_row or not branch_row.enabled or branch_row.company != company:
            frappe.throw("The selected branch is not an enabled branch of the selected company")
    if not can_access_context(user, company, branch):
        frappe.throw("You do not have access to the selected company and branch")

    name = frappe.db.exists("ASOUD User Context", {"user": user})
    values = {"company": company, "branch": branch}
    if name:
        frappe.db.set_value("ASOUD User Context", name, values)
    else:
        frappe.get_doc(
            {"doctype": "ASOUD User Context", "user": user, **values}
        ).insert(ignore_permissions=True)
    from asoud_core.services.audit import append_event

    append_event(
        "context.activated",
        company=company,
        branch=branch,
        after={"company": company, "branch": branch},
    )
    return {"company": company, "branch": branch}


@_whitelist(methods=["GET"])
def verify_audit_chain() -> dict:
    import frappe

    frappe.only_for(("System Manager", "Accounts Manager"))
    from asoud_core.services.audit import verify_chain

    return verify_chain()


@_whitelist(methods=["POST"])
def final_number(company: str, fiscal_year: str, from_date: str, to_date: str, reason: str) -> str:
    import frappe

    frappe.only_for(("Accounts Manager", "System Manager"))
    from asoud_core.services.journal_numbering import run_final_numbering

    return run_final_numbering(
        company=company,
        fiscal_year=fiscal_year,
        from_date=from_date,
        to_date=to_date,
        reason=reason,
    )


@_whitelist(methods=["POST"])
def lock_period(
    company: str,
    fiscal_year: str,
    from_date: str,
    to_date: str,
    reason: str = "Manual period lock",
    fiscal_period: str | None = None,
) -> str:
    import frappe

    frappe.only_for(("Accounts Manager", "System Manager"))
    from asoud_core.services.journal_numbering import lock_period as create_lock

    return create_lock(
        company=company,
        fiscal_year=fiscal_year,
        from_date=from_date,
        to_date=to_date,
        reason=reason,
        fiscal_period=fiscal_period,
    )


@_whitelist(methods=["POST"])
def unlock_period(lock_name: str, reason: str) -> str:
    import frappe

    frappe.only_for(("Accounts Manager", "System Manager"))
    from asoud_core.services.journal_numbering import unlock_period as reopen

    return reopen(lock_name=lock_name, reason=reason)


@_whitelist(methods=["GET"])
def numbering_overview(company: str) -> dict:
    import frappe

    if not frappe.get_doc("Company", company).has_permission("read"):
        frappe.throw("Not permitted", frappe.PermissionError)
    counts = {
        status: frappe.db.count(
            "ASOUD Accounting Document",
            {"company": company, "numbering_status": status},
        )
        for status in ("Temporary", "Final", "Locked", "Cancelled")
    }
    latest = frappe.get_all(
        "ASOUD Numbering Batch",
        filters={"company": company, "docstatus": 1},
        fields=["name", "fiscal_year", "from_date", "to_date", "document_count", "unit_count"],
        order_by="creation desc",
        limit=1,
    )
    return {"company": company, "counts": counts, "latest_batch": latest[0] if latest else None}


@_whitelist(methods=["GET"])
def document_consolidation_workspace(
    company: str,
    posting_date: str | None = None,
) -> dict:
    from asoud_core.services.document_consolidation import workspace

    return workspace(company, posting_date or None)


@_whitelist(methods=["POST"])
def consolidate_accounting_documents(
    company: str,
    posting_date: str,
    documents: str,
    reason: str,
    idempotency_key: str,
) -> dict:
    from asoud_core.services.document_consolidation import create
    from asoud_core.services.idempotency import execute_once

    request = {
        "company": company,
        "posting_date": posting_date,
        "documents": documents,
        "reason": reason,
    }
    return execute_once(
        idempotency_key,
        "accounting.documents.consolidate",
        request,
        lambda: create(company, posting_date, documents, reason),
    )


@_whitelist(methods=["GET"])
def operational_dashboard(
    company: str,
    branch: str | None = None,
    from_date: str | None = None,
    to_date: str | None = None,
) -> dict:
    """Return a compact, permission-scoped sales/purchase/stock snapshot."""
    import frappe
    from frappe.utils import get_first_day, get_last_day, nowdate

    from asoud_core.permissions import can_access_context

    branch = branch or None
    if not can_access_context(frappe.session.user, company, branch):
        frappe.throw("Not permitted", frappe.PermissionError)
    from_date = from_date or str(get_first_day(nowdate()))
    to_date = to_date or str(get_last_day(nowdate()))
    branch_clause = " and asoud_branch=%s" if branch else ""
    parameters = [company, from_date, to_date]
    if branch:
        parameters.append(branch)

    def total(doctype: str, field: str = "base_grand_total") -> float:
        value = frappe.db.sql(
            f"""
            select coalesce(sum({field}), 0)
              from `tab{doctype}`
             where docstatus=1 and company=%s and posting_date between %s and %s
                   {branch_clause}
            """,
            tuple(parameters),
        )[0][0]
        return float(value or 0)

    warehouse_filter = " and w.asoud_branch=%s" if branch else ""
    stock_parameters = [company]
    if branch:
        stock_parameters.append(branch)
    stock = frappe.db.sql(
        f"""
        select coalesce(sum(b.actual_qty), 0) actual_qty,
               coalesce(sum(b.stock_value), 0) stock_value
          from `tabBin` b
          join `tabWarehouse` w on w.name=b.warehouse
         where w.company=%s and w.is_group=0 {warehouse_filter}
        """,
        tuple(stock_parameters),
        as_dict=True,
    )[0]
    return {
        "company": company,
        "branch": branch,
        "from_date": from_date,
        "to_date": to_date,
        "sales": total("Sales Invoice"),
        "purchases": total("Purchase Invoice"),
        "receipts": total("Payment Entry", "base_received_amount"),
        "payments": total("Payment Entry", "base_paid_amount"),
        "stock_qty": float(stock.actual_qty or 0),
        "stock_value": float(stock.stock_value or 0),
    }


@_whitelist(methods=["GET"])
def dashboard_workspace(
    company: str,
    branch: str | None = None,
) -> dict:
    """Return the permission-scoped aggregate required by the Web PWA dashboard."""
    from asoud_core.services.dashboard import workspace_snapshot

    return workspace_snapshot(company, branch or None)


@_whitelist(methods=["GET"])
def operational_catalog(company: str, branch: str | None = None) -> dict:
    """Return enabled shared masters configured for the selected company."""
    import frappe

    from asoud_core.permissions import can_access_context

    branch = branch or None
    if not can_access_context(frappe.session.user, company, branch):
        frappe.throw("Not permitted", frappe.PermissionError)
    party_filters = {"company": company, "enabled": 1}
    item_filters = {"company": company, "enabled": 1}
    if branch:
        party_filters["default_branch"] = ["in", ("", branch)]
        item_filters["default_branch"] = ["in", ("", branch)]
    return {
        "customers": frappe.get_all(
            "ASOUD Party Company Profile",
            filters={**party_filters, "party_type": "Customer"},
            fields=["party", "credit_limit", "payment_terms_template", "price_list"],
            order_by="party",
        ),
        "suppliers": frappe.get_all(
            "ASOUD Party Company Profile",
            filters={**party_filters, "party_type": "Supplier"},
            fields=["party", "payment_terms_template", "price_list"],
            order_by="party",
        ),
        "items": frappe.get_all(
            "ASOUD Item Company Profile",
            filters=item_filters,
            fields=["item", "default_warehouse", "income_account", "expense_account"],
            order_by="item",
        ),
    }


@_whitelist(methods=["GET"])
def party_management_snapshot(
    company: str,
    branch: str | None = None,
    search: str | None = None,
) -> dict:
    from asoud_core.services.party_management import party_snapshot

    return party_snapshot(company, branch or None, search)


@_whitelist(methods=["GET"])
def party_code_preview(company: str, roles: str) -> dict:
    from asoud_core.services.party_management import preview_codes

    return preview_codes(company, roles)


@_whitelist(methods=["GET"])
def party_management_detail(name: str, company: str) -> dict:
    from asoud_core.services.party_management import party_detail

    return party_detail(name, company)


@_whitelist(methods=["POST"])
def save_party_identity(
    company: str,
    payload: str,
    idempotency_key: str,
    branch: str | None = None,
) -> dict:
    from asoud_core.services.idempotency import execute_once
    from asoud_core.services.party_management import normalize_party_payload, save_party

    values = normalize_party_payload(payload)
    request = {"company": company, "branch": branch or None, "payload": values}
    return execute_once(
        idempotency_key,
        "party.identity.save",
        request,
        lambda: save_party(company, values, branch or None),
    )


@_whitelist(methods=["GET"])
def item_management_snapshot(
    company: str,
    branch: str | None = None,
    search: str | None = None,
) -> dict:
    from asoud_core.services.item_management import item_snapshot

    return item_snapshot(company, branch or None, search)


@_whitelist(methods=["GET"])
def item_management_detail(item_code: str, company: str) -> dict:
    from asoud_core.services.item_management import item_detail

    return item_detail(item_code, company)


@_whitelist(methods=["POST"])
def save_item_master(
    company: str,
    payload: str,
    idempotency_key: str,
    branch: str | None = None,
) -> dict:
    from asoud_core.services.idempotency import execute_once
    from asoud_core.services.item_management import normalize_item_payload, save_item

    values = normalize_item_payload(payload)
    request = {"company": company, "branch": branch or None, "payload": values}
    return execute_once(
        idempotency_key,
        "item.master.save",
        request,
        lambda: save_item(company, values, branch or None),
    )


@_whitelist(methods=["GET"])
def inventory_management_workspace(
    company: str,
    branch: str | None = None,
) -> dict:
    from asoud_core.services.inventory_management import workspace

    return workspace(company, branch or None)


@_whitelist(methods=["POST"])
def save_inventory_setting(
    company: str,
    setting_type: str,
    payload: str,
    idempotency_key: str,
    branch: str | None = None,
) -> dict:
    from asoud_core.services.idempotency import execute_once
    from asoud_core.services.inventory_management import save_setting

    values = json.loads(payload)
    request = {
        "company": company,
        "branch": branch or None,
        "setting_type": setting_type,
        "payload": values,
    }
    return execute_once(
        idempotency_key,
        "inventory.setting.save",
        request,
        lambda: save_setting(company, setting_type, values, branch or None),
    )


@_whitelist(methods=["GET"])
def operational_workbench(
    company: str,
    branch: str | None = None,
    limit: int = 50,
) -> dict:
    from asoud_core.services.operational_workbench import contracts, recent_documents

    branch = branch or None
    return {
        "company": company,
        "branch": branch,
        "contracts": contracts(),
        "documents": recent_documents(company, branch, limit),
    }


@_whitelist(methods=["GET"])
def operational_link_options(
    document_type: str,
    fieldname: str,
    search: str = "",
    child: int | str = 0,
    limit: int = 20,
) -> list[dict]:
    """Return only permission-visible values for an allow-listed Link field."""
    from asoud_core.services.operational_workbench import link_options

    return link_options(
        document_type,
        fieldname,
        search,
        str(child).lower() in ("1", "true"),
        limit,
    )


@_whitelist(methods=["POST"])
def mark_dashboard_notification_read(name: str) -> dict:
    """Mark only the current user's notification as read."""
    import frappe

    notification = frappe.get_doc("Notification Log", name)
    if notification.for_user != frappe.session.user:
        frappe.throw("Not permitted", frappe.PermissionError)
    if not notification.read:
        notification.db_set("read", 1, update_modified=False)
    return {"name": name, "read": 1}


@_whitelist(methods=["POST"])
def create_operational_draft(
    document_type: str,
    company: str,
    payload: str,
    idempotency_key: str,
    branch: str | None = None,
) -> dict:
    from asoud_core.services.idempotency import execute_once
    from asoud_core.services.operational_workbench import create_draft

    return execute_once(
        idempotency_key,
        "operational.create_draft",
        {
            "document_type": document_type,
            "company": company,
            "branch": branch or None,
            "payload": payload,
        },
        lambda: create_draft(document_type, company, branch or None, payload),
    )


@_whitelist(methods=["POST"])
def transition_operational_document(
    document_type: str,
    name: str,
    action: str,
    idempotency_key: str,
    reason: str = "",
) -> dict:
    from asoud_core.services.idempotency import execute_once
    from asoud_core.services.operational_workbench import transition

    return execute_once(
        idempotency_key,
        "operational.transition",
        {
            "document_type": document_type,
            "name": name,
            "action": action,
            "reason": reason,
        },
        lambda: transition(document_type, name, action, reason),
    )


@_whitelist(methods=["POST"])
def transition_cheque(
    cheque: str,
    target_status: str,
    event_date: str,
    reason: str,
) -> str:
    from asoud_core.services.treasury import transition_cheque as transition

    return transition(cheque, target_status, event_date, reason)


@_whitelist(methods=["GET"])
def treasury_dashboard(
    company: str,
    branch: str | None = None,
    as_of_date: str | None = None,
) -> dict:
    import frappe
    from frappe.utils import nowdate

    from asoud_core.permissions import can_access_context
    from asoud_core.services.treasury import ledger_balance

    branch = branch or None
    if not can_access_context(frappe.session.user, company, branch):
        frappe.throw("Not permitted", frappe.PermissionError)
    as_of_date = as_of_date or nowdate()
    filters: dict = {"company": company, "enabled": 1}
    if branch:
        filters["branch"] = branch
    accounts = frappe.get_all(
        "ASOUD Treasury Account",
        filters=filters,
        fields=["name", "account_title", "treasury_type", "branch", "ledger_account"],
        order_by="treasury_type, account_title",
    )
    balances = []
    totals = {"Bank": 0.0, "Cash": 0.0, "Petty Cash": 0.0}
    for account in accounts:
        balance = ledger_balance(account.ledger_account, company, as_of_date)
        totals[account.treasury_type] += balance
        balances.append({**account, "balance": balance})
    cheque_filters: dict = {"company": company}
    if branch:
        cheque_filters["branch"] = branch
    cheque_rows = frappe.get_all(
        "ASOUD Cheque",
        filters=cheque_filters,
        fields=["cheque_type", "current_status", "amount"],
    )
    cheque_summary: dict[str, float] = {}
    for row in cheque_rows:
        key = f"{row.cheque_type}:{row.current_status}"
        cheque_summary[key] = cheque_summary.get(key, 0.0) + float(row.amount or 0)
    unsettled_claims = frappe.db.count(
        "ASOUD Petty Cash Claim", {**cheque_filters, "docstatus": 0}
    )
    return {
        "company": company,
        "branch": branch,
        "as_of_date": as_of_date,
        "totals": totals,
        "accounts": balances,
        "cheques": cheque_summary,
        "unsettled_petty_cash_claims": unsettled_claims,
    }


@_whitelist(methods=["POST"])
def approve_intercompany_source(
    transfer: str,
    idempotency_key: str | None = None,
) -> dict:
    import frappe

    frappe.only_for(("Accounts Manager", "System Manager"))
    from asoud_core.services.intercompany import approve_source

    if not idempotency_key:
        return approve_source(transfer)
    from asoud_core.services.idempotency import execute_once

    return execute_once(
        idempotency_key,
        "intercompany.approve_source",
        {"transfer": transfer},
        lambda: approve_source(transfer),
    )


@_whitelist(methods=["POST"])
def accept_intercompany_destination(
    transfer: str,
    idempotency_key: str | None = None,
) -> dict:
    import frappe

    frappe.only_for(("Accounts Manager", "System Manager"))
    from asoud_core.services.intercompany import accept_destination

    if not idempotency_key:
        return accept_destination(transfer)
    from asoud_core.services.idempotency import execute_once

    return execute_once(
        idempotency_key,
        "intercompany.accept_destination",
        {"transfer": transfer},
        lambda: accept_destination(transfer),
    )


@_whitelist(methods=["POST"])
def compensate_intercompany_transfer(
    transfer: str,
    posting_date: str,
    reason: str,
) -> str:
    import frappe

    frappe.only_for(("Accounts Manager", "System Manager"))
    from asoud_core.services.intercompany import reverse_transfer

    return reverse_transfer(transfer, posting_date, reason)


@_whitelist(methods=["GET"])
def holding_consolidation_report(
    holding: str,
    from_date: str,
    to_date: str,
) -> dict:
    from asoud_core.services.intercompany import consolidation_report

    return consolidation_report(holding, from_date, to_date)


@_whitelist(methods=["POST"])
def import_bank_statement(
    connection: str,
    file_name: str,
    content_base64: str,
) -> dict:
    import base64
    import binascii
    import frappe

    frappe.only_for(("Accounts Manager", "System Manager"))
    try:
        content = base64.b64decode(content_base64, validate=True)
    except (binascii.Error, ValueError):
        frappe.throw("Bank statement content must be valid Base64")
    if len(content) > 5 * 1024 * 1024:
        frappe.throw("Bank statement exceeds the 5 MiB import limit")
    from asoud_core.services.bank_statement import import_csv

    return import_csv(connection, file_name, content)


@_whitelist(methods=["POST"])
def match_bank_statement_line(
    line: str,
    voucher_type: str,
    voucher_name: str,
    score: int = 100,
) -> dict:
    import frappe

    frappe.only_for(("Accounts Manager", "System Manager"))
    from asoud_core.services.bank_statement import match_line

    return match_line(line, voucher_type, voucher_name, score)


@_whitelist(methods=["POST"])
def transition_sayad_operation(operation: str, target_state: str) -> dict:
    import frappe

    frappe.only_for(("Accounts Manager", "System Manager"))
    from asoud_core.services.sayad import sandbox_transition

    return sandbox_transition(operation, target_state)


@_whitelist(methods=["GET"])
def compliance_connectivity_dashboard(company: str) -> dict:
    import frappe

    from asoud_core.permissions import can_access_company

    if not can_access_company(frappe.session.user, company):
        frappe.throw("Not permitted", frappe.PermissionError)
    holding = frappe.db.get_value("Company", company, "asoud_holding")
    tax = frappe.db.get_value(
        "ASOUD Tax Settings",
        company,
        ["enabled", "environment", "provider"],
        as_dict=True,
    )
    bank_connections = frappe.get_all(
        "ASOUD Bank Connection",
        filters={"company": company, "enabled": 1},
        fields=["environment", "count(name) as count"],
        group_by="environment",
    )
    return {
        "company": company,
        "holding": holding,
        "tax": {
            "configured": bool(tax and tax.enabled),
            "environment": tax.environment if tax else None,
            "provider": tax.provider if tax else None,
            "queued": frappe.db.count(
                "ASOUD Tax Submission", {"company": company, "status": ["in", ["Queued", "Retry"]]}
            ),
            "accepted": frappe.db.count(
                "ASOUD Tax Submission", {"company": company, "status": "Accepted"}
            ),
        },
        "bank": {
            "connections": {row.environment: row.count for row in bank_connections},
            "unmatched_lines": frappe.db.count(
                "ASOUD Bank Statement Line", {"company": company, "match_status": "Unmatched"}
            ),
        },
        "sayad": {
            "open_operations": frappe.db.count(
                "ASOUD Sayad Operation",
                {
                    "company": company,
                    "state": ["not in", ["Settled", "Returned", "Rejected", "Cancelled"]],
                },
            )
        },
        "consolidation": {
            "fx_policy": bool(
                holding and frappe.db.exists("ASOUD FX Policy", {"holding": holding, "enabled": 1})
            ),
            "approved_rates": (
                frappe.db.count("ASOUD FX Rate", {"holding": holding, "docstatus": 1})
                if holding
                else 0
            ),
        },
        "production_claimed": False,
    }


@_whitelist(methods=["GET"])
def approval_inbox(
    company: str,
    branch: str | None = None,
    view: str = "incoming",
    limit: int = 50,
    search: str = "",
    status: str = "",
) -> dict:
    from asoud_core.services.approval import inbox

    return inbox(company, branch or None, view, limit, search, status)


@_whitelist(methods=["GET"])
def approval_request_detail(request: str) -> dict:
    from asoud_core.services.approval import request_detail

    return request_detail(request)


@_whitelist(methods=["POST"])
def start_approval_request(
    source_doctype: str,
    source_name: str,
    idempotency_key: str,
) -> dict:
    from asoud_core.services.approval import start_request
    from asoud_core.services.idempotency import execute_once

    return execute_once(
        idempotency_key,
        "approval.start",
        {"source_doctype": source_doctype, "source_name": source_name},
        lambda: start_request(source_doctype, source_name),
    )


@_whitelist(methods=["POST"])
def act_on_approval(
    request: str,
    action: str,
    comment: str,
    expected_version: str,
    idempotency_key: str,
) -> dict:
    from asoud_core.services.approval import perform_action
    from asoud_core.services.idempotency import execute_once

    return execute_once(
        idempotency_key,
        "approval.action",
        {
            "request": request,
            "action": action,
            "comment": comment,
            "expected_version": expected_version,
        },
        lambda: perform_action(request, action, comment, expected_version),
    )


@_whitelist(methods=["GET"])
def approval_policy_catalog(
    company: str,
    branch: str | None = None,
) -> list[dict]:
    from asoud_core.services.approval import policy_catalog

    return policy_catalog(company, branch or None)


@_whitelist(methods=["GET"])
def approval_settings_workspace(
    company: str,
    branch: str | None = None,
) -> dict:
    from asoud_core.services.approval_settings import workspace

    return workspace(company, branch or None)


@_whitelist(methods=["POST"])
def save_approval_policy(
    company: str,
    payload: str,
    idempotency_key: str,
) -> dict:
    from asoud_core.services.approval_settings import save
    from asoud_core.services.idempotency import execute_once

    values = json.loads(payload)
    return execute_once(
        idempotency_key,
        "approval.policy.save",
        {"company": company, "payload": values},
        lambda: save(company, values),
    )


@_whitelist(methods=["GET"])
def access_overview(
    company: str,
    branch: str | None = None,
) -> dict:
    from asoud_core.services.access_control import overview

    return overview(company, branch or None)


@_whitelist(methods=["GET"])
def organization_settings_snapshot(company: str | None = None) -> dict:
    from asoud_core.services.organization_settings import snapshot

    return snapshot(company or None)


@_whitelist(methods=["POST"])
def save_organization_unit(
    payload: str,
    idempotency_key: str,
) -> dict:
    from asoud_core.services.idempotency import execute_once
    from asoud_core.services.organization_settings import save

    parsed = __import__("json").loads(payload)
    return execute_once(
        idempotency_key,
        "organization.save_unit",
        parsed,
        lambda: save(parsed),
    )


@_whitelist(methods=["POST"])
def set_user_access(
    user: str,
    company: str,
    idempotency_key: str,
    branch: str | None = None,
    enabled: int = 1,
    holding_manager: int = 0,
) -> dict:
    from asoud_core.services.access_control import set_grant
    from asoud_core.services.idempotency import execute_once

    payload = {
        "user": user,
        "company": company,
        "branch": branch or None,
        "enabled": bool(int(enabled)),
        "holding_manager": bool(int(holding_manager)),
    }
    return execute_once(
        idempotency_key,
        "access.set_grant",
        payload,
        lambda: set_grant(**payload),
    )
