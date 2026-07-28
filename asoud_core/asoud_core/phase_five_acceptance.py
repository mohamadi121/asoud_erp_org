from __future__ import annotations

from asoud_core.phase_one_demo import COMPANY_A, HOLDING_CODE, ensure_phase_one_demo

POSTING_DATE = "2027-04-15"
CUSTOMER = "ASOUD Phase Five Customer"
SUPPLIER = "ASOUD Phase Five Supplier"
GOODS = "ASOUD-P5-GOODS"
SERVICE = "ASOUD-P5-SERVICE"


def _account(code: str) -> str:
    import frappe

    value = frappe.db.get_value(
        "Account", {"company": COMPANY_A, "account_number": code}, "name"
    )
    if not value:
        raise AssertionError(f"Required phase-five account {code} is missing")
    return value


def _ensure_warehouse(branch: str, label: str) -> str:
    import frappe

    existing = frappe.db.exists(
        "Warehouse", {"warehouse_name": label, "company": COMPANY_A}
    )
    if existing:
        warehouse = frappe.get_doc("Warehouse", existing)
    else:
        warehouse = frappe.get_doc(
            {
                "doctype": "Warehouse",
                "warehouse_name": label,
                "company": COMPANY_A,
                "is_group": 0,
                "asoud_branch": branch,
            }
        ).insert(ignore_permissions=True)
    if warehouse.asoud_branch != branch:
        warehouse.asoud_branch = branch
        warehouse.save(ignore_permissions=True)
    branch_doc = frappe.get_doc("ASOUD Branch", branch)
    if branch_doc.default_warehouse != warehouse.name:
        branch_doc.default_warehouse = warehouse.name
        branch_doc.save(ignore_permissions=True)
    return warehouse.name


def _ensure_party(doctype: str, name: str) -> str:
    import frappe

    if not frappe.db.exists("Customer Group", "ASOUD Phase Five Customers"):
        frappe.get_doc(
            {
                "doctype": "Customer Group",
                "customer_group_name": "ASOUD Phase Five Customers",
                "parent_customer_group": "All Customer Groups",
                "is_group": 0,
            }
        ).insert(ignore_permissions=True)
    if not frappe.db.exists("Supplier Group", "ASOUD Phase Five Suppliers"):
        frappe.get_doc(
            {
                "doctype": "Supplier Group",
                "supplier_group_name": "ASOUD Phase Five Suppliers",
                "parent_supplier_group": "All Supplier Groups",
                "is_group": 0,
            }
        ).insert(ignore_permissions=True)
    territory = frappe.db.get_value("Territory", {"is_group": 0}, "name")
    if not territory:
        territory = frappe.get_doc(
            {
                "doctype": "Territory",
                "territory_name": "ASOUD Phase Five Territory",
                "parent_territory": "All Territories",
                "is_group": 0,
            }
        ).insert(ignore_permissions=True).name
    if frappe.db.exists(doctype, name):
        doc = frappe.get_doc(doctype, name)
    elif doctype == "Customer":
        doc = frappe.get_doc(
            {
                "doctype": "Customer",
                "customer_name": name,
                "customer_type": "Company",
                "customer_group": "ASOUD Phase Five Customers",
                "territory": territory,
                "asoud_holding": HOLDING_CODE,
            }
        ).insert(ignore_permissions=True)
    else:
        doc = frappe.get_doc(
            {
                "doctype": "Supplier",
                "supplier_name": name,
                "supplier_group": "ASOUD Phase Five Suppliers",
                "supplier_type": "Company",
                "asoud_holding": HOLDING_CODE,
            }
        ).insert(ignore_permissions=True)
    if doc.asoud_holding != HOLDING_CODE:
        doc.asoud_holding = HOLDING_CODE
        doc.save(ignore_permissions=True)
    return doc.name


def _ensure_item_group() -> str:
    import frappe

    name = "ASOUD Phase Five"
    if not frappe.db.exists("Item Group", name):
        parent = frappe.db.get_value(
            "Item Group", {"is_group": 1}, "name", order_by="lft asc"
        )
        if not parent:
            parent = frappe.get_doc(
                {
                    "doctype": "Item Group",
                    "item_group_name": "ASOUD All Item Groups",
                    "is_group": 1,
                }
            ).insert(ignore_permissions=True).name
        frappe.get_doc(
            {
                "doctype": "Item Group",
                "item_group_name": name,
                "parent_item_group": parent,
                "is_group": 0,
            }
        ).insert(ignore_permissions=True)
    return name


