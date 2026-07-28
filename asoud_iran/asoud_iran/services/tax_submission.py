from __future__ import annotations

import json
from typing import Any

from asoud_iran.services.tax_gateway import SandboxTaxAdapter, build_tax_invoice, checksum


def _invoice_payload(invoice, invoice_kind: str, reference_tax_uid: str | None) -> dict[str, Any]:
    import frappe
    from frappe.utils import flt

    identity = frappe.db.get_value(
        "Company",
        invoice.company,
        ["asoud_national_id", "asoud_economic_code"],
        as_dict=True,
    )
    buyer_tax_id = frappe.db.get_value("Customer", invoice.customer, "tax_id") or ""
    total_tax = flt(invoice.base_total_taxes_and_charges, 2)
    net_total = flt(invoice.base_net_total, 2)
    items = []
    allocated = 0.0
    for index, row in enumerate(invoice.items):
        net = flt(row.base_net_amount, 2)
        if index == len(invoice.items) - 1:
            tax = round(total_tax - allocated, 2)
        else:
            tax = round(total_tax * net / net_total, 2) if net_total else 0.0
            allocated += tax
        items.append(
            {
                "item_code": row.item_code,
                "description": row.description or row.item_name,
                "quantity": row.qty,
                "unit": row.uom,
                "unit_price": flt(row.base_rate, 2),
                "discount": max(0.0, round(flt(row.qty) * flt(row.base_rate) - net, 2)),
                "tax": tax,
            }
        )
    return build_tax_invoice(
        company_identity={
            "national_id": identity.asoud_national_id if identity else "",
            "economic_code": identity.asoud_economic_code if identity else "",
        },
        invoice={
            "doctype": invoice.doctype,
            "name": invoice.name,
            "posting_date": invoice.posting_date,
            "currency": invoice.company_currency,
            "buyer_name": invoice.customer_name,
            "buyer_national_id": buyer_tax_id,
        },
        items=items,
        invoice_kind=invoice_kind,
        reference_tax_uid=reference_tax_uid,
    )


def queue_sales_invoice(
    invoice_name: str,
    invoice_kind: str = "Original",
    reference_tax_uid: str | None = None,
) -> dict[str, str]:
    import frappe

    invoice = frappe.get_doc("Sales Invoice", invoice_name)
    if invoice.docstatus != 1:
        frappe.throw("Only submitted sales invoices can enter the tax queue")
    if not invoice.has_permission("read"):
        frappe.throw("Not permitted", frappe.PermissionError)
    settings = frappe.db.get_value(
        "ASOUD Tax Settings", invoice.company, ["enabled", "environment"], as_dict=True
    )
    if not settings or not settings.enabled:
        frappe.throw("Tax gateway is not enabled for this company")
    payload = _invoice_payload(invoice, invoice_kind, reference_tax_uid)
    key = f"{invoice.name}:{invoice_kind}:{reference_tax_uid or '-'}:{payload['checksum']}"
    existing = frappe.db.exists("ASOUD Tax Submission", {"idempotency_key": key})
    if existing:
        return {"name": existing, "status": frappe.db.get_value("ASOUD Tax Submission", existing, "status")}
    frappe.flags.asoud_tax_gateway = True
    try:
        doc = frappe.get_doc(
            {
                "doctype": "ASOUD Tax Submission",
                "company": invoice.company,
                "source_doctype": invoice.doctype,
                "source_name": invoice.name,
                "invoice_kind": invoice_kind,
                "reference_tax_uid": reference_tax_uid,
                "idempotency_key": key,
                "payload_checksum": payload["checksum"],
                "payload_json": json.dumps(payload, ensure_ascii=False, sort_keys=True),
                "status": "Queued",
            }
        ).insert(ignore_permissions=True)
        _event(doc, "Draft", "Queued", {})
    finally:
        frappe.flags.asoud_tax_gateway = False
    return {"name": doc.name, "status": doc.status}


def _event(doc, from_status: str, to_status: str, details: dict[str, Any]) -> None:
    import frappe
    from frappe.utils import now_datetime

    frappe.get_doc(
        {
            "doctype": "ASOUD Tax Event",
            "submission": doc.name,
            "company": doc.company,
            "event_at": now_datetime(),
            "from_status": from_status,
            "to_status": to_status,
            "provider_reference": doc.provider_reference,
            "payload_checksum": doc.payload_checksum,
            "response_checksum": doc.response_checksum,
            "details_json": json.dumps(details, ensure_ascii=False, sort_keys=True),
        }
    ).insert(ignore_permissions=True)


def dispatch(submission_name: str) -> dict[str, str]:
    import frappe
    from frappe.utils import now_datetime

    frappe.db.sql("select name from `tabASOUD Tax Submission` where name=%s for update", submission_name)
    doc = frappe.get_doc("ASOUD Tax Submission", submission_name)
    if doc.status in {"Accepted", "Rejected"}:
        return {"name": doc.name, "status": doc.status}
    settings = frappe.get_doc("ASOUD Tax Settings", doc.company)
    if settings.environment != "Sandbox" or settings.provider != "ASOUD Sandbox":
        frappe.throw(
            "No audited production tax adapter is installed; transmission remains fail-closed"
        )
    payload = json.loads(doc.payload_json)
    if checksum({key: value for key, value in payload.items() if key != "checksum"}) != doc.payload_checksum:
        frappe.throw("Tax payload checksum verification failed")
    previous = doc.status
    result = SandboxTaxAdapter().submit(payload, doc.idempotency_key)
    frappe.flags.asoud_tax_gateway = True
    try:
        doc.status = result.state
        doc.provider_reference = result.provider_reference
        doc.attempt_count = (doc.attempt_count or 0) + 1
        doc.last_attempt_at = now_datetime()
        doc.response_checksum = checksum(result.response)
        doc.last_error = ""
        doc.save(ignore_permissions=True)
        _event(doc, previous, result.state, result.response)
    finally:
        frappe.flags.asoud_tax_gateway = False
    return {"name": doc.name, "status": doc.status, "provider_reference": doc.provider_reference}
