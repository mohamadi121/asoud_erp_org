from __future__ import annotations

import json
from typing import Any

from asoud_core.services.approval import SUPPORTED_SOURCE_DOCTYPES


MANAGER_ROLES = {"System Manager", "Accounts Manager", "ASOUD HR Manager"}


def _as_bool(value: Any, default: bool = False) -> bool:
    if value is None:
        return default
    if isinstance(value, str):
        return value.strip().lower() in {"1", "true", "yes", "on"}
    return bool(value)


def _normalize_payload(payload: str | dict[str, Any]) -> dict[str, Any]:
    values = json.loads(payload) if isinstance(payload, str) else dict(payload)
    stages = values.get("stages")
    if not isinstance(stages, list) or not stages:
        raise ValueError("Approval policy requires at least one stage")
    normalized: list[dict[str, Any]] = []
    for index, raw in enumerate(stages, start=1):
        if not isinstance(raw, dict):
            raise ValueError("Every approval stage must be an object")
        approver_type = str(raw.get("approver_type") or "").strip()
        if approver_type not in {"User", "Role", "Manager"}:
            raise ValueError("Approver type must be User, Role or Manager")
        user = str(raw.get("user") or "").strip()
        role = str(raw.get("role") or "").strip()
        sequence = int(raw.get("sequence") or index)
        if sequence < 1:
            raise ValueError("Approval stage sequence must be positive")
        if approver_type == "User" and not user:
            raise ValueError("A user approver is required")
        if approver_type == "Role" and not role:
            raise ValueError("An approver role is required")
        normalized.append(
            {
                "sequence": sequence,
                "stage_title": str(raw.get("stage_title") or "").strip()
                or f"Stage {index}",
                "approver_type": approver_type,
                "user": user if approver_type == "User" else None,
                "role": role if approver_type == "Role" else None,
                "due_hours": max(0, int(raw.get("due_hours") or 0)),
            }
        )
    sequences = sorted({row["sequence"] for row in normalized})
    if sequences != list(range(1, max(sequences) + 1)):
        raise ValueError("Approval sequences must be contiguous and start at one")
    normalized.sort(key=lambda row: (row["sequence"], row["stage_title"]))
    values["stages"] = normalized
    return values


def _assert_manager(company: str) -> None:
    import frappe

    if not MANAGER_ROLES.intersection(frappe.get_roles(frappe.session.user)):
        frappe.throw("Approval settings require an authorized manager", frappe.PermissionError)
    from asoud_core.permissions import can_access_context

    if not can_access_context(frappe.session.user, company, None):
        frappe.throw("Not permitted", frappe.PermissionError)


def _policy_dict(doc) -> dict[str, Any]:
    return {
        "name": doc.name,
        "policy_title": doc.policy_title,
        "enabled": bool(doc.enabled),
        "document_type": doc.document_type,
        "company": doc.company,
        "branch": doc.branch,
        "effective_from": str(doc.effective_from or ""),
        "effective_to": str(doc.effective_to or ""),
        "minimum_amount": float(doc.minimum_amount or 0),
        "maximum_amount": float(doc.maximum_amount or 0),
        "priority": int(doc.priority or 0),
        "policy_version": int(doc.policy_version or 1),
        "allow_self_approval": bool(doc.allow_self_approval),
        "parallel_mode": doc.parallel_mode or "All",
        "stages": [
            {
                "sequence": int(row.sequence or 0),
                "stage_title": row.stage_title,
                "approver_type": row.approver_type,
                "user": row.user,
                "role": row.role,
                "due_hours": int(row.due_hours or 0),
            }
            for row in doc.stages
        ],
    }


