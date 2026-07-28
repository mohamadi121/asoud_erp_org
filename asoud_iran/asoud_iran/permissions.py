from __future__ import annotations


def _is_privileged(user: str) -> bool:
    import frappe

    return user == "Administrator" or "System Manager" in frappe.get_roles(user)


def floating_detail_query(user: str | None = None) -> str:
    import frappe

    user = user or frappe.session.user
    if _is_privileged(user):
        return ""
    escaped = frappe.db.escape(user)
    direct = (
        "exists (select 1 from `tabASOUD Floating Detail Company` fdc "
        "join `tabASOUD User Access` ua on ua.`company`=fdc.`company` "
        "where fdc.`parent`=`tabASOUD Floating Detail`.`name` "
        f"and fdc.`enabled`=1 and ua.`user`={escaped} and ua.`enabled`=1)"
    )
    holding = (
        "exists (select 1 from `tabASOUD User Access` hua "
        "join `tabCompany` hc on hc.`name`=hua.`company` "
        f"where hua.`user`={escaped} and hua.`enabled`=1 "
        "and hua.`holding_manager`=1 "
        "and hc.`asoud_holding`=`tabASOUD Floating Detail`.`holding`)"
    )
    return f"({direct} or {holding})"


def floating_detail_permission(
    doc,
    user: str | None = None,
    permission_type: str | None = None,
) -> bool | None:
    import frappe

    user = user or frappe.session.user
    if _is_privileged(user):
        return None
    allowed = frappe.db.sql(
        """
        SELECT fdc.name
          FROM `tabASOUD Floating Detail Company` fdc
          JOIN `tabASOUD User Access` ua ON ua.company=fdc.company
         WHERE fdc.parent=%s AND fdc.enabled=1
           AND ua.user=%s AND ua.enabled=1
         LIMIT 1
        """,
        (doc.name, user),
    )
    if allowed:
        return None
    holding_manager = frappe.db.sql(
        """
        SELECT ua.name
          FROM `tabASOUD User Access` ua
          JOIN `tabCompany` company ON company.name=ua.company
         WHERE ua.user=%s AND ua.enabled=1 AND ua.holding_manager=1
           AND company.asoud_holding=%s
         LIMIT 1
        """,
        (user, doc.holding),
    )
    return None if holding_manager else False


def account_detail_rule_query(user: str | None = None) -> str:
    from asoud_core.permissions import company_profile_query

    return company_profile_query("ASOUD Account Detail Rule", user)


def account_detail_rule_permission(
    doc,
    user: str | None = None,
    permission_type: str | None = None,
) -> bool | None:
    from asoud_core.permissions import company_profile_permission

    return company_profile_permission(doc, user, permission_type)


def opening_import_query(user: str | None = None) -> str:
    from asoud_core.permissions import treasury_document_query

    return treasury_document_query("ASOUD Opening Balance Import", user)


def opening_import_permission(
    doc,
    user: str | None = None,
    permission_type: str | None = None,
) -> bool | None:
    from asoud_core.permissions import treasury_document_permission

    return treasury_document_permission(doc, user, permission_type)


def tax_document_query(doctype: str, user: str | None = None) -> str:
    from asoud_core.permissions import treasury_document_query

    return treasury_document_query(doctype, user)


def tax_settings_query(user: str | None = None) -> str:
    return tax_document_query("ASOUD Tax Settings", user)


def tax_submission_query(user: str | None = None) -> str:
    return tax_document_query("ASOUD Tax Submission", user)


def tax_event_query(user: str | None = None) -> str:
    return tax_document_query("ASOUD Tax Event", user)


def tax_document_permission(
    doc,
    user: str | None = None,
    permission_type: str | None = None,
) -> bool | None:
    from asoud_core.permissions import treasury_document_permission

    return treasury_document_permission(doc, user, permission_type)
