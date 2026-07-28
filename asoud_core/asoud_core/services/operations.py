from __future__ import annotations

SALES_DOCTYPES = {"Quotation", "Sales Order", "Delivery Note", "Sales Invoice"}
PURCHASE_DOCTYPES = {"Purchase Order", "Purchase Receipt", "Purchase Invoice"}
STOCK_DOCTYPES = {"Stock Entry", "Stock Reconciliation"}


def validate_shared_master(doc, method: str | None = None) -> None:
    import frappe

    holding = doc.get("asoud_holding")
    if not holding:
        return
    if doc.doctype == "Item":
        kind = doc.get("asoud_item_kind") or "Goods"
        if kind == "Service" and doc.get("is_stock_item"):
            frappe.throw("A service item cannot be a stock item")
        if kind == "Goods" and not doc.get("is_stock_item"):
            frappe.throw("A goods item must be a stock item; use Item Kind Service otherwise")


def validate_warehouse(doc, method: str | None = None) -> None:
    import frappe

    branch = doc.get("asoud_branch")
    company = doc.get("company")
    if branch:
        branch_company = frappe.db.get_value("ASOUD Branch", branch, "company")
        if branch_company != company:
            frappe.throw("Warehouse branch must belong to the warehouse company")


def apply_operational_defaults(doc, method: str | None = None) -> None:
    import frappe

    company = doc.get("company")
    if not company:
        return
    party_type, party = _party(doc)
    if party:
        profile = _party_profile(party_type, party, company)
        if profile:
            if not doc.get("asoud_branch") and profile.default_branch:
                doc.asoud_branch = profile.default_branch
            if not doc.get("payment_terms_template") and profile.payment_terms_template:
                doc.payment_terms_template = profile.payment_terms_template
            price_field = "selling_price_list" if party_type == "Customer" else "buying_price_list"
            if profile.price_list and doc.meta.has_field(price_field) and not doc.get(price_field):
                doc.set(price_field, profile.price_list)

    branch = doc.get("asoud_branch")
    branch_warehouse = (
        frappe.db.get_value("ASOUD Branch", branch, "default_warehouse") if branch else None
    )
    for row in doc.get("items") or []:
        profile = _item_profile(row.get("item_code"), company)
        item_kind = (
            frappe.db.get_value("Item", row.get("item_code"), "asoud_item_kind")
            if row.get("item_code")
            else None
        )
        if item_kind == "Service":
            continue
        warehouse = (profile and profile.default_warehouse) or branch_warehouse
        if warehouse:
            if doc.doctype in {"Sales Order", "Delivery Note", "Sales Invoice"} and not row.get("warehouse"):
                row.warehouse = warehouse
            elif doc.doctype in {"Purchase Order", "Purchase Receipt", "Purchase Invoice"} and not row.get("warehouse"):
                row.warehouse = warehouse


def validate_operational_document(doc, method: str | None = None) -> None:
    import frappe

    company = doc.get("company")
    if not company:
        return
    party_type, party = _party(doc)
    if party:
        profile = _party_profile(party_type, party, company)
        if not profile or not profile.enabled:
            frappe.throw(f"{party_type} {party} is not enabled for company {company}")
        company_holding = frappe.db.get_value("Company", company, "asoud_holding")
        party_holding = frappe.db.get_value(party_type, party, "asoud_holding")
        if company_holding and party_holding != company_holding:
            frappe.throw(f"{party_type} {party} does not belong to the company holding")
        if doc.doctype == "Sales Invoice":
            _validate_credit_limit(doc, profile)

    branch = doc.get("asoud_branch")
    for row in doc.get("items") or []:
        item_code = row.get("item_code")
        if not item_code:
            continue
        profile = _item_profile(item_code, company)
        if not profile or not profile.enabled:
            frappe.throw(f"Item {item_code} is not enabled for company {company}")
        company_holding = frappe.db.get_value("Company", company, "asoud_holding")
        if company_holding and frappe.db.get_value("Item", item_code, "asoud_holding") != company_holding:
            frappe.throw(f"Item {item_code} does not belong to the company holding")
        for warehouse_field in ("warehouse", "s_warehouse", "t_warehouse"):
            effective_branch = branch
            if (
                doc.doctype == "Stock Entry"
                and doc.get("stock_entry_type") == "Material Transfer"
                and warehouse_field == "t_warehouse"
            ):
                effective_branch = None
            _validate_row_warehouse(row.get(warehouse_field), company, effective_branch)


def _party(doc) -> tuple[str | None, str | None]:
    if doc.doctype in SALES_DOCTYPES:
        if doc.doctype == "Quotation" and doc.get("quotation_to") != "Customer":
            return None, None
        return "Customer", doc.get("customer") or doc.get("party_name")
    if doc.doctype in PURCHASE_DOCTYPES:
        return "Supplier", doc.get("supplier")
    return None, None


def _party_profile(party_type: str | None, party: str | None, company: str):
    import frappe

    if not party_type or not party:
        return None
    return frappe.db.get_value(
        "ASOUD Party Company Profile",
        {"party_type": party_type, "party": party, "company": company},
        ["name", "enabled", "default_branch", "credit_limit", "payment_terms_template", "price_list", "default_account"],
        as_dict=True,
    )


def _item_profile(item: str | None, company: str):
    import frappe

    if not item:
        return None
    return frappe.db.get_value(
        "ASOUD Item Company Profile",
        {"item": item, "company": company},
        ["name", "enabled", "default_branch", "default_warehouse", "income_account", "expense_account"],
        as_dict=True,
    )


def _validate_row_warehouse(warehouse: str | None, company: str, branch: str | None) -> None:
    import frappe

    if not warehouse:
        return
    row = frappe.db.get_value(
        "Warehouse", warehouse, ["company", "asoud_branch", "is_group"], as_dict=True
    )
    if not row or row.is_group or row.company != company:
        frappe.throw(f"Warehouse {warehouse} is not a leaf warehouse of company {company}")
    if branch and row.asoud_branch != branch:
        frappe.throw(f"Warehouse {warehouse} is not assigned to branch {branch}")


def _validate_credit_limit(doc, profile) -> None:
    import frappe
    from frappe.utils import flt

    limit = flt(profile.credit_limit)
    if limit <= 0 or doc.get("is_return"):
        return
    outstanding = frappe.db.sql(
        """
        select coalesce(sum(outstanding_amount), 0)
          from `tabSales Invoice`
         where docstatus=1 and company=%s and customer=%s
           and outstanding_amount>0 and name<>%s
        """,
        (doc.company, doc.customer, doc.name or ""),
    )[0][0]
    exposure = flt(outstanding) + flt(doc.get("rounded_total") or doc.get("grand_total"))
    if exposure > limit:
        frappe.throw(
            f"Company credit limit exceeded for {doc.customer}: "
            f"exposure {exposure:g}, limit {limit:g}"
        )
