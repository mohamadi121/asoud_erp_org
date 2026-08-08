from __future__ import annotations


def _is_privileged(user: str) -> bool:
    import frappe

    return user == "Administrator" or "System Manager" in frappe.get_roles(user)


def _holding_access_sql(user: str, company_expression: str) -> str:
    import frappe

    escaped = frappe.db.escape(user)
    return (
        "exists (select 1 from `tabASOUD User Access` hua "
        "join `tabCompany` source_company on source_company.`name`=hua.`company` "
        f"join `tabCompany` target_company on target_company.`name`={company_expression} "
        f"where hua.`user`={escaped} and hua.`enabled`=1 and hua.`holding_manager`=1 "
        "and ifnull(source_company.`asoud_holding`, '')<>'' "
        "and source_company.`asoud_holding`=target_company.`asoud_holding`)"
    )


def branch_query(user: str | None = None) -> str:
    import frappe

    user = user or frappe.session.user
    if _is_privileged(user):
        return ""
    escaped = frappe.db.escape(user)
    direct = (
        "exists (select 1 from `tabASOUD User Access` ua "
        f"where ua.`user`={escaped} and ua.`company`=`tabASOUD Branch`.`company` "
        "and ua.`enabled`=1 and "
        "(ifnull(ua.`branch`, '')='' or ua.`branch`=`tabASOUD Branch`.`name`))"
    )
    holding = _holding_access_sql(user, "`tabASOUD Branch`.`company`")
    return f"({direct} or {holding})"


def branch_permission(
    doc,
    user: str | None = None,
    permission_type: str | None = None,
) -> bool | None:
    import frappe

    user = user or frappe.session.user
    if _is_privileged(user):
        return None
    return None if can_access_context(user, doc.company, doc.name) else False


def user_access_query(user: str | None = None) -> str:
    import frappe

    user = user or frappe.session.user
    return "" if _is_privileged(user) else f"`tabASOUD User Access`.`user`={frappe.db.escape(user)}"


def user_access_permission(
    doc,
    user: str | None = None,
    permission_type: str | None = None,
) -> bool | None:
    import frappe

    user = user or frappe.session.user
    return None if _is_privileged(user) or doc.user == user else False


def can_access_context(user: str, company: str, branch: str | None = None) -> bool:
    import frappe

    if _is_privileged(user):
        return True
    branch_filter = (
        "(ifnull(ua.`branch`, '')='' or ua.`branch`=%s)"
        if branch
        else "ifnull(ua.`branch`, '')=''"
    )
    parameters: list[str] = [user, company]
    if branch:
        parameters.append(branch)
    direct = frappe.db.sql(
        f"""
        select ua.name
          from `tabASOUD User Access` ua
         where ua.user=%s and ua.company=%s and ua.enabled=1
           and {branch_filter}
         limit 1
        """,
        tuple(parameters),
    )
    if direct:
        return True
    target_holding = frappe.db.get_value("Company", company, "asoud_holding")
    if not target_holding:
        return False
    return bool(
        frappe.db.sql(
            """
            select ua.name
              from `tabASOUD User Access` ua
              join `tabCompany` c on c.name=ua.company
             where ua.user=%s and ua.enabled=1 and ua.holding_manager=1
               and c.asoud_holding=%s
             limit 1
            """,
            (user, target_holding),
        )
    )


def can_access_company(user: str, company: str) -> bool:
    import frappe

    if _is_privileged(user):
        return True
    if frappe.db.exists(
        "ASOUD User Access", {"user": user, "company": company, "enabled": 1}
    ):
        return True
    target_holding = frappe.db.get_value("Company", company, "asoud_holding")
    if not target_holding:
        return False
    return bool(
        frappe.db.sql(
            """
            select ua.name
              from `tabASOUD User Access` ua
              join `tabCompany` c on c.name=ua.company
             where ua.user=%s and ua.enabled=1 and ua.holding_manager=1
               and c.asoud_holding=%s
             limit 1
            """,
            (user, target_holding),
        )
    )


def can_manage_holding(user: str, holding: str) -> bool:
    import frappe

    if _is_privileged(user):
        return True
    return bool(
        frappe.db.sql(
            """
            select ua.name
              from `tabASOUD User Access` ua
              join `tabCompany` c on c.name=ua.company
             where ua.user=%s and ua.enabled=1 and ua.holding_manager=1
               and c.asoud_holding=%s
             limit 1
            """,
            (user, holding),
        )
    )