def _ensure_item(
    code: str,
    name: str,
    kind: str,
    warehouse: str | None,
    income: str,
    expense: str,
) -> str:
    import frappe

    if not frappe.db.exists("UOM", "Nos"):
        frappe.get_doc({"doctype": "UOM", "uom_name": "Nos"}).insert(
            ignore_permissions=True
        )
    if frappe.db.exists("Item", code):
        item = frappe.get_doc("Item", code)
    else:
        item = frappe.get_doc(
            {
                "doctype": "Item",
                "item_code": code,
                "item_name": name,
                "item_group": _ensure_item_group(),
                "stock_uom": "Nos",
                "is_stock_item": 1 if kind == "Goods" else 0,
                "include_item_in_manufacturing": 0,
                "asoud_holding": HOLDING_CODE,
                "asoud_item_kind": kind,
                "item_defaults": [
                    {
                        "company": COMPANY_A,
                        "default_warehouse": warehouse,
                        "income_account": income,
                        "expense_account": expense,
                    }
                ],
            }
        ).insert(ignore_permissions=True)
    if item.asoud_holding != HOLDING_CODE or item.asoud_item_kind != kind:
        item.asoud_holding = HOLDING_CODE
        item.asoud_item_kind = kind
        item.is_stock_item = 1 if kind == "Goods" else 0
        item.save(ignore_permissions=True)
    return item.name


def _ensure_profiles(
    customer: str,
    supplier: str,
    goods: str,
    service: str,
    branch: str,
    warehouse: str,
) -> None:
    import frappe

    for price_list, selling, buying in (
        ("ASOUD Standard Selling", 1, 0),
        ("ASOUD Standard Buying", 0, 1),
    ):
        if not frappe.db.exists("Price List", price_list):
            frappe.get_doc(
                {
                    "doctype": "Price List",
                    "price_list_name": price_list,
                    "currency": "IRR",
                    "selling": selling,
                    "buying": buying,
                    "enabled": 1,
                }
            ).insert(ignore_permissions=True)
        frappe.db.set_value(
            "Price List", price_list, {"currency": "IRR", "enabled": 1}
        )
    frappe.db.set_single_value("Global Defaults", "default_currency", "IRR")
    frappe.db.set_single_value(
        "Selling Settings", "selling_price_list", "ASOUD Standard Selling"
    )
    frappe.db.set_single_value(
        "Buying Settings", "buying_price_list", "ASOUD Standard Buying"
    )
    ar, ap = _account("112001"), _account("211001")
    for party_type, party, account, credit in (
        ("Customer", customer, ar, 500_000),
        ("Supplier", supplier, ap, 0),
    ):
        key = f"{party_type}|{party}|{COMPANY_A}"
        if not frappe.db.exists("ASOUD Party Company Profile", key):
            frappe.get_doc(
                {
                    "doctype": "ASOUD Party Company Profile",
                    "party_type": party_type,
                    "party": party,
                    "company": COMPANY_A,
                    "enabled": 1,
                    "default_branch": branch,
                    "credit_limit": credit,
                    "price_list": (
                        "ASOUD Standard Selling"
                        if party_type == "Customer"
                        else "ASOUD Standard Buying"
                    ),
                    "default_account": account,
                }
            ).insert(ignore_permissions=True)
    for item, default_warehouse, income, expense in (
        (goods, warehouse, _account("410001"), _account("510001")),
        (service, None, _account("410002"), _account("510002")),
    ):
        key = f"{item}|{COMPANY_A}"
        if not frappe.db.exists("ASOUD Item Company Profile", key):
            frappe.get_doc(
                {
                    "doctype": "ASOUD Item Company Profile",
                    "item": item,
                    "company": COMPANY_A,
                    "enabled": 1,
                    "default_branch": branch,
                    "default_warehouse": default_warehouse,
                    "income_account": income,
                    "expense_account": expense,
                }
            ).insert(ignore_permissions=True)


def _ensure_company_defaults() -> None:
    import frappe

    frappe.db.set_value(
        "Company",
        COMPANY_A,
        {
            "default_receivable_account": _account("112001"),
            "default_payable_account": _account("211001"),
            "default_income_account": _account("410001"),
            "default_expense_account": _account("510001"),
            "stock_adjustment_account": _account("530004"),
            "enable_perpetual_inventory": 1,
        },
        update_modified=False,
    )


