from __future__ import annotations

import json
from datetime import date
from typing import Any


DETAIL_TYPES = (
    "Customer",
    "Supplier",
    "Employee",
    "Bank",
    "Cashbox",
    "Project",
    "Cost Center",
    "Branch",
    "Other",
)


def _as_bool(value: Any) -> bool:
    if isinstance(value, bool):
        return value
    if isinstance(value, (int, float)):
        return bool(value)
    return str(value or "").strip().lower() in {"1", "true", "yes", "on"}


def _optional_date(value: Any, field_label: str) -> str | None:
    normalized = str(value or "").strip()
    if not normalized:
        return None
    try:
        return date.fromisoformat(normalized).isoformat()
    except ValueError as exc:
        raise ValueError(f"{field_label} must be an ISO date") from exc


def normalize_rule_payload(payload: str | list[dict[str, Any]]) -> list[dict[str, Any]]:
    rows = json.loads(payload) if isinstance(payload, str) else payload
    if not isinstance(rows, list):
        raise ValueError("Rules payload must be a list")

    normalized: list[dict[str, Any]] = []
    seen: set[str] = set()
    for raw in rows:
        if not isinstance(raw, dict):
            raise ValueError("Each account-detail rule must be an object")
        detail_type = str(raw.get("detail_type") or "").strip()
        if detail_type not in DETAIL_TYPES:
            raise ValueError(f"Unsupported floating detail type: {detail_type}")
        if detail_type in seen:
            raise ValueError(f"Duplicate floating detail type: {detail_type}")
        seen.add(detail_type)
        valid_from = _optional_date(raw.get("valid_from"), "Valid from")
        valid_to = _optional_date(raw.get("valid_to"), "Valid to")
        if valid_from and valid_to and valid_to < valid_from:
            raise ValueError("Valid to cannot be before valid from")
        normalized.append(
            {
                "detail_type": detail_type,
                "required": _as_bool(raw.get("required")),
                "enabled": _as_bool(raw.get("enabled", True)),
                "default_floating_detail": (
                    str(raw.get("default_floating_detail") or "").strip() or None
                ),
                "valid_from": valid_from,
                "valid_to": valid_to,
            }
        )
    if sum(1 for row in normalized if row["required"] and row["enabled"]) > 1:
        raise ValueError(
            "Only one enabled floating-detail type can be required for one account"
        )
    return normalized


def normalize_account_payload(payload: str | dict[str, Any]) -> dict[str, Any]:
    values = json.loads(payload) if isinstance(payload, str) else dict(payload)
    normalized = {
        "name": str(values.get("name") or "").strip() or None,
        "account_name": str(values.get("account_name") or "").strip(),
        "account_number": str(values.get("account_number") or "").strip(),
        "parent_account": str(values.get("parent_account") or "").strip(),
        "is_group": _as_bool(values.get("is_group")),
        "account_type": str(values.get("account_type") or "").strip(),
        "account_currency": str(values.get("account_currency") or "IRR")
        .strip()
        .upper(),
        "disabled": _as_bool(values.get("disabled")),
        "rules": normalize_rule_payload(values.get("rules") or []),
    }
    for key, label in (
        ("account_name", "Account name"),
        ("account_number", "Account number"),
        ("parent_account", "Parent account"),
    ):
        if not normalized[key]:
            raise ValueError(f"{label} is required")
    if normalized["is_group"] and normalized["rules"]:
        raise ValueError("Group accounts cannot have floating-detail rules")
    if not normalized["account_number"].isdigit():
        raise ValueError("Account number must contain digits only")
    if normalized["account_currency"] != "IRR":
        raise ValueError("Iranian chart accounts must use IRR")
    return normalized


def snapshot(company: str) -> dict[str, Any]:
    import frappe

    company_doc = frappe.get_doc("Company", company)
    if not company_doc.has_permission("read"):
        frappe.throw("Not permitted", frappe.PermissionError)

    enabled_detail_names = frappe.get_all(
        "ASOUD Floating Detail Company",
        filters={"company": company, "enabled": 1},
        pluck="parent",
    )
    floating_details = (
        frappe.get_all(
            "ASOUD Floating Detail",
            filters={"name": ["in", enabled_detail_names], "enabled": 1},
            fields=["name", "detail_title", "detail_type"],
            order_by="detail_type asc, detail_title asc",
        )
        if enabled_detail_names
        else []
    )

    return {
        "company": company,
        "detail_types": list(DETAIL_TYPES),
        "floating_details": floating_details,
        "accounts": frappe.get_all(
            "Account",
            filters={"company": company},
            fields=[
                "name",
                "account_name",
                "account_number",
                "parent_account",
                "root_type",
                "report_type",
                "account_type",
                "account_currency",
                "is_group",
                "disabled",
            ],
            order_by="account_number asc, name asc",
        ),
        "rules": frappe.get_all(
            "ASOUD Account Detail Rule",
            filters={"company": company},
            fields=[
                "name",
                "account",
                "detail_type",
                "required",
                "enabled",
                "default_floating_detail",
                "valid_from",
                "valid_to",
            ],
            order_by="account asc, detail_type asc",
        ),
    }