def standard_document_query(doctype: str, user: str | None = None) -> str:
    import frappe

    user = user or frappe.session.user
    if _is_privileged(user):
        return ""
    escaped = frappe.db.escape(user)
    table = f"`tab{doctype}`"
    direct = (
        "exists (select 1 from `tabASOUD User Access` ua "
        f"where ua.`user`={escaped} and ua.`company`={table}.`company` and ua.`enabled`=1 "
        f"and (ifnull(ua.`branch`, '')='' or ua.`branch`={table}.`asoud_branch`))"
    )
    holding = _holding_access_sql(user, f"{table}.`company`")
    return f"({direct} or {holding})"


def standard_document_permission(
    doc,
    user: str | None = None,
    permission_type: str | None = None,
) -> bool | None:
    import frappe

    user = user or frappe.session.user
    return None if can_access_context(user, doc.company, doc.get("asoud_branch")) else False


def company_profile_permission(
    doc,
    user: str | None = None,
    permission_type: str | None = None,
) -> bool | None:
    import frappe

    user = user or frappe.session.user
    return None if can_access_company(user, doc.company) else False


def shared_master_query(doctype: str, user: str | None = None) -> str:
    import frappe

    user = user or frappe.session.user
    if _is_privileged(user):
        return ""
    escaped = frappe.db.escape(user)
    table = f"`tab{doctype}`"
    return (
        "exists (select 1 from `tabASOUD User Access` ua "
        "join `tabCompany` c on c.`name`=ua.`company` "
        f"where ua.`user`={escaped} and ua.`enabled`=1 "
        f"and c.`asoud_holding`={table}.`asoud_holding`)"
    )


def shared_master_permission(
    doc,
    user: str | None = None,
    permission_type: str | None = None,
) -> bool | None:
    import frappe

    user = user or frappe.session.user
    if _is_privileged(user):
        return None
    holding = doc.get("asoud_holding")
    if not holding:
        return False
    allowed = frappe.db.sql(
        """
        select ua.name
          from `tabASOUD User Access` ua
          join `tabCompany` c on c.name=ua.company
         where ua.user=%s and ua.enabled=1 and c.asoud_holding=%s
         limit 1
        """,
        (user, holding),
    )
    return None if allowed else False


def customer_query(user: str | None = None) -> str:
    return shared_master_query("Customer", user)


def supplier_query(user: str | None = None) -> str:
    return shared_master_query("Supplier", user)


def item_query(user: str | None = None) -> str:
    return shared_master_query("Item", user)


def journal_entry_query(user: str | None = None) -> str:
    return standard_document_query("Journal Entry", user)


def sales_invoice_query(user: str | None = None) -> str:
    return standard_document_query("Sales Invoice", user)


def purchase_invoice_query(user: str | None = None) -> str:
    return standard_document_query("Purchase Invoice", user)


def payment_entry_query(user: str | None = None) -> str:
    return standard_document_query("Payment Entry", user)


def stock_entry_query(user: str | None = None) -> str:
    return standard_document_query("Stock Entry", user)


def delivery_note_query(user: str | None = None) -> str:
    return standard_document_query("Delivery Note", user)


def purchase_receipt_query(user: str | None = None) -> str:
    return standard_document_query("Purchase Receipt", user)


def stock_reconciliation_query(user: str | None = None) -> str:
    return standard_document_query("Stock Reconciliation", user)


def sales_order_query(user: str | None = None) -> str:
    return standard_document_query("Sales Order", user)


def purchase_order_query(user: str | None = None) -> str:
    return standard_document_query("Purchase Order", user)


def quotation_query(user: str | None = None) -> str:
    return standard_document_query("Quotation", user)


def material_request_query(user: str | None = None) -> str:
    return standard_document_query("Material Request", user)


def party_profile_query(user: str | None = None) -> str:
    return company_profile_query("ASOUD Party Company Profile", user)


def item_profile_query(user: str | None = None) -> str:
    return company_profile_query("ASOUD Item Company Profile", user)


def fiscal_period_query(user: str | None = None) -> str:
    return company_profile_query("ASOUD Fiscal Period", user)


def period_lock_query(user: str | None = None) -> str:
    return company_profile_query("ASOUD Period Lock", user)


def party_identity_query(user: str | None = None) -> str:
    return company_profile_query("ASOUD Party Identity", user)


def party_code_series_query(user: str | None = None) -> str:
    return company_profile_query("ASOUD Party Code Series", user)


def company_profile_query(doctype: str, user: str | None = None) -> str:
    import frappe

    user = user or frappe.session.user
    if _is_privileged(user):
        return ""
    table = f"`tab{doctype}`"
    escaped = frappe.db.escape(user)
    direct = (
        "exists (select 1 from `tabASOUD User Access` ua "
        f"where ua.`user`={escaped} and ua.`company`={table}.`company` and ua.`enabled`=1)"
    )
    holding = _holding_access_sql(user, f"{table}.`company`")
    return f"({direct} or {holding})"


