from __future__ import annotations

import json
from dataclasses import dataclass
from typing import Any


@dataclass(frozen=True)
class OperationContract:
    label: str
    fields: tuple[str, ...]
    child_table: str | None = None
    child_fields: tuple[str, ...] = ()
    child_required: bool = False


CONTRACTS: dict[str, OperationContract] = {
    "Sales Invoice": OperationContract(
        "صورتحساب فروش",
        ("customer", "posting_date", "due_date", "currency", "update_stock", "remarks"),
        "items",
        ("item_code", "qty", "rate", "warehouse", "cost_center"),
        True,
    ),
    "Purchase Invoice": OperationContract(
        "صورتحساب خرید",
        ("supplier", "posting_date", "due_date", "currency", "update_stock", "remarks"),
        "items",
        ("item_code", "qty", "rate", "warehouse", "cost_center"),
        True,
    ),
    "Payment Entry": OperationContract(
        "دریافت/پرداخت",
        (
            "payment_type",
            "posting_date",
            "party_type",
            "party",
            "paid_from",
            "paid_to",
            "paid_amount",
            "received_amount",
            "reference_no",
            "reference_date",
            "remarks",
        ),
        "references",
        ("reference_doctype", "reference_name", "allocated_amount"),
    ),
    "Stock Entry": OperationContract(
        "عملیات انبار",
        ("stock_entry_type", "posting_date", "from_warehouse", "to_warehouse", "remarks"),
        "items",
        (
            "item_code",
            "qty",
            "s_warehouse",
            "t_warehouse",
            "basic_rate",
            "cost_center",
        ),
        True,
    ),
    "Journal Entry": OperationContract(
        "سند حسابداری",
        ("posting_date", "voucher_type", "cheque_no", "cheque_date", "user_remark"),
        "accounts",
        (
            "account",
            "party_type",
            "party",
            "debit_in_account_currency",
            "credit_in_account_currency",
            "cost_center",
            "project",
        ),
        True,
    ),
    "ASOUD Treasury Transaction": OperationContract(
        "عملیات خزانه",
        (
            "posting_date",
            "transaction_type",
            "source_treasury_account",
            "target_treasury_account",
            "counter_account",
            "amount",
            "reference_no",
            "remarks",
        ),
    ),
    "ASOUD Cheque": OperationContract(
        "چک",
        (
            "cheque_type",
            "cheque_number",
            "bank_name",
            "account_number",
            "amount",
            "due_date",
            "party_type",
            "party",
            "party_account",
            "cheque_account",
            "bank_treasury_account",
            "floating_detail",
            "remarks",
        ),
    ),
    "ASOUD Intercompany Transfer": OperationContract(
        "انتقال بین‌شرکتی",
        (
            "transfer_type",
            "posting_date",
            "source_company",
            "source_branch",
            "destination_company",
            "destination_branch",
            "amount",
            "currency",
            "idempotency_key",
            "reason",
            "source_settlement_account",
            "source_settlement_detail",
            "source_intercompany_account",
            "source_intercompany_detail",
            "destination_settlement_account",
            "destination_settlement_detail",
            "destination_intercompany_account",
            "destination_intercompany_detail",
            "source_voucher_type",
            "source_voucher",
            "destination_voucher_type",
            "destination_voucher",
            "remarks",
        ),
    ),
}

REQUIRED_FIELDS: dict[str, set[str]] = {
    "Sales Invoice": {"customer", "posting_date"},
    "Purchase Invoice": {"supplier", "posting_date"},
    "Payment Entry": {"payment_type", "posting_date"},
    "Stock Entry": {"stock_entry_type", "posting_date"},
    "Journal Entry": {"posting_date"},
}

REQUIRED_CHILD_FIELDS: dict[str, set[str]] = {
    "Sales Invoice": {"item_code", "qty", "rate"},
    "Purchase Invoice": {"item_code", "qty", "rate"},
    "Stock Entry": {"item_code", "qty"},
    "Journal Entry": {"account"},
}


def parse_payload(payload: str | dict[str, Any]) -> dict[str, Any]:
    if isinstance(payload, str):
        try:
            payload = json.loads(payload)
        except (TypeError, ValueError) as exc:
            raise ValueError("Payload must be valid JSON") from exc
    if not isinstance(payload, dict):
        raise ValueError("Payload must be a JSON object")
    return payload


