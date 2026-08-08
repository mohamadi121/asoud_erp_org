from __future__ import annotations

import json
from typing import Any


SETTING_TYPES = {
    "Warehouse",
    "Warehouse Type",
    "Item Group",
    "UOM",
    "UOM Category",
    "UOM Conversion Factor",
}
MANAGER_ROLES = {"System Manager", "Stock Manager", "Item Manager"}


def _as_bool(value: Any, default: bool = False) -> bool:
    if value is None:
        return default
    if isinstance(value, str):
        return value.strip().lower() in {"1", "true", "yes", "on"}
    return bool(value)


def normalize_setting_payload(
    setting_type: str, payload: str | dict[str, Any]
) -> dict[str, Any]:
    if setting_type not in SETTING_TYPES:
        raise ValueError("Unsupported inventory setting type")
    values = json.loads(payload) if isinstance(payload, str) else dict(payload)
    name = str(values.get("name") or "").strip() or None

    if setting_type == "Warehouse":
        warehouse_name = str(values.get("warehouse_name") or "").strip()
        if not warehouse_name:
            raise ValueError("Warehouse name is required")
        return {
            "name": name,
            "warehouse_name": warehouse_name,
            "parent_warehouse": str(values.get("parent_warehouse") or "").strip()
            or None,
            "warehouse_type": str(values.get("warehouse_type") or "").strip()
            or None,
            "branch": str(values.get("branch") or "").strip() or None,
            "account": str(values.get("account") or "").strip() or None,
            "is_group": _as_bool(values.get("is_group")),
            "disabled": _as_bool(values.get("disabled")),
        }

    if setting_type == "Warehouse Type":
        label = str(values.get("warehouse_type") or values.get("label") or "").strip()
        if not label:
            raise ValueError("Warehouse type is required")
        return {
            "name": name,
            "label": label,
            "description": str(values.get("description") or "").strip(),
        }

    if setting_type == "Item Group":
        label = str(values.get("item_group_name") or values.get("label") or "").strip()
        if not label:
            raise ValueError("Item group name is required")
        return {
            "name": name,
            "label": label,
            "parent_item_group": str(values.get("parent_item_group") or "").strip()
            or None,
            "is_group": _as_bool(values.get("is_group")),
        }

    if setting_type == "UOM":
        label = str(values.get("uom_name") or values.get("label") or "").strip()
        if not label:
            raise ValueError("Unit of measure name is required")
        return {
            "name": name,
            "label": label,
            "enabled": _as_bool(values.get("enabled"), True),
            "must_be_whole_number": _as_bool(values.get("must_be_whole_number")),
        }

    if setting_type == "UOM Category":
        label = str(values.get("category_name") or values.get("label") or "").strip()
        if not label:
            raise ValueError("Unit category name is required")
        return {"name": name, "label": label}

    category = str(values.get("category") or "").strip()
    from_uom = str(values.get("from_uom") or "").strip()
    to_uom = str(values.get("to_uom") or "").strip()
    try:
        factor = float(values.get("value") or 0)
    except (TypeError, ValueError) as exc:
        raise ValueError("Conversion factor must be numeric") from exc
    if not category or not from_uom or not to_uom:
        raise ValueError("Category, source unit and destination unit are required")
    if from_uom == to_uom:
        raise ValueError("Source and destination units must be different")
    if factor <= 0:
        raise ValueError("Conversion factor must be positive")
    return {
        "name": name,
        "category": category,
        "from_uom": from_uom,
        "to_uom": to_uom,
        "value": factor,
    }


def _can_manage() -> bool:
    import frappe

    return bool(MANAGER_ROLES.intersection(frappe.get_roles(frappe.session.user)))


def _assert_context(company: str, branch: str | None, manage: bool = False) -> None:
    import frappe
    from asoud_core.permissions import can_access_context

    if not can_access_context(frappe.session.user, company, branch):
        frappe.throw("Not permitted", frappe.PermissionError)
    if manage and not _can_manage():
        frappe.throw("Inventory settings require an authorized manager", frappe.PermissionError)


def _rows(doctype: str, fields: list[str], **kwargs) -> list[dict[str, Any]]:
    import frappe

    return [dict(row) for row in frappe.get_all(doctype, fields=fields, **kwargs)]


def _dashboard(company: str, branch: str | None) -> dict[str, Any]:
    import frappe

    profile_rows = frappe.get_all(
        "ASOUD Item Company Profile",
        filters={"company": company, "enabled": 1},
        fields=["item", "default_branch"],
        limit_page_length=0,
    )
    profiles = [
        row.item
        for row in profile_rows
        if not branch or not row.default_branch or row.default_branch == branch
    ]
    item_rows = (
        frappe.get_all(
            "Item",
            filters={"name": ["in", profiles], "disabled": 0},
            fields=["name", "asoud_item_kind"],
            limit_page_length=0,
        )
        if profiles
        else []
    )
    conditions = ["w.company=%s", "w.is_group=0", "w.disabled=0"]
    params: list[Any] = [company]
    if branch:
        conditions.append("w.asoud_branch=%s")
        params.append(branch)
    balance = frappe.db.sql(
        f"""
        select coalesce(sum(b.actual_qty), 0) as actual_qty,
               coalesce(sum(b.stock_value), 0) as stock_value,
               count(distinct case when b.actual_qty != 0 then b.item_code end) as stocked_items,
               coalesce(sum(case when b.actual_qty < 0 then 1 else 0 end), 0) as negative_bins
          from `tabBin` b
          join `tabWarehouse` w on w.name=b.warehouse
         where {' and '.join(conditions)}
        """,
        tuple(params),
        as_dict=True,
    )[0]
    warehouse_filters: dict[str, Any] = {
        "company": company,
        "is_group": 0,
        "disabled": 0,
    }
    if branch:
        warehouse_filters["asoud_branch"] = branch
    movement_filters: dict[str, Any] = {"company": company}
    if branch:
        movement_filters["asoud_branch"] = branch
    return {
        "item_count": len(item_rows),
        "goods_count": sum(row.asoud_item_kind == "Goods" for row in item_rows),
        "service_count": sum(row.asoud_item_kind == "Service" for row in item_rows),
        "warehouse_count": frappe.db.count("Warehouse", warehouse_filters),
        "actual_qty": float(balance.actual_qty or 0),
        "stock_value": float(balance.stock_value or 0),
        "stocked_items": int(balance.stocked_items or 0),
        "negative_bins": int(balance.negative_bins or 0),
        "recent_movements": _rows(
            "Stock Entry",
            ["name", "stock_entry_type", "posting_date", "docstatus", "modified"],
            filters=movement_filters,
            order_by="posting_date desc, modified desc",
            limit_page_length=8,
        ),
    }


