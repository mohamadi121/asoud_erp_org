from __future__ import annotations

import json
from typing import Any


def normalize_item_payload(payload: str | dict[str, Any]) -> dict[str, Any]:
    values = json.loads(payload) if isinstance(payload, str) else dict(payload)
    kind = str(values.get("item_kind") or "Goods").strip()
    if kind not in {"Goods", "Service"}:
        raise ValueError("Unsupported item kind")
    name = str(values.get("item_name") or "").strip()
    if not name:
        raise ValueError("Item name is required")
    return {
        "item_code": str(values.get("item_code") or "").strip() or None,
        "item_name": name,
        "item_kind": kind,
        "item_group": str(values.get("item_group") or "").strip() or None,
        "stock_uom": str(values.get("stock_uom") or "").strip() or None,
        "description": str(values.get("description") or "").strip(),
        "disabled": bool(values.get("disabled", False)),
        "enabled": bool(values.get("enabled", True)),
        "default_branch": str(values.get("default_branch") or "").strip() or None,
        "default_warehouse": str(values.get("default_warehouse") or "").strip() or None,
        "income_account": str(values.get("income_account") or "").strip() or None,
        "expense_account": str(values.get("expense_account") or "").strip() or None,
    }


def _assert_manage(company: str, branch: str | None) -> None:
    import frappe

    if not {"System Manager", "Stock Manager"}.intersection(
        frappe.get_roles(frappe.session.user)
    ):
        frappe.throw("Not permitted", frappe.PermissionError)
    from asoud_core.permissions import can_access_context

    if not can_access_context(frappe.session.user, company, branch):
        frappe.throw("Not permitted", frappe.PermissionError)


def _options(company: str) -> dict[str, list[str]]:
    import frappe

    def names(doctype: str, filters: dict[str, Any] | None = None) -> list[str]:
        return frappe.get_all(doctype, filters=filters or {}, pluck="name", order_by="name")

    return {
        "item_groups": names("Item Group", {"is_group": 0}),
        "uoms": names("UOM", {"enabled": 1}),
        "branches": names("ASOUD Branch", {"company": company, "enabled": 1}),
        "warehouses": names("Warehouse", {"company": company, "is_group": 0, "disabled": 0}),
        "income_accounts": names("Account", {"company": company, "is_group": 0, "root_type": "Income"}),
        "expense_accounts": names("Account", {"company": company, "is_group": 0, "root_type": "Expense"}),
    }


def save_item(company: str, payload: str | dict[str, Any], branch: str | None = None) -> dict:
    import frappe
    from frappe.model.naming import make_autoname

    branch = branch or None
    _assert_manage(company, branch)
    try:
        values = normalize_item_payload(payload)
    except (TypeError, ValueError, json.JSONDecodeError) as exc:
        frappe.throw(str(exc))
    holding = frappe.db.get_value("Company", company, "asoud_holding")
    if values["item_code"]:
        item = frappe.get_doc("Item", values["item_code"])
        if item.asoud_holding != holding:
            frappe.throw("Item does not belong to the selected holding")
        before = item.as_dict()
    else:
        item = frappe.new_doc("Item")
        item.item_code = make_autoname(
            "GDS-.#####" if values["item_kind"] == "Goods" else "SRV-.#####"
        )
        before = None
    item.item_name = values["item_name"]
    item.item_group = values["item_group"] or item.item_group
    item.stock_uom = values["stock_uom"] or item.stock_uom
    if not item.item_group or not item.stock_uom:
        frappe.throw("Item group and unit of measure are required")
    item.description = values["description"]
    item.asoud_holding = holding
    item.asoud_item_kind = values["item_kind"]
    item.is_stock_item = 1 if values["item_kind"] == "Goods" else 0
    item.disabled = int(values["disabled"])
    item.save(ignore_permissions=True)

    key = f"{item.name}|{company}"
    profile = (
        frappe.get_doc("ASOUD Item Company Profile", key)
        if frappe.db.exists("ASOUD Item Company Profile", key)
        else frappe.new_doc("ASOUD Item Company Profile")
    )
    profile.profile_key = key
    profile.item = item.name
    profile.company = company
    for field in (
        "enabled", "default_branch", "default_warehouse", "income_account", "expense_account"
    ):
        profile.set(field, values[field])
    profile.save(ignore_permissions=True)

    from asoud_core.services.audit import append_event

    append_event(
        "item.saved", resource_doctype="Item", resource_name=item.name,
        company=company, branch=branch, before=before, after=item.as_dict(),
    )
    return item_detail(item.name, company)


def item_snapshot(company: str, branch: str | None = None, search: str | None = None) -> dict:
    import frappe
    from asoud_core.permissions import can_access_context

    branch = branch or None
    if not can_access_context(frappe.session.user, company, branch):
        frappe.throw("Not permitted", frappe.PermissionError)
    filters: dict[str, Any] = {"company": company}
    if branch:
        filters["default_branch"] = ["in", ("", branch)]
    profiles = frappe.get_all(
        "ASOUD Item Company Profile", filters=filters,
        fields=["item", "enabled", "default_branch", "default_warehouse", "income_account", "expense_account"],
        order_by="modified desc", limit=200,
    )
    item_names = [row.item for row in profiles]
    item_filters: dict[str, Any] = {"name": ["in", item_names]}
    if search and search.strip():
        item_filters["item_name"] = ["like", f"%{search.strip()}%"]
    items = frappe.get_all(
        "Item", filters=item_filters,
        fields=["name", "item_name", "asoud_item_kind", "item_group", "stock_uom", "disabled", "description"],
        order_by="modified desc",
    ) if item_names else []
    by_item = {row.item: row for row in profiles}
    return {
        "company": company, "branch": branch,
        "items": [{**row, "profile": by_item.get(row.name)} for row in items],
        "options": _options(company),
        "code_patterns": {"Goods": "GDS-#####", "Service": "SRV-#####"},
    }


def item_detail(item_code: str, company: str) -> dict:
    import frappe
    from asoud_core.permissions import can_access_company

    if not can_access_company(frappe.session.user, company):
        frappe.throw("Not permitted", frappe.PermissionError)
    profile = frappe.db.get_value(
        "ASOUD Item Company Profile", {"item": item_code, "company": company},
        ["enabled", "default_branch", "default_warehouse", "income_account", "expense_account"], as_dict=True,
    )
    if not profile:
        frappe.throw("Item is not configured for the selected company")
    item = frappe.get_doc("Item", item_code)
    return {"item": item.as_dict(), "profile": profile}
