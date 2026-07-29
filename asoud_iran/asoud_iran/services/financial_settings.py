from __future__ import annotations

import json
from typing import Any


AMOUNT_UNITS = {"IRR", "TOMAN"}
CALENDAR_DISPLAYS = {"Jalali", "Gregorian"}


def snapshot(company: str) -> dict[str, Any]:
    import frappe

    company_doc = frappe.get_doc("Company", company)
    if not company_doc.has_permission("read"):
        frappe.throw("Not permitted", frappe.PermissionError)

    settings = frappe.db.get_value(
        "ASOUD Iran Company Settings",
        company,
        [
            "company",
            "coa_template",
            "base_currency",
            "amount_input_unit",
            "calendar_display",
            "timezone",
            "setup_version",
            "setup_status",
        ],
        as_dict=True,
    )
    values = dict(settings or {})
    values.update(
        {
            "company": company,
            "company_name": company_doc.company_name,
            "base_currency": values.get("base_currency")
            or company_doc.default_currency
            or "IRR",
            "amount_input_unit": values.get("amount_input_unit") or "IRR",
            "calendar_display": values.get("calendar_display") or "Jalali",
            "timezone": values.get("timezone") or "Asia/Tehran",
            "setup_status": values.get("setup_status") or "Pending",
        }
    )

    templates = frappe.get_all(
        "ASOUD COA Template",
        filters={"docstatus": 1},
        fields=[
            "name",
            "template_title",
            "version",
            "business_scope",
            "base_currency",
        ],
        order_by="template_title, version desc",
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
    companies_by_year: dict[str, set[str]] = {}
    for row in assignments:
        companies_by_year.setdefault(row.parent, set()).add(row.company)
    applicable_years = [
        {
            **dict(row),
            "is_global": not bool(companies_by_year.get(row.name)),
        }
        for row in fiscal_years
        if not companies_by_year.get(row.name)
        or company in companies_by_year[row.name]
    ]

    return {
        "settings": values,
        "coa_templates": templates,
        "fiscal_years": applicable_years,
        "period_locks": frappe.get_all(
            "ASOUD Period Lock",
            filters={"company": company},
            fields=[
                "name",
                "fiscal_year",
                "fiscal_period",
                "from_date",
                "to_date",
                "lock_reason",
                "docstatus",
                "unlocked_by",
                "unlocked_on",
                "unlock_reason",
            ],
            order_by="from_date desc",
        ),
        "fiscal_periods": frappe.get_all(
            "ASOUD Fiscal Period",
            filters={"company": company},
            fields=[
                "name",
                "fiscal_year",
                "period_name",
                "period_type",
                "from_date",
                "to_date",
                "enabled",
            ],
            order_by="from_date desc",
        ),
    }


def save(company: str, payload: str | dict[str, Any]) -> dict[str, Any]:
    import frappe

    frappe.only_for(("System Manager", "Accounts Manager"))
    company_doc = frappe.get_doc("Company", company)
    if not company_doc.has_permission("write"):
        frappe.throw("Not permitted", frappe.PermissionError)
    if company_doc.default_currency != "IRR":
        frappe.throw("Iranian accounting requires IRR as the company ledger currency")

    try:
        values = _normalize_payload(payload)
    except (TypeError, ValueError, json.JSONDecodeError) as exc:
        frappe.throw(str(exc))
    template = frappe.db.get_value(
        "ASOUD COA Template",
        values["coa_template"],
        ["name", "docstatus", "base_currency"],
        as_dict=True,
    )
    if not template or template.docstatus != 1:
        frappe.throw("Only a submitted chart-of-accounts template can be selected")
    if template.base_currency != "IRR":
        frappe.throw("The selected chart-of-accounts template must use IRR")

    existing = frappe.db.exists("ASOUD Iran Company Settings", company)
    before = (
        frappe.db.get_value(
            "ASOUD Iran Company Settings",
            company,
            ["coa_template", "amount_input_unit", "calendar_display"],
            as_dict=True,
        )
        if existing
        else None
    )
    doc = (
        frappe.get_doc("ASOUD Iran Company Settings", existing)
        if existing
        else frappe.new_doc("ASOUD Iran Company Settings")
    )
    doc.update(
        {
            "company": company,
            "coa_template": values["coa_template"],
            "base_currency": "IRR",
            "amount_input_unit": values["amount_input_unit"],
            "calendar_display": values["calendar_display"],
            "timezone": "Asia/Tehran",
        }
    )
    doc.save()

    from asoud_core.services.audit import append_event

    append_event(
        "financial_settings.updated",
        company=company,
        resource_doctype="ASOUD Iran Company Settings",
        resource_name=doc.name,
        before=dict(before or {}),
        after={
            "coa_template": doc.coa_template,
            "amount_input_unit": doc.amount_input_unit,
            "calendar_display": doc.calendar_display,
        },
    )
    return snapshot(company)


def _normalize_payload(payload: str | dict[str, Any]) -> dict[str, str]:
    values = json.loads(payload) if isinstance(payload, str) else dict(payload)
    normalized = {
        "coa_template": str(values.get("coa_template") or "").strip(),
        "amount_input_unit": str(
            values.get("amount_input_unit") or "IRR"
        ).strip().upper(),
        "calendar_display": str(
            values.get("calendar_display") or "Jalali"
        ).strip(),
    }
    if not normalized["coa_template"]:
        raise ValueError("Chart-of-accounts template is required")
    if normalized["amount_input_unit"] not in AMOUNT_UNITS:
        raise ValueError("Amount input unit must be IRR or TOMAN")
    if normalized["calendar_display"] not in CALENDAR_DISPLAYS:
        raise ValueError("Calendar display must be Jalali or Gregorian")
    return normalized