def _ensure_initial_stock(branch: str, warehouse: str, item: str) -> str:
    import frappe

    marker = "ASOUD-P5-OPENING-STOCK"
    existing_rows = frappe.db.sql(
        """
        select sr.name
         from `tabStock Reconciliation` sr
          join `tabStock Reconciliation Item` sri on sri.parent=sr.name
         where sr.docstatus=1 and sr.company=%s
           and sri.item_code=%s and sri.warehouse=%s
         order by sr.creation
         limit 1
        """,
        (COMPANY_A, item, warehouse),
    )
    existing = existing_rows[0][0] if existing_rows else None
    if existing:
        return existing
    reconciliation = frappe.get_doc(
        {
            "doctype": "Stock Reconciliation",
            "company": COMPANY_A,
            "posting_date": POSTING_DATE,
            "posting_time": "08:00:00",
            "purpose": "Stock Reconciliation",
            "expense_account": _account("211003"),
            "asoud_branch": branch,
            "remarks": marker,
            "items": [
                {
                    "item_code": item,
                    "warehouse": warehouse,
                    "qty": 100,
                    "valuation_rate": 1000,
                }
            ],
        }
    ).insert(ignore_permissions=True)
    reconciliation.submit()
    return reconciliation.name


def _ensure_sales(customer: str, goods: str, service: str, branch: str) -> dict:
    import frappe

    marker = "ASOUD-P5-SALES"
    order_name = frappe.db.exists("Sales Order", {"po_no": marker, "docstatus": 1})
    if not order_name:
        order = frappe.get_doc(
            {
                "doctype": "Sales Order",
                "company": COMPANY_A,
                "customer": customer,
                "transaction_date": POSTING_DATE,
                "delivery_date": POSTING_DATE,
                "po_no": marker,
                "currency": "IRR",
                "conversion_rate": 1,
                "selling_price_list": "ASOUD Standard Selling",
                "price_list_currency": "IRR",
                "plc_conversion_rate": 1,
                "asoud_branch": branch,
                "items": [
                    {"item_code": goods, "qty": 2, "rate": 1500, "delivery_date": POSTING_DATE},
                    {"item_code": service, "qty": 1, "rate": 2000, "delivery_date": POSTING_DATE},
                ],
            }
        ).insert(ignore_permissions=True)
        order.submit()
        order_name = order.name
    delivery_name = frappe.db.exists(
        "Delivery Note Item", {"against_sales_order": order_name}, cache=True
    )
    if delivery_name:
        delivery_name = frappe.db.get_value("Delivery Note Item", delivery_name, "parent")
    else:
        from erpnext.selling.doctype.sales_order.sales_order import make_delivery_note

        delivery = make_delivery_note(order_name)
        delivery.posting_date = POSTING_DATE
        delivery.posting_time = "10:00:00"
        delivery.asoud_branch = branch
        delivery.insert(ignore_permissions=True)
        delivery.submit()
        delivery_name = delivery.name
    invoice_name = frappe.db.exists(
        "Sales Invoice Item", {"sales_order": order_name, "docstatus": 1}, cache=True
    )
    if invoice_name:
        invoice_name = frappe.db.get_value("Sales Invoice Item", invoice_name, "parent")
    else:
        from erpnext.selling.doctype.sales_order.sales_order import make_sales_invoice

        invoice = make_sales_invoice(order_name)
        invoice.posting_date = POSTING_DATE
        invoice.asoud_branch = branch
        invoice.insert(ignore_permissions=True)
        invoice.submit()
        invoice_name = invoice.name
    return {"order": order_name, "delivery": delivery_name, "invoice": invoice_name}


