from __future__ import annotations

import json
import re
from typing import Any


def snapshot(company: str | None = None) -> dict[str, Any]:
    import frappe

    frappe.only_for(("System Manager", "Accounts Manager"))
    holdings = frappe.get_all(
        "ASOUD Holding",
        fields=[
            "name", "holding_name", "holding_code",
            "consolidation_currency", "enabled",
        ],
        order_by="holding_name",
    )
    company_filters = {"is_group": 0}
    if company:
        company_filters["name"] = company
    companies = frappe.get_all(
        "Company",
        filters=company_filters,
        fields=[
            "name", "company_name", "abbr", "default_currency",
            "country", "asoud_holding", "asoud_entity_type",
            "asoud_national_id", "asoud_economic_code",
            "asoud_registration_number", "asoud_legal_type",
            "asoud_phone", "asoud_email", "asoud_website",
            "asoud_province", "asoud_city", "asoud_legal_address",
            "asoud_postal_code", "asoud_logo",
        ],
        order_by="company_name",
    )
    branches = frappe.get_all(
        "ASOUD Branch",
        filters={"company": company} if company else None,
        fields=[
            "name", "branch_name", "branch_code", "company", "holding",
            "enabled", "default_warehouse", "default_cost_center",
        ],
        order_by="company, branch_name",
    )
    return {
        "holdings": holdings,
        "companies": companies,
        "branches": branches,
        "counts": {
            "holdings": len(holdings),
            "companies": len(companies),
            "branches": len(branches),
        },
    }


def save(payload: str | dict[str, Any]) -> dict[str, Any]:
    import frappe

    frappe.only_for(("System Manager", "Accounts Manager"))
    values = json.loads(payload) if isinstance(payload, str) else dict(payload)
    kind = str(values.pop("kind", "")).strip().lower()
    if kind == "holding":
        return _save_holding(values)
    if kind == "company":
        return _save_company(values)
    if kind == "branch":
        return _save_branch(values)
    frappe.throw("Organization unit kind must be Holding, Company or Branch")


def _save_holding(values: dict[str, Any]) -> dict[str, Any]:
    import frappe

    required = _required(values, "holding_name", "holding_code")
    code = _code(required["holding_code"])
    existing = frappe.db.exists("ASOUD Holding", code)
    doc = frappe.get_doc("ASOUD Holding", existing) if existing else frappe.new_doc("ASOUD Holding")
    doc.update({
        "holding_name": required["holding_name"],
        "holding_code": code,
        "consolidation_currency": values.get("consolidation_currency") or "IRR",
        "entity_type": values.get("entity_type") or "Legal",
        "national_id": _digits(values.get("national_id")) or None,
        "economic_code": _digits(values.get("economic_code")) or None,
        "registration_number": values.get("registration_number") or None,
        "legal_type": values.get("legal_type") or None,
        "consolidation_method": values.get("consolidation_method") or "Full",
        "reporting_calendar": values.get("reporting_calendar") or None,
        "eliminate_intercompany": int(
            _boolean(values.get("eliminate_intercompany", True))
        ),
        "enabled": int(_boolean(values.get("enabled", True))),
    })
    doc.save()
    return {"kind": "Holding", "name": doc.name, "created": not bool(existing)}


def _save_company(values: dict[str, Any]) -> dict[str, Any]:
    import frappe

    required = _required(values, "company_name", "abbr")
    entity_type = values.get("entity_type") or "Legal"
    if entity_type not in ("Legal", "Natural"):
        frappe.throw("Entity type must be Legal or Natural")
    national_id = _digits(values.get("national_id"))
    if national_id and len(national_id) not in (10, 11):
        frappe.throw("National ID must contain 10 or 11 digits")
    name = values.get("name")
    existing = name if name and frappe.db.exists("Company", name) else None
    doc = frappe.get_doc("Company", existing) if existing else frappe.new_doc("Company")
    doc.update({
        "company_name": required["company_name"],
        "abbr": _code(required["abbr"]),
        "default_currency": values.get("default_currency") or "IRR",
        "country": values.get("country") or "Iran",
        "asoud_holding": values.get("holding") or None,
        "asoud_entity_type": entity_type,
        "asoud_national_id": national_id or None,
        "asoud_economic_code": _digits(values.get("economic_code")) or None,
        "asoud_registration_number": str(values.get("registration_number") or "").strip() or None,
        "asoud_legal_type": values.get("legal_type") or None,
        "asoud_phone": values.get("phone") or None,
        "asoud_email": values.get("email") or None,
        "asoud_website": values.get("website") or None,
        "asoud_province": values.get("province") or None,
        "asoud_city": values.get("city") or None,
        "asoud_legal_address": values.get("legal_address") or None,
        "asoud_postal_code": _digits(values.get("postal_code")) or None,
        "asoud_logo": values.get("logo") or None,
        "asoud_first_name": values.get("first_name") or None,
        "asoud_last_name": values.get("last_name") or None,
        "asoud_birth_date": values.get("birth_date") or None,
        "asoud_activity_type": values.get("activity_type") or None,
    })
    doc.save()
    return {"kind": "Company", "name": doc.name, "created": not bool(existing)}


def _save_branch(values: dict[str, Any]) -> dict[str, Any]:
    import frappe

    required = _required(values, "branch_name", "branch_code", "company")
    if not frappe.db.exists("Company", required["company"]):
        frappe.throw("Selected company does not exist")
    code = _code(required["branch_code"])
    existing = values.get("name") or frappe.db.exists(
        "ASOUD Branch", {"company": required["company"], "branch_code": code}
    )
    doc = frappe.get_doc("ASOUD Branch", existing) if existing else frappe.new_doc("ASOUD Branch")
    doc.update({
        "branch_name": required["branch_name"],
        "branch_code": code,
        "company": required["company"],
        "enabled": int(_boolean(values.get("enabled", True))),
        "default_warehouse": values.get("default_warehouse") or None,
        "default_cost_center": values.get("default_cost_center") or None,
        "default_cash_account": values.get("default_cash_account") or None,
        "default_bank_account": values.get("default_bank_account") or None,
        "branch_manager": values.get("manager") or None,
        "numbering_series": values.get("numbering_series") or None,
        "address": values.get("address") or None,
        "activity_scope": values.get("activity_scope") or None,
    })
    doc.save()
    return {"kind": "Branch", "name": doc.name, "created": not bool(existing)}


def _required(values: dict[str, Any], *fields: str) -> dict[str, str]:
    import frappe

    result = {field: str(values.get(field) or "").strip() for field in fields}
    missing = [field for field, value in result.items() if not value]
    if missing:
        frappe.throw(f"Missing required fields: {', '.join(missing)}")
    return result


def _digits(value: Any) -> str:
    normalized = str(value or "").translate(
        str.maketrans("۰۱۲۳۴۵۶۷۸۹٠١٢٣٤٥٦٧٨٩", "01234567890123456789")
    )
    return re.sub(r"\D", "", normalized)


def _code(value: Any) -> str:
    import frappe

    code = re.sub(r"[^A-Za-z0-9_-]", "", str(value or "").strip().upper())
    if not code:
        frappe.throw("Code must contain Latin letters or digits")
    return code


def _boolean(value: Any) -> bool:
    return str(value).lower() not in ("0", "false", "no", "off", "")