def sanitize_payload(document_type: str, payload: str | dict[str, Any]) -> dict[str, Any]:
    contract = CONTRACTS.get(document_type)
    if not contract:
        raise ValueError("Unsupported operational document type")
    source = parse_payload(payload)
    clean = {field: source[field] for field in contract.fields if field in source}
    if contract.child_table and contract.child_table in source:
        rows = source[contract.child_table]
        if not isinstance(rows, list) or not rows:
            raise ValueError(f"{contract.child_table} must be a non-empty array")
        clean[contract.child_table] = [
            {field: row[field] for field in contract.child_fields if field in row}
            for row in rows
            if isinstance(row, dict)
        ]
        if not clean[contract.child_table]:
            raise ValueError(f"{contract.child_table} must contain an object")
    return clean


def _assert_context(company: str, branch: str | None) -> None:
    import frappe

    from asoud_core.permissions import can_access_context

    if not can_access_context(frappe.session.user, company, branch):
        frappe.throw("Not permitted", frappe.PermissionError)


def _field_spec(meta: Any, fieldname: str) -> dict[str, Any]:
    field = meta.get_field(fieldname) if meta else None
    options = getattr(field, "options", None) if field else None
    return {
        "fieldname": fieldname,
        "label": getattr(field, "label", None) or fieldname,
        "fieldtype": getattr(field, "fieldtype", None) or "Data",
        "options": options or "",
        "required": bool(getattr(field, "reqd", False)),
        "read_only": bool(getattr(field, "read_only", False)),
    }


def _contract_specs(document_type: str, contract: OperationContract) -> tuple[list, list]:
    """Read v15 metadata while retaining a safe fallback for unit tests."""
    try:
        import frappe

        meta = frappe.get_meta(document_type)
        child_meta = None
        if contract.child_table:
            table_field = meta.get_field(contract.child_table)
            if table_field and table_field.options:
                child_meta = frappe.get_meta(table_field.options)
    except (ImportError, AttributeError, RuntimeError):
        meta = None
        child_meta = None
    fields = [_field_spec(meta, field) for field in contract.fields]
    child_fields = [_field_spec(child_meta, field) for field in contract.child_fields]
    required = REQUIRED_FIELDS.get(document_type, set())
    required_children = REQUIRED_CHILD_FIELDS.get(document_type, set())
    for field in fields:
        field["required"] = field["required"] or field["fieldname"] in required
    for field in child_fields:
        field["required"] = field["required"] or field["fieldname"] in required_children
    return fields, child_fields


def contracts() -> list[dict[str, Any]]:
    result = []
    for document_type, contract in CONTRACTS.items():
        field_specs, child_field_specs = _contract_specs(document_type, contract)
        result.append({
            "document_type": document_type,
            "label": contract.label,
            "fields": list(contract.fields),
            "field_specs": field_specs,
            "child_table": contract.child_table,
            "child_fields": list(contract.child_fields),
            "child_field_specs": child_field_specs,
            "child_required": contract.child_required,
        })
    return result


def link_options(
    document_type: str,
    fieldname: str,
    search: str = "",
    child: bool = False,
    limit: int = 20,
) -> list[dict[str, str]]:
    """Return permission-filtered options for one allow-listed Link field."""
    import frappe

    contract = CONTRACTS.get(document_type)
    if not contract:
        frappe.throw("Unsupported operational document type")
    allowed = contract.child_fields if child else contract.fields
    if fieldname not in allowed:
        frappe.throw("Unsupported operational field")
    meta = frappe.get_meta(document_type)
    if child:
        table = meta.get_field(contract.child_table)
        meta = frappe.get_meta(table.options)
    field = meta.get_field(fieldname)
    if not field or field.fieldtype not in ("Link", "Dynamic Link") or not field.options:
        frappe.throw("Field does not provide link options")
    if field.fieldtype == "Dynamic Link":
        frappe.throw("Dynamic Link options depend on another field")
    limit = max(1, min(int(limit), 50))
    filters = {"name": ["like", f"%{search.strip()}%"]} if search.strip() else None
    rows = frappe.get_list(
        field.options,
        filters=filters,
        fields=["name"],
        order_by="modified desc",
        page_length=limit,
    )
    return [{"value": row.name, "label": row.name} for row in rows]