def _ensure_purchase(supplier: str, goods: str, service: str, branch: str) -> dict:
    import frappe

    marker = "ASOUD-P5-PURCHASE"
    order_rows = frappe.db.sql(
        """
        select po.name
          from `tabPurchase Order` po
          join `tabPurchase Order Item` poi on poi.parent=po.name
         where po.docstatus=1 and po.company=%s and po.supplier=%s
           and po.transaction_date=%s and poi.item_code=%s and poi.qty=5
         order by po.creation
         limit 1
        """,
        (COMPANY_A, supplier, POSTING_DATE, goods),
    )
    order_name = order_rows[0][0] if order_rows else None
    if not order_name:
        order = frappe.get_doc(
            {
                "doctype": "Purchase Order",
                "company": COMPANY_A,
                "supplier": supplier,
                "transaction_date": POSTING_DATE,
                "schedule_date": POSTING_DATE,
                "supplier_quotation": marker,
                "currency": "IRR",
                "conversion_rate": 1,
                "buying_price_list": "ASOUD Standard Buying",
                "price_list_currency": "IRR",
                "plc_conversion_rate": 1,
                "asoud_branch": branch,
                "items": [
                    {"item_code": goods, "qty": 5, "rate": 900, "schedule_date": POSTING_DATE},
                    {"item_code": service, "qty": 1, "rate": 1200, "schedule_date": POSTING_DATE},
                ],
            }
        ).insert(ignore_permissions=True)
        order.submit()
        order_name = order.name
    receipt_name = frappe.db.exists(
        "Purchase Receipt Item", {"purchase_order": order_name, "docstatus": 1}, cache=True
    )
    if receipt_name:
        receipt_name = frappe.db.get_value("Purchase Receipt Item", receipt_name, "parent")
    else:
        from erpnext.buying.doctype.purchase_order.purchase_order import make_purchase_receipt

        receipt = make_purchase_receipt(order_name)
        receipt.posting_date = POSTING_DATE
        receipt.posting_time = "11:00:00"
        receipt.asoud_branch = branch
        receipt.insert(ignore_permissions=True)
        receipt.submit()
        receipt_name = receipt.name
    invoice_name = frappe.db.exists(
        "Purchase Invoice Item", {"purchase_order": order_name, "docstatus": 1}, cache=True
    )
    if invoice_name:
        invoice_name = frappe.db.get_value("Purchase Invoice Item", invoice_name, "parent")
    else:
        from erpnext.buying.doctype.purchase_order.purchase_order import make_purchase_invoice

        invoice = make_purchase_invoice(order_name)
        invoice.posting_date = POSTING_DATE
        invoice.asoud_branch = branch
        invoice.insert(ignore_permissions=True)
        invoice.submit()
        invoice_name = invoice.name
    return {"order": order_name, "receipt": receipt_name, "invoice": invoice_name}


def _ensure_payment(invoice_type: str, invoice_name: str, branch: str) -> str:
    import frappe

    existing = frappe.db.exists(
        "Payment Entry Reference",
        {"reference_doctype": invoice_type, "reference_name": invoice_name, "docstatus": 1},
        cache=True,
    )
    if existing:
        return frappe.db.get_value("Payment Entry Reference", existing, "parent")
    invoice = frappe.get_doc(invoice_type, invoice_name)
    is_sales = invoice_type == "Sales Invoice"
    amount = invoice.outstanding_amount
    payment = frappe.get_doc(
        {
            "doctype": "Payment Entry",
            "payment_type": "Receive" if is_sales else "Pay",
            "company": COMPANY_A,
            "posting_date": POSTING_DATE,
            "party_type": "Customer" if is_sales else "Supplier",
            "party": invoice.customer if is_sales else invoice.supplier,
            "paid_from": _account("112001") if is_sales else _account("111001"),
            "paid_to": _account("111001") if is_sales else _account("211001"),
            "paid_amount": amount,
            "received_amount": amount,
            "reference_no": f"ASOUD-P5-{invoice_type}",
            "reference_date": POSTING_DATE,
            "asoud_branch": branch,
            "references": [
                {
                    "reference_doctype": invoice_type,
                    "reference_name": invoice_name,
                    "total_amount": invoice.grand_total,
                    "outstanding_amount": amount,
                    "allocated_amount": amount,
                }
            ],
        }
    ).insert(ignore_permissions=True)
    payment.submit()
    return payment.name


def _ensure_transfer(item: str, source: str, target: str, branch: str) -> str:
    import frappe

    marker = "ASOUD-P5-BRANCH-TRANSFER"
    existing = frappe.db.exists("Stock Entry", {"remarks": marker, "docstatus": 1})
    if existing:
        return existing
    transfer = frappe.get_doc(
        {
            "doctype": "Stock Entry",
            "stock_entry_type": "Material Transfer",
            "purpose": "Material Transfer",
            "company": COMPANY_A,
            "from_warehouse": source,
            "to_warehouse": target,
            "posting_date": POSTING_DATE,
            "posting_time": "14:00:00",
            "asoud_branch": branch,
            "remarks": marker,
            "items": [
                {
                    "item_code": item,
                    "qty": 1,
                    "s_warehouse": source,
                    "t_warehouse": target,
                }
            ],
        }
    ).insert(ignore_permissions=True)
    transfer.submit()
    return transfer.name


def _assert_credit_limit(customer: str, goods: str, branch: str) -> None:
    import frappe

    profile = f"Customer|{customer}|{COMPANY_A}"
    old_limit = frappe.db.get_value("ASOUD Party Company Profile", profile, "credit_limit")
    frappe.db.set_value("ASOUD Party Company Profile", profile, "credit_limit", 1)
    try:
        frappe.get_doc(
            {
                "doctype": "Sales Invoice",
                "company": COMPANY_A,
                "customer": customer,
                "posting_date": POSTING_DATE,
                "due_date": POSTING_DATE,
                "asoud_branch": branch,
                "items": [{"item_code": goods, "qty": 1, "rate": 10}],
            }
        ).insert(ignore_permissions=True)
    except frappe.ValidationError:
        pass
    else:
        raise AssertionError("Company-specific customer credit limit was not enforced")
    finally:
        frappe.db.set_value(
            "ASOUD Party Company Profile", profile, "credit_limit", old_limit
        )


