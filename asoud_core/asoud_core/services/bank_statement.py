from __future__ import annotations

from typing import Any

from asoud_core.services.banking import (
    parse_statement_csv,
    scoped_fingerprint,
    statement_checksum,
)


def import_csv(connection_name: str, file_name: str, content: bytes) -> dict[str, Any]:
    import frappe
    from frappe.utils import now_datetime

    connection = frappe.get_doc("ASOUD Bank Connection", connection_name)
    if not connection.enabled:
        frappe.throw("Bank connection is disabled")
    from asoud_core.permissions import can_access_context

    if not can_access_context(frappe.session.user, connection.company, connection.branch):
        frappe.throw("Not permitted", frappe.PermissionError)
    digest = statement_checksum(content)
    import_key = scoped_fingerprint(connection.name, digest)
    existing = frappe.db.exists("ASOUD Bank Statement Import", {"import_key": import_key})
    if existing:
        return {
            "name": existing,
            "row_count": frappe.db.get_value("ASOUD Bank Statement Import", existing, "row_count"),
            "duplicate": True,
        }
    try:
        rows = parse_statement_csv(content)
    except (UnicodeDecodeError, ValueError) as exc:
        frappe.throw(str(exc))
    frappe.flags.asoud_bank_import = True
    try:
        run = frappe.get_doc(
            {
                "doctype": "ASOUD Bank Statement Import",
                "company": connection.company,
                "branch": connection.branch,
                "bank_connection": connection.name,
                "file_name": file_name,
                "import_key": import_key,
                "file_checksum": digest,
                "imported_at": now_datetime(),
                "imported_by": frappe.session.user,
                "row_count": len(rows),
                "status": "Imported",
            }
        ).insert(ignore_permissions=True)
        for row in rows:
            row = {
                **row,
                "fingerprint": scoped_fingerprint(connection.name, row["fingerprint"]),
            }
            frappe.get_doc(
                {
                    "doctype": "ASOUD Bank Statement Line",
                    "statement_import": run.name,
                    "company": connection.company,
                    "branch": connection.branch,
                    **row,
                }
            ).insert(ignore_permissions=True)
    finally:
        frappe.flags.asoud_bank_import = False
    return {"name": run.name, "row_count": len(rows), "duplicate": False}


def match_line(
    line_name: str, voucher_type: str, voucher_name: str, score: int = 100
) -> dict[str, str]:
    import frappe
    from frappe.utils import now_datetime

    frappe.db.sql(
        "select name from `tabASOUD Bank Statement Line` where name=%s for update", line_name
    )
    line = frappe.get_doc("ASOUD Bank Statement Line", line_name)
    if not frappe.has_permission(voucher_type, "read", voucher_name):
        frappe.throw("Not permitted", frappe.PermissionError)
    company = frappe.db.get_value(voucher_type, voucher_name, "company")
    if company != line.company:
        frappe.throw("Bank line and voucher must belong to the same company")
    frappe.flags.asoud_bank_reconcile = True
    try:
        line.match_status = "Matched"
        line.matched_voucher_type = voucher_type
        line.matched_voucher = voucher_name
        line.match_score = max(0, min(100, int(score)))
        line.matched_by = frappe.session.user
        line.matched_at = now_datetime()
        line.save(ignore_permissions=True)
    finally:
        frappe.flags.asoud_bank_reconcile = False
    return {"name": line.name, "status": line.match_status}
