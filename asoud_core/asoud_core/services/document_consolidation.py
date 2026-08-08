from __future__ import annotations

import json
from typing import Any


def workspace(company: str, posting_date: str | None = None) -> dict[str, Any]:
    import frappe

    company_doc = frappe.get_doc("Company", company)
    if not company_doc.has_permission("read"):
        frappe.throw("Not permitted", frappe.PermissionError)

    base_filters: dict[str, Any] = {
        "company": company,
        "numbering_status": "Temporary",
        "consolidation": ["is", "not set"],
    }
    available_rows = frappe.get_all(
        "ASOUD Accounting Document",
        filters=base_filters,
        fields=["posting_date"],
        order_by="posting_date desc",
    )
    filters = dict(base_filters)
    if posting_date:
        filters["posting_date"] = posting_date

    candidates = frappe.get_all(
        "ASOUD Accounting Document",
        filters=filters,
        fields=[
            "name",
            "posting_date",
            "source_doctype",
            "source_name",
            "temporary_number",
            "source_creation",
        ],
        order_by="posting_date, source_creation, name",
        limit_page_length=500,
    )
    fiscal_years = frappe.get_all(
        "Fiscal Year",
        fields=["name", "year_start_date", "year_end_date", "disabled"],
        order_by="year_start_date desc",
    )
    assignments = frappe.get_all(
        "Fiscal Year Company",
        fields=["parent", "company"],
    )
    assigned: dict[str, set[str]] = {}
    for row in assignments:
        assigned.setdefault(row.parent, set()).add(row.company)

    return {
        "company": company,
        "posting_date": posting_date or "",
        "candidates": candidates,
        "available_dates": sorted(
            {str(row.posting_date) for row in available_rows}, reverse=True
        ),
        "fiscal_years": [
            dict(row)
            for row in fiscal_years
            if not row.disabled
            and (not assigned.get(row.name) or company in assigned[row.name])
        ],
        "recent_consolidations": frappe.get_all(
            "ASOUD Document Consolidation",
            filters={"company": company, "docstatus": 1},
            fields=["name", "posting_date", "reason", "modified"],
            order_by="modified desc",
            limit=10,
        ),
    }


def create(
    company: str,
    posting_date: str,
    documents: str | list[str],
    reason: str,
) -> dict[str, Any]:
    import frappe

    frappe.only_for(("Accounts Manager", "System Manager"))
    company_doc = frappe.get_doc("Company", company)
    if not company_doc.has_permission("read"):
        frappe.throw("Not permitted", frappe.PermissionError)
    try:
        names = _normalize_document_names(documents)
    except (TypeError, ValueError, json.JSONDecodeError) as exc:
        frappe.throw(str(exc))
    reason = (reason or "").strip()
    posting_date = (posting_date or "").strip()
    if not posting_date:
        frappe.throw("Posting date is required")
    if not reason:
        frappe.throw("Consolidation reason is required")
    if len(names) < 2:
        frappe.throw("At least two documents must be selected")

    doc = frappe.get_doc(
        {
            "doctype": "ASOUD Document Consolidation",
            "company": company,
            "posting_date": posting_date,
            "reason": reason,
            "documents": [{"accounting_document": name} for name in names],
        }
    )
    doc.insert()
    doc.submit()
    return {
        "name": doc.name,
        "company": company,
        "posting_date": posting_date,
        "document_count": len(names),
    }


def _normalize_document_names(documents: str | list[str]) -> list[str]:
    values = json.loads(documents) if isinstance(documents, str) else documents
    if not isinstance(values, list):
        raise ValueError("Documents must be a JSON list")
    names = [str(value or "").strip() for value in values]
    names = [name for name in names if name]
    if len(names) != len(set(names)):
        raise ValueError("A document may be selected only once")
    return names
