from __future__ import annotations

import hashlib
import json

from asoud_core.services.banking import transition_sayad


def sandbox_transition(operation_name: str, target_state: str) -> dict[str, str]:
    import frappe
    from frappe.utils import now_datetime

    frappe.db.sql(
        "select name from `tabASOUD Sayad Operation` where name=%s for update",
        operation_name,
    )
    operation = frappe.get_doc("ASOUD Sayad Operation", operation_name)
    connection = frappe.db.get_value(
        "ASOUD Bank Connection",
        {
            "treasury_account": frappe.db.get_value(
                "ASOUD Cheque", operation.cheque, "bank_treasury_account"
            ),
            "enabled": 1,
        },
        ["environment", "name"],
        as_dict=True,
    )
    if not connection or connection.environment != "Sandbox":
        frappe.throw(
            "No contracted production Sayad adapter is installed; operation remains fail-closed"
        )
    try:
        next_state = transition_sayad(operation.state, target_state)
    except ValueError as exc:
        frappe.throw(str(exc))
    request = {
        "operation": operation.operation_type,
        "sayad_id": operation.sayad_id,
        "target_state": next_state,
        "idempotency_key": operation.idempotency_key,
    }
    request_checksum = hashlib.sha256(
        json.dumps(request, sort_keys=True, separators=(",", ":")).encode()
    ).hexdigest()
    reference = f"SBX-SAYAD-{request_checksum[:20].upper()}"
    response = {"sandbox": True, "state": next_state, "reference": reference}
    response_checksum = hashlib.sha256(
        json.dumps(response, sort_keys=True, separators=(",", ":")).encode()
    ).hexdigest()
    previous = operation.state
    frappe.flags.asoud_sayad_gateway = True
    try:
        operation.state = next_state
        operation.provider_reference = reference
        operation.request_checksum = request_checksum
        operation.response_checksum = response_checksum
        operation.last_error = ""
        operation.save(ignore_permissions=True)
        frappe.get_doc(
            {
                "doctype": "ASOUD Sayad Event",
                "operation": operation.name,
                "company": operation.company,
                "event_at": now_datetime(),
                "from_state": previous,
                "to_state": next_state,
                "provider_reference": reference,
                "request_checksum": request_checksum,
                "response_checksum": response_checksum,
                "details_json": json.dumps(response, sort_keys=True),
            }
        ).insert(ignore_permissions=True)
    finally:
        frappe.flags.asoud_sayad_gateway = False
    return {"name": operation.name, "state": next_state, "provider_reference": reference}