def treasury_document_query(doctype: str, user: str | None = None) -> str:
    import frappe

    user = user or frappe.session.user
    if _is_privileged(user):
        return ""
    escaped = frappe.db.escape(user)
    table = f"`tab{doctype}`"
    direct = (
        "exists (select 1 from `tabASOUD User Access` ua "
        f"where ua.`user`={escaped} and ua.`company`={table}.`company` "
        "and ua.`enabled`=1 and "
        f"(ifnull(ua.`branch`, '')='' or ua.`branch`={table}.`branch`))"
    )
    holding = _holding_access_sql(user, f"{table}.`company`")
    return f"({direct} or {holding})"


def treasury_document_permission(
    doc,
    user: str | None = None,
    permission_type: str | None = None,
) -> bool | None:
    import frappe

    user = user or frappe.session.user
    return None if can_access_context(user, doc.company, doc.get("branch")) else False


def treasury_account_query(user: str | None = None) -> str:
    return treasury_document_query("ASOUD Treasury Account", user)


def treasury_transaction_query(user: str | None = None) -> str:
    return treasury_document_query("ASOUD Treasury Transaction", user)


def petty_cash_claim_query(user: str | None = None) -> str:
    return treasury_document_query("ASOUD Petty Cash Claim", user)


def cheque_query(user: str | None = None) -> str:
    return treasury_document_query("ASOUD Cheque", user)


def cheque_event_query(user: str | None = None) -> str:
    return treasury_document_query("ASOUD Cheque Event", user)


def cash_count_query(user: str | None = None) -> str:
    return treasury_document_query("ASOUD Cash Count", user)


def bank_reconciliation_query(user: str | None = None) -> str:
    return treasury_document_query("ASOUD Bank Reconciliation", user)


def bank_connection_query(user: str | None = None) -> str:
    return treasury_document_query("ASOUD Bank Connection", user)


def bank_statement_import_query(user: str | None = None) -> str:
    return treasury_document_query("ASOUD Bank Statement Import", user)


def bank_statement_line_query(user: str | None = None) -> str:
    return treasury_document_query("ASOUD Bank Statement Line", user)


def sayad_operation_query(user: str | None = None) -> str:
    return treasury_document_query("ASOUD Sayad Operation", user)


def sayad_event_query(user: str | None = None) -> str:
    return treasury_document_query("ASOUD Sayad Event", user)


def intercompany_transfer_query(user: str | None = None) -> str:
    import frappe

    user = user or frappe.session.user
    if _is_privileged(user):
        return ""
    escaped = frappe.db.escape(user)
    table = "`tabASOUD Intercompany Transfer`"
    source = (
        "exists (select 1 from `tabASOUD User Access` ua "
        f"where ua.user={escaped} and ua.enabled=1 and ua.company={table}.source_company "
        f"and (ifnull(ua.branch, '')='' or ua.branch={table}.source_branch))"
    )
    destination = (
        "exists (select 1 from `tabASOUD User Access` ua "
        f"where ua.user={escaped} and ua.enabled=1 and ua.company={table}.destination_company "
        f"and (ifnull(ua.branch, '')='' or ua.branch={table}.destination_branch))"
    )
    holding = (
        "exists (select 1 from `tabASOUD User Access` ua "
        "join `tabCompany` c on c.name=ua.company "
        f"where ua.user={escaped} and ua.enabled=1 and ua.holding_manager=1 "
        f"and c.asoud_holding={table}.holding)"
    )
    return f"({source} or {destination} or {holding})"


def intercompany_transfer_permission(
    doc,
    user: str | None = None,
    permission_type: str | None = None,
) -> bool | None:
    import frappe

    user = user or frappe.session.user
    allowed = (
        can_manage_holding(user, doc.holding)
        or can_access_context(user, doc.source_company, doc.source_branch)
        or can_access_context(user, doc.destination_company, doc.destination_branch)
    )
    return None if allowed else False


def consolidation_map_query(user: str | None = None) -> str:
    import frappe

    user = user or frappe.session.user
    if _is_privileged(user):
        return ""
    escaped = frappe.db.escape(user)
    return (
        "exists (select 1 from `tabASOUD User Access` ua "
        "join `tabCompany` c on c.name=ua.company "
        f"where ua.user={escaped} and ua.enabled=1 and ua.holding_manager=1 "
        "and c.asoud_holding=`tabASOUD Consolidation Account Map`.holding)"
    )