def recent_documents(company: str, branch: str | None = None, limit: int = 50) -> list[dict]:
    import frappe

    _assert_context(company, branch)
    limit = max(1, min(int(limit), 100))
    result: list[dict] = []
    for document_type in CONTRACTS:
        meta = frappe.get_meta(document_type)
        filters: dict[str, Any] = {}
        if meta.has_field("company"):
            filters["company"] = company
        elif document_type == "ASOUD Intercompany Transfer":
            filters["source_company"] = company
        if branch and meta.has_field("asoud_branch"):
            filters["asoud_branch"] = branch
        elif branch and meta.has_field("branch"):
            filters["branch"] = branch
        fields = ["name", "docstatus", "modified"]
        for candidate in (
            "posting_date",
            "transaction_date",
            "status",
            "grand_total",
            "amount",
            "asoud_approval_status",
            "asoud_approval_request",
        ):
            if meta.has_field(candidate):
                fields.append(candidate)
        for row in frappe.get_all(
            document_type,
            filters=filters,
            fields=fields,
            order_by="modified desc",
            limit=min(limit, 20),
        ):
            result.append({"document_type": document_type, **row})
    return sorted(result, key=lambda row: str(row.get("modified") or ""), reverse=True)[:limit]


def create_draft(
    document_type: str,
    company: str,
    branch: str | None,
    payload: str | dict[str, Any],
) -> dict[str, Any]:
    import frappe

    _assert_context(company, branch)
    clean = sanitize_payload(document_type, payload)
    doc = frappe.new_doc(document_type)
    meta = frappe.get_meta(document_type)
    if meta.has_field("company"):
        doc.company = company
    if branch and meta.has_field("asoud_branch"):
        doc.asoud_branch = branch
    elif branch and meta.has_field("branch"):
        doc.branch = branch
    for key, value in clean.items():
        if isinstance(value, list):
            for row in value:
                doc.append(key, row)
        else:
            doc.set(key, value)
    doc.insert()
    from asoud_core.services.audit import append_event

    append_event(
        "operational.draft.created",
        resource_doctype=document_type,
        resource_name=doc.name,
        company=company,
        branch=branch,
        after={"docstatus": doc.docstatus},
    )
    return {
        "document_type": document_type,
        "name": doc.name,
        "docstatus": doc.docstatus,
    }


def transition(document_type: str, name: str, action: str, reason: str = "") -> dict[str, Any]:
    import frappe

    if document_type not in CONTRACTS:
        frappe.throw("Unsupported operational document type")
    if document_type not in {
        "Sales Invoice",
        "Purchase Invoice",
        "Payment Entry",
        "Stock Entry",
        "Journal Entry",
        "ASOUD Treasury Transaction",
    }:
        frappe.throw("This document must use its dedicated workflow")
    if action not in ("submit", "cancel"):
        frappe.throw("Unsupported action")
    doc = frappe.get_doc(document_type, name)
    company = doc.get("company") or doc.get("source_company")
    branch = doc.get("asoud_branch") or doc.get("branch") or doc.get("source_branch")
    _assert_context(company, branch)
    if not doc.has_permission(action):
        frappe.throw("Not permitted", frappe.PermissionError)
    if action == "submit":
        if doc.docstatus != 0:
            frappe.throw("Only a draft document can be submitted")
        doc.submit()
    else:
        if doc.docstatus != 1:
            frappe.throw("Only a submitted document can be cancelled")
        if not reason.strip():
            frappe.throw("Cancellation reason is required")
        doc.add_comment("Comment", text=f"Cancellation reason: {reason.strip()}")
        doc.cancel()
    from asoud_core.services.audit import append_event

    append_event(
        f"operational.{action}",
        resource_doctype=document_type,
        resource_name=doc.name,
        company=company,
        branch=branch,
        reason=reason,
        after={"docstatus": doc.docstatus},
    )
    return {
        "document_type": document_type,
        "name": doc.name,
        "docstatus": doc.docstatus,
    }