def workspace(company: str, branch: str | None = None) -> dict[str, Any]:
    import frappe

    branch = branch or None
    _assert_context(company, branch)
    warehouse_filters: dict[str, Any] = {"company": company}
    if branch:
        warehouse_filters["asoud_branch"] = branch
    return {
        "company": company,
        "branch": branch,
        "can_manage": _can_manage(),
        "dashboard": _dashboard(company, branch),
        "warehouses": _rows(
            "Warehouse",
            [
                "name",
                "warehouse_name",
                "parent_warehouse",
                "warehouse_type",
                "asoud_branch as branch",
                "account",
                "is_group",
                "disabled",
            ],
            filters=warehouse_filters,
            order_by="lft asc",
            limit_page_length=0,
        ),
        "warehouse_types": _rows(
            "Warehouse Type",
            ["name", "description"],
            order_by="name",
            limit_page_length=0,
        ),
        "item_groups": _rows(
            "Item Group",
            ["name", "item_group_name", "parent_item_group", "is_group"],
            order_by="lft asc",
            limit_page_length=0,
        ),
        "uoms": _rows(
            "UOM",
            ["name", "uom_name", "enabled", "must_be_whole_number"],
            order_by="name",
            limit_page_length=0,
        ),
        "uom_categories": _rows(
            "UOM Category",
            ["name", "category_name"],
            order_by="name",
            limit_page_length=0,
        ),
        "uom_conversions": _rows(
            "UOM Conversion Factor",
            ["name", "category", "from_uom", "to_uom", "value"],
            order_by="modified desc",
            limit_page_length=0,
        ),
        "branches": _rows(
            "ASOUD Branch",
            ["name", "branch_name"],
            filters={"company": company, "enabled": 1},
            order_by="branch_name",
            limit_page_length=0,
        ),
        "accounts": frappe.get_all(
            "Account",
            filters={"company": company, "is_group": 0, "root_type": "Asset"},
            pluck="name",
            order_by="name",
            limit_page_length=0,
        ),
    }


def save_setting(
    company: str,
    setting_type: str,
    payload: str | dict[str, Any],
    branch: str | None = None,
) -> dict[str, Any]:
    import frappe

    branch = branch or None
    _assert_context(company, branch, manage=True)
    try:
        values = normalize_setting_payload(setting_type, payload)
    except (TypeError, ValueError, json.JSONDecodeError) as exc:
        frappe.throw(str(exc))

    name = values.get("name")
    before = None
    if name:
        doc = frappe.get_doc(setting_type, name)
        before = doc.as_dict()
        if setting_type == "Warehouse" and doc.company != company:
            frappe.throw("Warehouse belongs to another company", frappe.PermissionError)
    else:
        doc = frappe.new_doc(setting_type)

    if setting_type == "Warehouse":
        target_branch = values["branch"] or branch
        if target_branch and frappe.db.get_value("ASOUD Branch", target_branch, "company") != company:
            frappe.throw("Warehouse branch must belong to the selected company")
        parent = values["parent_warehouse"]
        if not name and not parent:
            frappe.throw("A parent warehouse is required")
        if parent and frappe.db.get_value("Warehouse", parent, "company") != company:
            frappe.throw("Parent warehouse must belong to the selected company")
        doc.update(
            {
                "warehouse_name": values["warehouse_name"],
                "company": company,
                "parent_warehouse": parent,
                "warehouse_type": values["warehouse_type"],
                "asoud_branch": target_branch,
                "account": values["account"],
                "is_group": int(values["is_group"]),
                "disabled": int(values["disabled"]),
            }
        )
    elif setting_type == "Warehouse Type":
        if not name:
            doc.name = values["label"]
        doc.description = values["description"]
    elif setting_type == "Item Group":
        if not name:
            doc.item_group_name = values["label"]
        doc.parent_item_group = values["parent_item_group"] or (
            "All Item Groups" if frappe.db.exists("Item Group", "All Item Groups") else None
        )
        doc.is_group = int(values["is_group"])
    elif setting_type == "UOM":
        if not name:
            doc.uom_name = values["label"]
        doc.enabled = int(values["enabled"])
        doc.must_be_whole_number = int(values["must_be_whole_number"])
    elif setting_type == "UOM Category":
        if not name:
            doc.category_name = values["label"]
    else:
        doc.update(
            {
                "category": values["category"],
                "from_uom": values["from_uom"],
                "to_uom": values["to_uom"],
                "value": values["value"],
            }
        )

    doc.save(ignore_permissions=True)
    from asoud_core.services.audit import append_event

    append_event(
        "inventory.setting.saved",
        resource_doctype=setting_type,
        resource_name=doc.name,
        company=company,
        branch=branch,
        before=before,
        after=doc.as_dict(),
    )
    return {"name": doc.name, "setting_type": setting_type}
