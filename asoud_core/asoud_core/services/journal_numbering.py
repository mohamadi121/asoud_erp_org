from __future__ import annotations

import hashlib
import json
from datetime import date


class FrappeNumberingError(ValueError):
    pass


SUPPORTED_DOCTYPES = (
    "Journal Entry",
    "Sales Invoice",
    "Purchase Invoice",
    "Payment Entry",
    "Stock Entry",
    "Delivery Note",
    "Purchase Receipt",
    "Stock Reconciliation",
)


def _posting_date(doc):
    return doc.get("posting_date") or doc.get("transaction_date")


def _fiscal_year(posting_date: date, company: str) -> str:
    from erpnext.accounts.utils import get_fiscal_year

    result = get_fiscal_year(posting_date, company=company)
    if not result:
        raise FrappeNumberingError(f"No fiscal year covers {posting_date} for {company}")
    return result[0]


def assign_temporary_number(doc, method: str | None = None) -> None:
    """Allocate an immutable number shared by every supported accounting source."""
    import frappe
    from frappe.model.naming import getseries

    if doc.doctype not in SUPPORTED_DOCTYPES:
        return
    if not doc.company or not _posting_date(doc):
        raise FrappeNumberingError("Company and posting date are required for accounting numbering")
    persisted = None
    if not doc.is_new():
        persisted = frappe.db.get_value(doc.doctype, doc.name, "asoud_temporary_number")
    if persisted and doc.asoud_temporary_number != persisted:
        raise FrappeNumberingError("The temporary accounting number is immutable")
    if doc.asoud_temporary_number:
        return

    fiscal_year = _fiscal_year(_posting_date(doc), doc.company)
    company_abbr = frappe.db.get_value("Company", doc.company, "abbr") or doc.company
    sequence = getseries(f"ASOUD-TEMP-{company_abbr}-{fiscal_year}-", 7)
    doc.asoud_temporary_number = f"{company_abbr}-{fiscal_year}-{sequence}"
    doc.asoud_numbering_status = "Temporary"


def register_submitted_document(doc, method: str | None = None) -> None:
    """Create the immutable cross-DocType registry row after a successful submit."""
    import frappe

    if doc.doctype not in SUPPORTED_DOCTYPES or doc.docstatus != 1:
        return
    source_key = f"{doc.doctype}::{doc.name}"
    if frappe.db.exists("ASOUD Accounting Document", {"source_key": source_key}):
        return
    posting_date = _posting_date(doc)
    frappe.get_doc(
        {
            "doctype": "ASOUD Accounting Document",
            "source_doctype": doc.doctype,
            "source_name": doc.name,
            "source_key": source_key,
            "company": doc.company,
            "branch": doc.get("asoud_branch"),
            "fiscal_year": _fiscal_year(posting_date, doc.company),
            "posting_date": posting_date,
            "posting_time": doc.get("posting_time"),
            "temporary_number": doc.asoud_temporary_number,
            "final_number": doc.get("asoud_final_number"),
            "numbering_status": doc.get("asoud_numbering_status") or "Temporary",
            "source_creation": doc.creation,
        }
    ).insert(ignore_permissions=True)


def backfill_submitted_document(doctype: str, name: str) -> str:
    """Register a pre-phase-three submitted document without rewriting its name."""
    import frappe

    if doctype not in SUPPORTED_DOCTYPES:
        raise FrappeNumberingError(f"Unsupported accounting document: {doctype}")
    doc = frappe.get_doc(doctype, name)
    if doc.docstatus != 1:
        raise FrappeNumberingError("Only submitted documents can be backfilled")
    frappe.db.sql("select name from `tabCompany` where name=%s for update", doc.company)
    if not doc.asoud_temporary_number:
        assign_temporary_number(doc)
        frappe.db.set_value(
            doctype,
            name,
            {
                "asoud_temporary_number": doc.asoud_temporary_number,
                "asoud_numbering_status": "Temporary",
            },
            update_modified=False,
        )
    register_submitted_document(doc)
    return frappe.db.get_value(
        "ASOUD Accounting Document", {"source_key": f"{doctype}::{name}"}, "name"
    )


def backfill_legacy_documents() -> int:
    """Migration-safe registry adoption for submitted documents from older releases."""
    import frappe

    count = 0
    for doctype in SUPPORTED_DOCTYPES:
        for name in frappe.get_all(doctype, filters={"docstatus": 1}, pluck="name"):
            if frappe.db.exists(
                "ASOUD Accounting Document",
                {"source_key": f"{doctype}::{name}"},
            ):
                continue
            backfill_submitted_document(doctype, name)
            count += 1
    return count


