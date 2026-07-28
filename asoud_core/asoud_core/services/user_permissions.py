from __future__ import annotations


def _desired_companies(user: str) -> set[str]:
    import frappe

    grants = frappe.get_all(
        "ASOUD User Access",
        filters={"user": user, "enabled": 1},
        fields=["company", "holding_manager"],
    )
    desired = {row.company for row in grants}
    manager_companies = [row.company for row in grants if row.holding_manager]
    if manager_companies:
        holdings = {
            value
            for value in frappe.get_all(
                "Company",
                filters={"name": ["in", manager_companies]},
                pluck="asoud_holding",
            )
            if value
        }
        if holdings:
            desired.update(
                frappe.get_all(
                    "Company",
                    filters={"asoud_holding": ["in", list(holdings)], "is_group": 0},
                    pluck="name",
                )
            )
    return desired


def sync_user_permissions(user: str) -> None:
    import frappe

    if not frappe.db.has_column("User Permission", "asoud_managed"):
        return

    desired = _desired_companies(user)
    managed = {
        row.for_value: row.name
        for row in frappe.get_all(
            "User Permission",
            filters={"user": user, "allow": "Company", "asoud_managed": 1},
            fields=["name", "for_value"],
        )
    }
    existing = set(
        frappe.get_all(
            "User Permission",
            filters={"user": user, "allow": "Company"},
            pluck="for_value",
        )
    )
    for company, name in managed.items():
        if company not in desired:
            frappe.delete_doc("User Permission", name, ignore_permissions=True)
    for company in sorted(desired - existing):
        frappe.get_doc(
            {
                "doctype": "User Permission",
                "user": user,
                "allow": "Company",
                "for_value": company,
                "apply_to_all_doctypes": 1,
                "asoud_managed": 1,
            }
        ).insert(ignore_permissions=True)


def sync_holding_managers(doc, method: str | None = None) -> None:
    import frappe

    if not frappe.db.table_exists("ASOUD User Access"):
        return
    users = frappe.get_all(
        "ASOUD User Access",
        filters={"holding_manager": 1, "enabled": 1},
        pluck="user",
    )
    for user in set(users):
        sync_user_permissions(user)
