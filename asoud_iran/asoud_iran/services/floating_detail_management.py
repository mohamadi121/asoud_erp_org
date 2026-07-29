from __future__ import annotations

import json
from typing import Any

from asoud_iran.services.account_detail_rules import DETAIL_TYPES, _as_bool


def normalize_group_payload(payload: str | dict[str, Any]) -> dict[str, Any]:
    values = json.loads(payload) if isinstance(payload, str) else dict(payload)
    normalized = {
        "name": str(values.get("name") or "").strip() or None,
        "group_title": str(values.get("group_title") or "").strip(),
        "group_code": str(values.get("group_code") or "").strip().upper(),
        "detail_type": str(values.get("detail_type") or "").strip(),
        "parent_group": str(values.get("parent_group") or "").strip() or None,
        "enabled": _as_bool(values.get("enabled", True)),
    }
    if not normalized["group_title"]:
        raise ValueError("Floating detail group title is required")
    if not normalized["group_code"]:
        raise ValueError("Floating detail group code is required")
    if normalized["detail_type"] not in DETAIL_TYPES:
        raise ValueError("Unsupported floating detail type")
    return normalized


def normalize_detail_payload(payload: str | dict[str, Any]) -> dict[str, Any]:
    values = json.loads(payload) if isinstance(payload, str) else dict(payload)
    normalized = {
        "name": str(values.get("name") or "").strip() or None,
        "detail_title": str(values.get("detail_title") or "").strip(),
        "detail_group": str(values.get("detail_group") or "").strip(),
        "reference_doctype": str(values.get("reference_doctype") or "").strip() or None,
        "reference_name": str(values.get("reference_name") or "").strip() or None,
        "detail_code": str(values.get("detail_code") or "").strip(),
        "enabled": _as_bool(values.get("enabled", True)),
        "company_enabled": _as_bool(values.get("company_enabled", True)),
    }
    if not normalized["detail_title"]:
        raise ValueError("Floating detail title is required")
    if not normalized["detail_group"]:
        raise ValueError("Floating detail group is required")
    if not normalized["detail_code"]:
        raise ValueError("Company floating detail code is required")
    if bool(normalized["reference_doctype"]) != bool(normalized["reference_name"]):
        raise ValueError("Reference type and reference must be provided together")
    return normalized


def _company_holding(company: str) -> str:
    import frappe

    holding = frappe.db.get_value("Company", company, "asoud_holding")
    if not holding:
        frappe.throw("Company must belong to an ASOUD holding")
    return holding


def _assert_manage(company: str) -> str:
    import frappe

    frappe.only_for(("System Manager", "Accounts Manager"))
    from asoud_core.permissions import can_access_company

    if not can_access_company(frappe.session.user, company):
        frappe.throw("Not permitted", frappe.PermissionError)
    return _company_holding(company)


def snapshot(company: str) -> dict[str, Any]:
    import frappe

    from asoud_core.permissions import can_access_company

    if not can_access_company(frappe.session.user, company):
        frappe.throw("Not permitted", frappe.PermissionError)
    holding = _company_holding(company)
    groups = frappe.get_all(
        "ASOUD Floating Detail Group",
        filters={"holding": holding},
        fields=[
            "name",
            "group_title",
            "group_code",
            "detail_type",
            "parent_group",
            "enabled",
        ],
        order_by="detail_type asc, group_code asc",
    )
    mappings = frappe.get_all(
        "ASOUD Floating Detail Company",
        filters={"company": company},
        fields=["parent", "detail_code", "enabled"],
    )
    mapping_by_detail = {row.parent: row for row in mappings}
    details = frappe.get_all(
        "ASOUD Floating Detail",
        filters={"holding": holding},
        fields=[
            "name",
            "detail_title",
            "detail_type",
            "detail_group",
            "reference_doctype",
            "reference_name",
            "enabled",
        ],
        order_by="detail_type asc, detail_title asc",
    )
    return {
        "company": company,
        "holding": holding,
        "detail_types": list(DETAIL_TYPES),
        "groups": groups,
        "details": [
            {
                **dict(row),
                "detail_code": (
                    mapping_by_detail[row.name].detail_code
                    if row.name in mapping_by_detail
                    else ""
                ),
                "company_enabled": bool(
                    mapping_by_detail[row.name].enabled
                    if row.name in mapping_by_detail
                    else False
                ),
            }
            for row in details
        ],
    }


