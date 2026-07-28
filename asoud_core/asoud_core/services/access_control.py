from __future__ import annotations

from typing import Any


def _assert_admin(company: str) -> None:
    import frappe

    roles = set(frappe.get_roles(frappe.session.user))
    if not ({"System Manager", "Accounts Manager"} & roles):
        frappe.throw("Access administration requires an authorized manager", frappe.PermissionError)
    from asoud_core.permissions import can_access_context

    if not can_access_context(frappe.session.user, company, None):
        frappe.throw("Not permitted", frappe.PermissionError)


def overview(company: str, branch: str | None = None) -> dict[str, Any]:
    import frappe

    branch = branch or None
    _assert_admin(company)
    filters: dict[str, Any] = {"company": company}
    if branch:
        filters["branch"] = ["in", ["", branch]]
    grants = frappe.get_all(
        "ASOUD User Access",
        filters=filters,
        fields=["name", "user", "company", "branch", "holding_manager", "enabled"],
        order_by="user, branch",
        limit_page_length=0,
    )
    user_names = sorted({row.user for row in grants})
    users = (
        {
            row.name: row
            for row in frappe.get_all(
                "User",
                filters={"name": ["in", user_names]},
                fields=["name", "full_name", "enabled", "user_type"],
                limit_page_length=0,
            )
        }
        if user_names
        else {}
    )
    roles_by_user: dict[str, list[str]] = {}
    role_rows = (
        frappe.get_all(
            "Has Role",
            filters={
                "parenttype": "User",
                "parent": ["in", sorted(users)],
            },
            fields=["parent", "role"],
            order_by="role",
            limit_page_length=0,
        )
        if users
        else []
    )
    for row in role_rows:
        roles_by_user.setdefault(row.parent, []).append(row.role)
    return {
        "company": company,
        "branch": branch,
        "users": [
            {
                **dict(grant),
                "full_name": users.get(grant.user).full_name
                if users.get(grant.user)
                else grant.user,
                "user_enabled": bool(users.get(grant.user).enabled)
                if users.get(grant.user)
                else False,
                "user_type": users.get(grant.user).user_type
                if users.get(grant.user)
                else None,
                "roles": roles_by_user.get(grant.user, []),
            }
            for grant in grants
        ],
    }


def set_grant(
    user: str,
    company: str,
    branch: str | None,
    enabled: bool,
    holding_manager: bool,
) -> dict[str, Any]:
    import frappe

    branch = branch or None
    _assert_admin(company)
    if not frappe.db.exists("User", user):
        frappe.throw("User does not exist")
    if branch:
        branch_company = frappe.db.get_value("ASOUD Branch", branch, "company")
        if not branch_company or branch_company != company:
            frappe.throw("Branch must belong to the selected company")
    existing = frappe.get_all(
        "ASOUD User Access",
        filters={"user": user, "company": company},
        fields=["name", "branch"],
        limit_page_length=0,
    )
    name = next(
        (
            row.name
            for row in existing
            if (row.branch or None) == branch
        ),
        None,
    )
    before = None
    values = {
        "user": user,
        "company": company,
        "branch": branch,
        "enabled": int(bool(enabled)),
        "holding_manager": int(bool(holding_manager)),
    }
    if name:
        before = frappe.db.get_value(
            "ASOUD User Access",
            name,
            ["enabled", "holding_manager"],
            as_dict=True,
        )
        frappe.db.set_value("ASOUD User Access", name, values)
    else:
        name = frappe.get_doc(
            {"doctype": "ASOUD User Access", **values}
        ).insert(ignore_permissions=True).name
    from asoud_core.services.user_permissions import sync_user_permissions

    sync_user_permissions(user)
    from asoud_core.services.audit import append_event

    append_event(
        "access.grant.updated",
        resource_doctype="ASOUD User Access",
        resource_name=name,
        company=company,
        branch=branch,
        before=dict(before) if before else None,
        after=values,
    )
    return {"name": name, **values}
