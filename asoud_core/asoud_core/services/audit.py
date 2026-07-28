from __future__ import annotations

import hashlib
import json
from typing import Any


GENESIS_HASH = "0" * 64


def canonical_event_payload(values: dict[str, Any]) -> str:
    return json.dumps(values, ensure_ascii=False, sort_keys=True, separators=(",", ":"), default=str)


def event_hash(previous_hash: str, values: dict[str, Any]) -> str:
    return hashlib.sha256(
        f"{previous_hash}:{canonical_event_payload(values)}".encode("utf-8")
    ).hexdigest()


def append_event(
    action: str,
    *,
    resource_doctype: str | None = None,
    resource_name: str | None = None,
    company: str | None = None,
    branch: str | None = None,
    reason: str = "",
    before: Any = None,
    after: Any = None,
    correlation_id: str | None = None,
) -> str:
    import frappe
    from frappe.utils import now_datetime

    if not action.strip():
        frappe.throw("Audit action is required")
    locked = frappe.db.sql("select get_lock('asoud_audit_chain', 10)")[0][0]
    if not locked:
        frappe.throw("Could not acquire the audit-chain lock")
    try:
        previous = frappe.db.get_value(
            "ASOUD Audit Event",
            {},
            "event_hash",
            order_by="creation desc",
        ) or GENESIS_HASH
        values = {
            "occurred_at": str(now_datetime()),
            "actor": frappe.session.user,
            "company": company,
            "branch": branch,
            "action": action.strip(),
            "resource_doctype": resource_doctype,
            "resource_name": resource_name,
            "reason": reason.strip(),
            "correlation_id": correlation_id or getattr(frappe.local, "request_id", None),
            "before_json": canonical_event_payload(before) if before is not None else None,
            "after_json": canonical_event_payload(after) if after is not None else None,
        }
        digest = event_hash(previous, values)
        doc = frappe.get_doc(
            {
                "doctype": "ASOUD Audit Event",
                **values,
                "previous_hash": previous,
                "event_hash": digest,
            }
        )
        doc.insert(ignore_permissions=True)
        return doc.name
    finally:
        frappe.db.sql("select release_lock('asoud_audit_chain')")


def verify_chain() -> dict[str, Any]:
    import frappe

    previous = GENESIS_HASH
    checked = 0
    for row in frappe.get_all(
        "ASOUD Audit Event",
        fields=[
            "name",
            "occurred_at",
            "actor",
            "company",
            "branch",
            "action",
            "resource_doctype",
            "resource_name",
            "reason",
            "correlation_id",
            "before_json",
            "after_json",
            "previous_hash",
            "event_hash",
        ],
        order_by="creation, name",
        limit_page_length=0,
    ):
        values = {
            key: row.get(key)
            for key in (
                "occurred_at",
                "actor",
                "company",
                "branch",
                "action",
                "resource_doctype",
                "resource_name",
                "reason",
                "correlation_id",
                "before_json",
                "after_json",
            )
        }
        expected = event_hash(previous, values)
        if row.previous_hash != previous or row.event_hash != expected:
            return {"valid": False, "checked": checked, "failed_event": row.name}
        previous = row.event_hash
        checked += 1
    return {"valid": True, "checked": checked, "head": previous}
