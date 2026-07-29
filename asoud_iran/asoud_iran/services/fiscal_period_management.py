from __future__ import annotations

import json
from typing import Any


def _bool(value: Any, default: bool = True) -> bool:
    if value is None:
        return default
    if isinstance(value, str):
        return value.strip().lower() not in {"", "0", "false", "no"}
    return bool(value)


def normalize_fiscal_year(payload: str | dict[str, Any]) -> dict[str, Any]:
    values = json.loads(payload) if isinstance(payload, str) else dict(payload)
    result = {
        "name": str(values.get("name") or "").strip() or None,
        "year_name": str(values.get("year_name") or values.get("year") or "").strip(),
        "from_date": str(
            values.get("from_date") or values.get("year_start_date") or ""
        ).strip(),
        "to_date": str(
            values.get("to_date") or values.get("year_end_date") or ""
        ).strip(),
        "disabled": _bool(values.get("disabled"), False),
    }
    if not result["year_name"] or not result["from_date"] or not result["to_date"]:
        raise ValueError("Fiscal year name, start date and end date are required")
    if result["from_date"] > result["to_date"]:
        raise ValueError("Fiscal year start date cannot be after end date")
    return result


def normalize_fiscal_period(payload: str | dict[str, Any]) -> dict[str, Any]:
    values = json.loads(payload) if isinstance(payload, str) else dict(payload)
    result = {
        "name": str(values.get("name") or "").strip() or None,
        "fiscal_year": str(values.get("fiscal_year") or "").strip(),
        "period_name": str(values.get("period_name") or "").strip(),
        "period_type": str(values.get("period_type") or "Standard").strip(),
        "from_date": str(values.get("from_date") or "").strip(),
        "to_date": str(values.get("to_date") or "").strip(),
        "enabled": _bool(values.get("enabled"), True),
    }
    if (
        not result["fiscal_year"]
        or not result["period_name"]
        or not result["from_date"]
        or not result["to_date"]
    ):
        raise ValueError("Fiscal year, period name and date range are required")
    if result["period_type"] not in {"Standard", "Adjustment"}:
        raise ValueError("Unsupported fiscal period type")
    if result["from_date"] > result["to_date"]:
        raise ValueError("Fiscal period start date cannot be after end date")
    return result


def normalize_period_lock(payload: str | dict[str, Any]) -> dict[str, Any]:
    values = json.loads(payload) if isinstance(payload, str) else dict(payload)
    result = {
        "fiscal_year": str(values.get("fiscal_year") or "").strip(),
        "fiscal_period": str(values.get("fiscal_period") or "").strip() or None,
        "from_date": str(values.get("from_date") or "").strip(),
        "to_date": str(values.get("to_date") or "").strip(),
        "reason": str(values.get("reason") or "").strip(),
    }
    if (
        not result["fiscal_year"]
        or not result["from_date"]
        or not result["to_date"]
        or not result["reason"]
    ):
        raise ValueError("Fiscal year, date range and lock reason are required")
    if result["from_date"] > result["to_date"]:
        raise ValueError("Lock start date cannot be after end date")
    return result


def _assert_manage(company: str) -> None:
    import frappe

    frappe.only_for(("System Manager", "Accounts Manager"))
    from asoud_core.permissions import can_access_company

    if not can_access_company(frappe.session.user, company):
        frappe.throw("Not permitted", frappe.PermissionError)


def save_fiscal_year(company: str, payload: str | dict[str, Any]) -> dict:
    import frappe

    _assert_manage(company)
    try:
        values = normalize_fiscal_year(payload)
    except (TypeError, ValueError, json.JSONDecodeError) as exc:
        frappe.throw(str(exc))
    if values["name"]:
        doc = frappe.get_doc("Fiscal Year", values["name"])
        assigned = {row.company for row in doc.companies}
        if assigned and company not in assigned:
            frappe.throw("Fiscal year does not belong to the selected company")
        if not assigned:
            frappe.throw("A global fiscal year cannot be edited from company settings")
        before = doc.as_dict()
    else:
        if frappe.db.exists("Fiscal Year", values["year_name"]):
            frappe.throw("Fiscal year name already exists")
        doc = frappe.new_doc("Fiscal Year")
        doc.year = values["year_name"]
        doc.append("companies", {"company": company})
        before = None
    doc.year_start_date = values["from_date"]
    doc.year_end_date = values["to_date"]
    doc.disabled = int(values["disabled"])
    doc.save()
    from asoud_core.services.audit import append_event

    append_event(
        "fiscal_year.saved",
        resource_doctype=doc.doctype,
        resource_name=doc.name,
        company=company,
        before=before,
        after=doc.as_dict(),
    )
    from asoud_iran.services.financial_settings import snapshot

    return snapshot(company)


def save_fiscal_period(company: str, payload: str | dict[str, Any]) -> dict:
    import frappe

    _assert_manage(company)
    try:
        values = normalize_fiscal_period(payload)
    except (TypeError, ValueError, json.JSONDecodeError) as exc:
        frappe.throw(str(exc))
    if values["name"]:
        doc = frappe.get_doc("ASOUD Fiscal Period", values["name"])
        if doc.company != company:
            frappe.throw("Fiscal period does not belong to the selected company")
        before = doc.as_dict()
    else:
        doc = frappe.new_doc("ASOUD Fiscal Period")
        before = None
    doc.update(
        {
            "company": company,
            **{key: value for key, value in values.items() if key != "name"},
        }
    )
    doc.save()
    from asoud_core.services.audit import append_event

    append_event(
        "fiscal_period.saved",
        resource_doctype=doc.doctype,
        resource_name=doc.name,
        company=company,
        before=before,
        after=doc.as_dict(),
    )
    from asoud_iran.services.financial_settings import snapshot

    return snapshot(company)


def lock_financial_period(company: str, payload: str | dict[str, Any]) -> dict:
    _assert_manage(company)
    try:
        values = normalize_period_lock(payload)
    except (TypeError, ValueError, json.JSONDecodeError) as exc:
        import frappe

        frappe.throw(str(exc))
    from asoud_core.services.journal_numbering import lock_period

    lock_period(company=company, **values)
    from asoud_iran.services.financial_settings import snapshot

    return snapshot(company)


def unlock_financial_period(company: str, lock_name: str, reason: str) -> dict:
    import frappe

    _assert_manage(company)
    lock_company = frappe.db.get_value("ASOUD Period Lock", lock_name, "company")
    if lock_company != company:
        frappe.throw("Period lock does not belong to the selected company")
    from asoud_core.services.journal_numbering import unlock_period

    unlock_period(lock_name=lock_name, reason=reason)
    from asoud_iran.services.financial_settings import snapshot

    return snapshot(company)