def assert_numbering_allows_cancel(doc, method: str | None = None) -> None:
    """Final or locked legal documents are corrected only by reversal/amendment."""
    import frappe

    registry = frappe.db.get_value(
        "ASOUD Accounting Document",
        {"source_key": f"{doc.doctype}::{doc.name}"},
        ["numbering_status", "final_number"],
        as_dict=True,
    )
    if registry and (registry.final_number or registry.numbering_status in {"Final", "Locked"}):
        raise FrappeNumberingError(
            "A final-numbered accounting document cannot be cancelled; create a reversal/amendment"
        )


def mark_cancelled(doc, method: str | None = None) -> None:
    import frappe

    registry = frappe.db.get_value(
        "ASOUD Accounting Document",
        {"source_key": f"{doc.doctype}::{doc.name}"},
        "name",
    )
    if registry:
        frappe.db.set_value(
            "ASOUD Accounting Document",
            registry,
            "numbering_status",
            "Cancelled",
            update_modified=False,
        )
    frappe.db.set_value(
        doc.doctype, doc.name, "asoud_numbering_status", "Cancelled", update_modified=False
    )


def _assert_period_open(company: str, from_date: date, to_date: date) -> None:
    import frappe

    if frappe.db.exists(
        "ASOUD Period Lock",
        {
            "company": company,
            "from_date": ["<=", to_date],
            "to_date": [">=", from_date],
            "docstatus": 1,
        },
    ):
        raise FrappeNumberingError("The selected range overlaps a legally locked period")


def _request_hash(company, fiscal_year, start, end, reason) -> str:
    payload = json.dumps(
        [company, fiscal_year, str(start), str(end), reason.strip()],
        ensure_ascii=False,
        separators=(",", ":"),
    )
    return hashlib.sha256(payload.encode()).hexdigest()


def run_final_numbering(
    *,
    company: str,
    fiscal_year: str,
    from_date: str,
    to_date: str,
    reason: str,
) -> str:
    """Renumber the selected date and every later document as one atomic sequence.

    Submitted consolidations form one legal numbering unit. Their source documents
    keep their own immutable temporary numbers and share the aggregate final number.
    """
    import frappe
    from frappe.utils import getdate, now_datetime

    start, requested_end = getdate(from_date), getdate(to_date)
    if start > requested_end:
        raise FrappeNumberingError("from_date must not be after to_date")
    if not reason.strip():
        raise FrappeNumberingError("A reason is required")
    fiscal_dates = frappe.db.get_value(
        "Fiscal Year", fiscal_year, ["year_start_date", "year_end_date"], as_dict=True
    )
    if not fiscal_dates or not (
        fiscal_dates.year_start_date <= start <= requested_end <= fiscal_dates.year_end_date
    ):
        raise FrappeNumberingError("The selected range must be inside the fiscal year")
    effective_end = fiscal_dates.year_end_date
    _assert_period_open(company, start, effective_end)

    frappe.db.sql("select name from `tabCompany` where name=%s for update", company)
    request_hash = _request_hash(company, fiscal_year, start, requested_end, reason)
    existing = frappe.db.get_value(
        "ASOUD Numbering Batch",
        {"request_hash": request_hash, "docstatus": 1, "status": "Completed"},
        "name",
    )
    if existing:
        return existing

    batch = frappe.get_doc(
        {
            "doctype": "ASOUD Numbering Batch",
            "company": company,
            "fiscal_year": fiscal_year,
            "from_date": start,
            "to_date": effective_end,
            "reason": reason.strip(),
            "request_hash": request_hash,
            "status": "Running",
        }
    ).insert()
    rows = frappe.db.sql(
        """
        select name, source_doctype, source_name, final_number, consolidation
          from `tabASOUD Accounting Document`
         where company=%s and fiscal_year=%s and posting_date between %s and %s
           and numbering_status!='Cancelled'
         order by posting_date, coalesce(posting_time, '00:00:00'),
                  source_creation, temporary_number, name
         for update
        """,
        (company, fiscal_year, start, effective_end),
        as_dict=True,
    )
    previous_max = frappe.db.sql(
        """
        select coalesce(max(final_number), 0)
          from `tabASOUD Accounting Document`
         where company=%s and fiscal_year=%s and posting_date < %s
           and numbering_status!='Cancelled'
        """,
        (company, fiscal_year, start),
    )[0][0]

    unit_numbers: dict[str, int] = {}
    changed_at = now_datetime()
    for row in rows:
        unit = f"C::{row.consolidation}" if row.consolidation else f"D::{row.name}"
        if unit not in unit_numbers:
            unit_numbers[unit] = int(previous_max) + len(unit_numbers) + 1
        new_number = unit_numbers[unit]
        if row.final_number != new_number:
            frappe.get_doc(
                {
                    "doctype": "ASOUD Number History",
                    "accounting_document": row.name,
                    "source_doctype": row.source_doctype,
                    "source_name": row.source_name,
                    "company": company,
                    "fiscal_year": fiscal_year,
                    "old_final_number": row.final_number,
                    "new_final_number": new_number,
                    "numbering_batch": batch.name,
                    "changed_at": changed_at,
                    "reason": reason.strip(),
                }
            ).insert(ignore_permissions=True)
        frappe.db.set_value(
            "ASOUD Accounting Document",
            row.name,
            {
                "final_number": new_number,
                "numbering_status": "Final",
                "numbering_batch": batch.name,
            },
            update_modified=False,
        )
        frappe.db.set_value(
            row.source_doctype,
            row.source_name,
            {"asoud_final_number": new_number, "asoud_numbering_status": "Final"},
            update_modified=False,
        )

    batch.db_set({"status": "Completed", "document_count": len(rows), "unit_count": len(unit_numbers)})
    batch.submit()
    return batch.name


