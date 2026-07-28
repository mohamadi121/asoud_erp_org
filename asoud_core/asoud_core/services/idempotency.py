from __future__ import annotations

import hashlib
import json
import re
from collections.abc import Callable
from typing import Any


KEY_PATTERN = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._:-]{15,127}$")


def validate_request_key(value: str) -> str:
    value = (value or "").strip()
    if not KEY_PATTERN.fullmatch(value):
        raise ValueError(
            "Idempotency key must contain 16-128 safe ASCII characters"
        )
    return value


def request_digest(payload: Any) -> str:
    canonical = json.dumps(
        payload,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
        default=str,
    )
    return hashlib.sha256(canonical.encode()).hexdigest()


def execute_once(
    request_key: str,
    operation: str,
    payload: Any,
    callback: Callable[[], dict[str, Any]],
) -> dict[str, Any]:
    import frappe

    request_key = validate_request_key(request_key)
    actor = frappe.session.user
    ledger_key = hashlib.sha256(
        f"{actor}:{operation}:{request_key}".encode()
    ).hexdigest()
    digest = request_digest(payload)
    lock_name = f"asoud_idem_{ledger_key[:32]}"
    locked = frappe.db.sql("select get_lock(%s, 10)", lock_name)[0][0]
    if not locked:
        frappe.throw("Could not acquire idempotency lock")
    try:
        existing = frappe.db.get_value(
            "ASOUD Idempotency Record",
            ledger_key,
            ["request_hash", "response_json"],
            as_dict=True,
        )
        if existing:
            if existing.request_hash != digest:
                frappe.throw("Idempotency key was already used with another payload")
            return json.loads(existing.response_json)
        response = callback()
        frappe.get_doc(
            {
                "doctype": "ASOUD Idempotency Record",
                "ledger_key": ledger_key,
                "request_key": request_key,
                "actor": actor,
                "operation": operation,
                "request_hash": digest,
                "response_json": json.dumps(
                    response,
                    ensure_ascii=False,
                    sort_keys=True,
                    separators=(",", ":"),
                    default=str,
                ),
            }
        ).insert(ignore_permissions=True)
        return response
    finally:
        frappe.db.sql("select release_lock(%s)", lock_name)