def workspace(company: str, branch: str | None = None) -> dict[str, Any]:
    import frappe

    branch = branch or None
    _assert_manager(company)
    if branch:
        branch_company = frappe.db.get_value("ASOUD Branch", branch, "company")
        if branch_company != company:
            frappe.throw("Branch must belong to the selected company")
    policies = frappe.get_all(
        "ASOUD Approval Policy",
        filters={"company": company},
        fields=["name", "branch"],
        order_by="priority desc, policy_title",
        limit_page_length=0,
    )
    policy_names = [
        row.name for row in policies if not branch or not row.branch or row.branch == branch
    ]
    access_rows = frappe.get_all(
        "ASOUD User Access",
        filters={"company": company, "enabled": 1},
        fields=["user", "branch"],
        limit_page_length=0,
    )
    allowed_users = sorted(
        {
            row.user
            for row in access_rows
            if not branch or not row.branch or row.branch == branch
        }
    )
    users = (
        frappe.get_all(
            "User",
            filters={"name": ["in", allowed_users], "enabled": 1},
            fields=["name", "full_name"],
            order_by="full_name",
            limit_page_length=0,
        )
        if allowed_users
        else []
    )
    return {
        "company": company,
        "branch": branch,
        "policies": [
            _policy_dict(frappe.get_doc("ASOUD Approval Policy", name))
            for name in policy_names
        ],
        "document_types": sorted(SUPPORTED_SOURCE_DOCTYPES),
        "branches": frappe.get_all(
            "ASOUD Branch",
            filters={"company": company, "enabled": 1},
            fields=["name", "branch_name"],
            order_by="branch_name",
            limit_page_length=0,
        ),
        "users": users,
        "roles": frappe.get_all(
            "Role",
            filters={"disabled": 0},
            pluck="name",
            order_by="name",
            limit_page_length=0,
        ),
    }


def save(company: str, payload: str | dict[str, Any]) -> dict[str, Any]:
    import frappe

    _assert_manager(company)
    try:
        values = _normalize_payload(payload)
    except (TypeError, ValueError, json.JSONDecodeError) as exc:
        frappe.throw(str(exc))
    name = str(values.get("name") or "").strip()
    if name:
        doc = frappe.get_doc("ASOUD Approval Policy", name)
        if doc.company != company:
            frappe.throw("Approval policy belongs to another company", frappe.PermissionError)
        before = _policy_dict(doc)
        version = int(doc.policy_version or 1) + 1
    else:
        doc = frappe.new_doc("ASOUD Approval Policy")
        before = None
        version = 1
    branch = str(values.get("branch") or "").strip() or None
    if branch and frappe.db.get_value("ASOUD Branch", branch, "company") != company:
        frappe.throw("Branch must belong to the selected company")
    document_type = str(values.get("document_type") or "").strip()
    if document_type not in SUPPORTED_SOURCE_DOCTYPES:
        frappe.throw("Unsupported approval document type")
    for stage in values["stages"]:
        if stage["user"] and not frappe.db.exists("User", stage["user"]):
            frappe.throw(f"Approver user does not exist: {stage['user']}")
        if stage["role"] and not frappe.db.exists("Role", stage["role"]):
            frappe.throw(f"Approver role does not exist: {stage['role']}")
    doc.update(
        {
            "policy_title": str(values.get("policy_title") or "").strip(),
            "enabled": int(_as_bool(values.get("enabled"), True)),
            "document_type": document_type,
            "company": company,
            "branch": branch,
            "effective_from": values.get("effective_from") or None,
            "effective_to": values.get("effective_to") or None,
            "minimum_amount": values.get("minimum_amount") or 0,
            "maximum_amount": values.get("maximum_amount") or 0,
            "priority": int(values.get("priority") or 0),
            "policy_version": version,
            "allow_self_approval": int(_as_bool(values.get("allow_self_approval"))),
            "parallel_mode": values.get("parallel_mode") or "All",
            "stages": values["stages"],
        }
    )
    doc.save()
    result = _policy_dict(doc)
    from asoud_core.services.audit import append_event

    append_event(
        "approval.policy.saved",
        resource_doctype="ASOUD Approval Policy",
        resource_name=doc.name,
        company=company,
        branch=branch,
        before=before,
        after=result,
    )
    return result