def _assert_gl_balance(vouchers: list[str]) -> None:
    import frappe

    for voucher in vouchers:
        debit, credit = frappe.db.sql(
            """
            select coalesce(sum(debit), 0), coalesce(sum(credit), 0)
              from `tabGL Entry`
             where voucher_no=%s and is_cancelled=0
            """,
            voucher,
        )[0]
        if round(float(debit or 0), 2) != round(float(credit or 0), 2):
            raise AssertionError(f"GL is not balanced for {voucher}")


def run_phase_five_acceptance() -> dict:
    import frappe

    frappe.only_for("System Manager")
    ensure_phase_one_demo()
    frappe.set_user("Administrator")
    _ensure_company_defaults()
    branches = frappe.get_all(
        "ASOUD Branch",
        filters={"company": COMPANY_A, "enabled": 1},
        fields=["name", "branch_code"],
    )
    branch_by_code = {row.branch_code: row.name for row in branches}
    hq, ops = branch_by_code["HQ"], branch_by_code["OPS"]
    hq_warehouse = _ensure_warehouse(hq, "ASOUD Phase Five HQ")
    ops_warehouse = _ensure_warehouse(ops, "ASOUD Phase Five OPS")
    customer = _ensure_party("Customer", CUSTOMER)
    supplier = _ensure_party("Supplier", SUPPLIER)
    goods = _ensure_item(
        GOODS, "Phase Five Goods", "Goods", hq_warehouse, _account("410001"), _account("510001")
    )
    service = _ensure_item(
        SERVICE, "Phase Five Service", "Service", None, _account("410002"), _account("510002")
    )
    _ensure_profiles(customer, supplier, goods, service, hq, hq_warehouse)
    opening = _ensure_initial_stock(hq, hq_warehouse, goods)
    sales = _ensure_sales(customer, goods, service, hq)
    purchase = _ensure_purchase(supplier, goods, service, hq)
    receipt = _ensure_payment("Sales Invoice", sales["invoice"], hq)
    payment = _ensure_payment("Purchase Invoice", purchase["invoice"], hq)
    transfer = _ensure_transfer(goods, hq_warehouse, ops_warehouse, hq)
    _assert_credit_limit(customer, goods, hq)

    sources = [
        opening,
        sales["delivery"],
        sales["invoice"],
        purchase["receipt"],
        purchase["invoice"],
        receipt,
        payment,
        transfer,
    ]
    missing_registry = [
        source
        for source in sources
        if not frappe.db.exists("ASOUD Accounting Document", {"source_name": source})
    ]
    if missing_registry:
        raise AssertionError(f"Accounting registry is incomplete: {missing_registry}")
    _assert_gl_balance([sales["invoice"], purchase["invoice"], receipt, payment, transfer])
    hq_qty = frappe.db.get_value("Bin", {"item_code": goods, "warehouse": hq_warehouse}, "actual_qty")
    ops_qty = frappe.db.get_value("Bin", {"item_code": goods, "warehouse": ops_warehouse}, "actual_qty")
    transfer_ledger = frappe.get_all(
        "Stock Ledger Entry",
        filters={"voucher_no": transfer, "is_cancelled": 0},
        fields=["warehouse", "actual_qty"],
    )
    movement = {
        row.warehouse: movement_qty
        for row in transfer_ledger
        for movement_qty in [float(row.actual_qty)]
    }
    if (
        movement.get(hq_warehouse, 0) >= 0
        or movement.get(ops_warehouse, 0) <= 0
        or float(ops_qty or 0) < 1
        or float(hq_qty or 0) <= 0
    ):
        raise AssertionError(
            f"Branch stock transfer mismatch: ledger={movement}, "
            f"hq_bin={hq_qty}, ops_bin={ops_qty}"
        )
    frappe.db.commit()
    return {
        "status": "passed",
        "masters": {"customer": customer, "supplier": supplier, "items": [goods, service]},
        "sales": sales,
        "purchase": purchase,
        "payments": [receipt, payment],
        "inventory": {
            "opening": opening,
            "transfer": transfer,
            "hq_qty": float(hq_qty),
            "ops_qty": float(ops_qty),
        },
        "registry_documents": len(sources),
        "credit_limit": "enforced",
        "gl_balance": "passed",
    }