def save_account(
    company: str,
    payload: str | dict[str, Any],
) -> dict[str, Any]:
    import frappe

    frappe.only_for(("System Manager", "Accounts Manager"))
    company_doc = frappe.get_doc("Company", company)
    if not company_doc.has_permission("write"):
        frappe.throw("Not permitted", frappe.PermissionError)

    try:
        values = normalize_account_payload(payload)
    except (TypeError, ValueError, json.JSONDecodeError) as exc:
        frappe.throw(str(exc))

    parent = frappe.db.get_value(
        "Account",
        values["parent_account"],
        ["name", "company", "root_type", "report_type", "account_currency"],
        as_dict=True,
    )
    if not parent or parent.company != company:
        frappe.throw("Parent account does not belong to the selected company")

    duplicate_filters: dict[str, Any] = {
        "company": company,
        "account_number": values["account_number"],
    }
    if values["name"]:
        duplicate_filters["name"] = ["!=", values["name"]]
    if frappe.db.exists("Account", duplicate_filters):
        frappe.throw("Account number already exists in this company")

    if values["name"]:
        account = frappe.get_doc("Account", values["name"])
        if account.company != company or not account.has_permission("write"):
            frappe.throw("Not permitted", frappe.PermissionError)
    else:
        account = frappe.new_doc("Account")
        account.company = company

    before = {
        "account_name": account.get("account_name"),
        "account_number": account.get("account_number"),
        "parent_account": account.get("parent_account"),
        "is_group": account.get("is_group"),
        "account_type": account.get("account_type"),
        "disabled": account.get("disabled"),
    }
    account.update(
        {
            "account_name": values["account_name"],
            "account_number": values["account_number"],
            "parent_account": parent.name,
            "root_type": parent.root_type,
            "report_type": parent.report_type,
            "account_type": values["account_type"],
            "account_currency": "IRR",
            "is_group": int(values["is_group"]),
            "disabled": int(values["disabled"]),
        }
    )
    account.save()
    _replace_rules(company, account.name, values["rules"])

    from asoud_core.services.audit import append_event

    append_event(
        "chart_account.saved",
        company=company,
        resource_doctype="Account",
        resource_name=account.name,
        before=before,
        after={
            "account_name": account.account_name,
            "account_number": account.account_number,
            "parent_account": account.parent_account,
            "is_group": account.is_group,
            "account_type": account.account_type,
            "disabled": account.disabled,
            "detail_rules": values["rules"],
        },
    )
    return snapshot(company)


def save_rules(
    company: str,
    account: str,
    payload: str | list[dict[str, Any]],
) -> dict[str, Any]:
    import frappe

    frappe.only_for(("System Manager", "Accounts Manager"))
    account_row = frappe.db.get_value(
        "Account",
        account,
        ["company", "is_group"],
        as_dict=True,
    )
    if not account_row or account_row.company != company:
        frappe.throw("Account does not belong to the selected company")
    if account_row.is_group:
        frappe.throw("Group accounts cannot have floating-detail rules")
    try:
        rules = normalize_rule_payload(payload)
    except (TypeError, ValueError, json.JSONDecodeError) as exc:
        frappe.throw(str(exc))
    _replace_rules(company, account, rules)
    return snapshot(company)


def _replace_rules(
    company: str,
    account: str,
    rules: list[dict[str, Any]],
) -> None:
    import frappe

    existing_names = frappe.get_all(
        "ASOUD Account Detail Rule",
        filters={"company": company, "account": account},
        fields=["name", "detail_type"],
    )
    existing = {row.detail_type: row.name for row in existing_names}
    requested = {row["detail_type"] for row in rules}

    for detail_type, name in existing.items():
        if detail_type in requested:
            continue
        doc = frappe.get_doc("ASOUD Account Detail Rule", name)
        if doc.enabled:
            doc.enabled = 0
            doc.save()

    for row in rules:
        doc = (
            frappe.get_doc(
                "ASOUD Account Detail Rule",
                existing[row["detail_type"]],
            )
            if row["detail_type"] in existing
            else frappe.new_doc("ASOUD Account Detail Rule")
        )
        doc.update({"company": company, "account": account, **row})
        doc.save()


def eligible_details(
    company: str,
    account: str,
    query: str = "",
    limit: int = 20,
) -> list[dict[str, Any]]:
    import frappe

    account_company = frappe.db.get_value("Account", account, "company")
    if account_company != company:
        frappe.throw("Account does not belong to the selected company")

    today = date.today().isoformat()
    rule_rows = frappe.get_all(
        "ASOUD Account Detail Rule",
        filters={
            "company": company,
            "account": account,
            "enabled": 1,
        },
        fields=["detail_type", "required", "default_floating_detail", "valid_from", "valid_to"],
    )
    active_rules = [
        row
        for row in rule_rows
        if (not row.valid_from or str(row.valid_from) <= today)
        and (not row.valid_to or str(row.valid_to) >= today)
    ]
    allowed_types = [row.detail_type for row in active_rules]
    if not allowed_types:
        return []

    enabled_parents = frappe.get_all(
        "ASOUD Floating Detail Company",
        filters={"company": company, "enabled": 1},
        pluck="parent",
    )
    if not enabled_parents:
        return []
    filters: dict[str, Any] = {
        "name": ["in", enabled_parents],
        "enabled": 1,
        "detail_type": ["in", allowed_types],
    }
    if query.strip():
        filters["detail_title"] = ["like", f"%{query.strip()}%"]
    rows = frappe.get_all(
        "ASOUD Floating Detail",
        filters=filters,
        fields=["name", "detail_title", "detail_type", "reference_doctype", "reference_name"],
        order_by="detail_title asc",
        limit_page_length=max(1, min(int(limit), 100)),
    )
    defaults = {
        row.default_floating_detail
        for row in active_rules
        if row.default_floating_detail
    }
    return [{**dict(row), "is_default": row.name in defaults} for row in rows]