def consolidation_adjustment_query(user: str | None = None) -> str:
    return consolidation_map_query(user).replace(
        "`tabASOUD Consolidation Account Map`",
        "`tabASOUD Consolidation Adjustment`",
    )


def fx_policy_query(user: str | None = None) -> str:
    return consolidation_map_query(user).replace(
        "`tabASOUD Consolidation Account Map`", "`tabASOUD FX Policy`"
    )


def fx_rate_query(user: str | None = None) -> str:
    return consolidation_map_query(user).replace(
        "`tabASOUD Consolidation Account Map`", "`tabASOUD FX Rate`"
    )


def holding_document_permission(
    doc,
    user: str | None = None,
    permission_type: str | None = None,
) -> bool | None:
    import frappe

    user = user or frappe.session.user
    return None if can_manage_holding(user, doc.holding) else False


def migration_run_query(user: str | None = None) -> str:
    return company_profile_query("ASOUD Migration Run", user)


def cutover_run_query(user: str | None = None) -> str:
    return company_profile_query("ASOUD Cutover Run", user)


def company_control_document_permission(
    doc,
    user: str | None = None,
    permission_type: str | None = None,
) -> bool | None:
    import frappe

    user = user or frappe.session.user
    return None if can_access_context(user, doc.company, None) else False


def audit_event_query(user: str | None = None) -> str:
    import frappe

    user = user or frappe.session.user
    if _is_privileged(user):
        return ""
    escaped = frappe.db.escape(user)
    table = "`tabASOUD Audit Event`"
    return (
        f"{table}.company is not null and exists ("
        "select 1 from `tabASOUD User Access` ua "
        f"where ua.user={escaped} and ua.enabled=1 and ua.company={table}.company)"
    )


def audit_event_permission(
    doc,
    user: str | None = None,
    permission_type: str | None = None,
) -> bool | None:
    import frappe

    user = user or frappe.session.user
    if _is_privileged(user):
        return None
    return None if doc.company and can_access_context(user, doc.company, doc.branch) else False


def approval_policy_query(user: str | None = None) -> str:
    return company_profile_query("ASOUD Approval Policy", user)


def approval_request_query(user: str | None = None) -> str:
    return treasury_document_query("ASOUD Approval Request", user)


def approval_action_query(user: str | None = None) -> str:
    import frappe

    user = user or frappe.session.user
    if _is_privileged(user):
        return ""
    escaped = frappe.db.escape(user)
    table = "`tabASOUD Approval Action`"
    return (
        "exists (select 1 from `tabASOUD Approval Request` ar "
        "join `tabASOUD User Access` ua on ua.company=ar.company "
        f"where ar.name={table}.approval_request and ua.user={escaped} "
        "and ua.enabled=1 and "
        "(ifnull(ua.branch, '')='' or ua.branch=ar.branch))"
    )


def approval_delegation_query(user: str | None = None) -> str:
    import frappe

    user = user or frappe.session.user
    if _is_privileged(user):
        return ""
    escaped = frappe.db.escape(user)
    return (
        f"(`tabASOUD Approval Delegation`.principal_user={escaped} "
        f"or `tabASOUD Approval Delegation`.delegate_user={escaped})"
    )


def access_schedule_query(user: str | None = None) -> str:
    import frappe

    user = user or frappe.session.user
    return (
        ""
        if _is_privileged(user)
        else f"`tabASOUD User Access Schedule`.user={frappe.db.escape(user)}"
    )


def approval_document_permission(
    doc,
    user: str | None = None,
    permission_type: str | None = None,
) -> bool | None:
    import frappe

    user = user or frappe.session.user
    company = doc.get("company")
    branch = doc.get("branch")
    if not company:
        return None if _is_privileged(user) else False
    return None if can_access_context(user, company, branch) else False


def approval_action_permission(
    doc,
    user: str | None = None,
    permission_type: str | None = None,
) -> bool | None:
    import frappe

    user = user or frappe.session.user
    request = frappe.db.get_value(
        "ASOUD Approval Request",
        doc.approval_request,
        ["company", "branch"],
        as_dict=True,
    )
    return (
        None
        if request and can_access_context(user, request.company, request.branch)
        else False
    )


def approval_delegation_permission(
    doc,
    user: str | None = None,
    permission_type: str | None = None,
) -> bool | None:
    import frappe

    user = user or frappe.session.user
    if _is_privileged(user):
        return None
    return None if user in {doc.principal_user, doc.delegate_user} else False


def access_schedule_permission(
    doc,
    user: str | None = None,
    permission_type: str | None = None,
) -> bool | None:
    import frappe

    user = user or frappe.session.user
    return None if _is_privileged(user) or user == doc.user else False