def save_group(company: str, payload: str | dict[str, Any]) -> dict[str, Any]:
    import frappe

    holding = _assert_manage(company)
    try:
        values = normalize_group_payload(payload)
    except (TypeError, ValueError, json.JSONDecodeError) as exc:
        frappe.throw(str(exc))
    if values["name"]:
        doc = frappe.get_doc("ASOUD Floating Detail Group", values["name"])
        if doc.holding != holding:
            frappe.throw("Group does not belong to the selected holding")
    else:
        doc = frappe.new_doc("ASOUD Floating Detail Group")
    before = doc.as_dict() if values["name"] else None
    doc.update({"holding": holding, **{k: v for k, v in values.items() if k != "name"}})
    doc.save()
    from asoud_core.services.audit import append_event

    append_event(
        "floating_detail_group.saved",
        company=company,
        resource_doctype=doc.doctype,
        resource_name=doc.name,
        before=before,
        after=doc.as_dict(),
    )
    return snapshot(company)


def save_detail(company: str, payload: str | dict[str, Any]) -> dict[str, Any]:
    import frappe

    holding = _assert_manage(company)
    try:
        values = normalize_detail_payload(payload)
    except (TypeError, ValueError, json.JSONDecodeError) as exc:
        frappe.throw(str(exc))
    group = frappe.db.get_value(
        "ASOUD Floating Detail Group",
        values["detail_group"],
        ["holding", "detail_type", "enabled"],
        as_dict=True,
    )
    if not group or not group.enabled or group.holding != holding:
        frappe.throw("Floating detail group is not active in the selected holding")
    if values["name"]:
        doc = frappe.get_doc("ASOUD Floating Detail", values["name"])
        if doc.holding != holding:
            frappe.throw("Floating detail does not belong to the selected holding")
    else:
        doc = frappe.new_doc("ASOUD Floating Detail")
    before = doc.as_dict() if values["name"] else None
    doc.update(
        {
            "detail_title": values["detail_title"],
            "holding": holding,
            "detail_type": group.detail_type,
            "detail_group": values["detail_group"],
            "reference_doctype": values["reference_doctype"],
            "reference_name": values["reference_name"],
            "enabled": int(values["enabled"]),
        }
    )
    company_row = next(
        (row for row in doc.company_codes if row.company == company),
        None,
    )
    if company_row is None:
        company_row = doc.append("company_codes", {"company": company})
    company_row.detail_code = values["detail_code"]
    company_row.enabled = int(values["company_enabled"])
    doc.save()
    from asoud_core.services.audit import append_event

    append_event(
        "floating_detail.saved",
        company=company,
        resource_doctype=doc.doctype,
        resource_name=doc.name,
        before=before,
        after=doc.as_dict(),
    )
    return snapshot(company)


def ensure_groups_for_existing_details() -> None:
    import frappe

    rows = [
        row
        for row in frappe.get_all(
            "ASOUD Floating Detail",
            fields=["name", "holding", "detail_type", "detail_group"],
        )
        if not row.detail_group
    ]
    for row in rows:
        code = f"AUTO-{row.detail_type.upper().replace(' ', '-')}"
        group_name = frappe.db.exists(
            "ASOUD Floating Detail Group",
            {"holding": row.holding, "group_code": code},
        )
        if not group_name:
            group_name = frappe.get_doc(
                {
                    "doctype": "ASOUD Floating Detail Group",
                    "group_title": f"{row.detail_type} عمومی",
                    "group_code": code,
                    "holding": row.holding,
                    "detail_type": row.detail_type,
                    "enabled": 1,
                }
            ).insert(ignore_permissions=True).name
        frappe.db.set_value(
            "ASOUD Floating Detail",
            row.name,
            "detail_group",
            group_name,
            update_modified=False,
        )