def lock_period(
    *,
    company: str,
    fiscal_year: str,
    from_date: str,
    to_date: str,
    reason: str = "Manual period lock",
    fiscal_period: str | None = None,
) -> str:
    import frappe
    from frappe.utils import getdate

    start, end = getdate(from_date), getdate(to_date)
    reason = reason.strip()
    if start > end:
        raise FrappeNumberingError("from_date must not be after to_date")
    if not reason:
        raise FrappeNumberingError("Lock reason is required")
    _assert_period_open(company, start, end)
    if frappe.db.exists(
        "ASOUD Accounting Document",
        {
            "company": company,
            "fiscal_year": fiscal_year,
            "posting_date": ["between", [start, end]],
            "numbering_status": "Temporary",
        },
    ):
        raise FrappeNumberingError(
            "All submitted accounting documents must have a final number before locking"
        )
    lock = frappe.get_doc(
        {
            "doctype": "ASOUD Period Lock",
            "company": company,
            "fiscal_year": fiscal_year,
            "fiscal_period": fiscal_period,
            "from_date": start,
            "to_date": end,
            "lock_reason": reason,
        }
    ).insert()
    lock.submit()
    rows = frappe.get_all(
        "ASOUD Accounting Document",
        filters={
            "company": company,
            "fiscal_year": fiscal_year,
            "posting_date": ["between", [start, end]],
            "numbering_status": "Final",
        },
        fields=["name", "source_doctype", "source_name"],
    )
    for row in rows:
        frappe.db.set_value(
            "ASOUD Accounting Document", row.name, "numbering_status", "Locked", update_modified=False
        )
        frappe.db.set_value(
            row.source_doctype,
            row.source_name,
            "asoud_numbering_status",
            "Locked",
            update_modified=False,
        )
    from asoud_core.services.audit import append_event

    append_event(
        "period.locked",
        resource_doctype=lock.doctype,
        resource_name=lock.name,
        company=company,
        reason=reason,
        after={
            "fiscal_year": fiscal_year,
            "fiscal_period": fiscal_period,
            "from_date": start,
            "to_date": end,
            "document_count": len(rows),
        },
    )
    return lock.name


def unlock_period(*, lock_name: str, reason: str) -> str:
    import frappe
    from frappe.utils import now_datetime

    reason = reason.strip()
    if not reason:
        raise FrappeNumberingError("Unlock reason is required")
    lock = frappe.get_doc("ASOUD Period Lock", lock_name)
    if lock.docstatus != 1:
        raise FrappeNumberingError("Only a submitted period lock can be reopened")
    before = {
        "company": lock.company,
        "fiscal_year": lock.fiscal_year,
        "from_date": lock.from_date,
        "to_date": lock.to_date,
        "docstatus": lock.docstatus,
    }
    rows = frappe.get_all(
        "ASOUD Accounting Document",
        filters={
            "company": lock.company,
            "fiscal_year": lock.fiscal_year,
            "posting_date": ["between", [lock.from_date, lock.to_date]],
            "numbering_status": "Locked",
        },
        fields=["name", "source_doctype", "source_name"],
    )
    lock.db_set(
        {
            "unlocked_by": frappe.session.user,
            "unlocked_on": now_datetime(),
            "unlock_reason": reason,
        },
        update_modified=False,
    )
    lock.cancel()
    for row in rows:
        frappe.db.set_value(
            "ASOUD Accounting Document",
            row.name,
            "numbering_status",
            "Final",
            update_modified=False,
        )
        frappe.db.set_value(
            row.source_doctype,
            row.source_name,
            "asoud_numbering_status",
            "Final",
            update_modified=False,
        )
    from asoud_core.services.audit import append_event

    append_event(
        "period.unlocked",
        resource_doctype=lock.doctype,
        resource_name=lock.name,
        company=lock.company,
        reason=reason,
        before=before,
        after={"docstatus": 2, "document_count": len(rows)},
    )
    return lock.name
