from __future__ import annotations

from typing import Any


def percentage_change(current: float, previous: float) -> float:
    """Return a bounded, presentation-ready percentage change."""
    current = float(current or 0)
    previous = float(previous or 0)
    if previous == 0:
        return 0.0 if current == 0 else 100.0
    return round(((current - previous) / abs(previous)) * 100, 1)


def _context_clause(branch: str | None, alias: str = "") -> tuple[str, list[str]]:
    if not branch:
        return "", []
    prefix = f"{alias}." if alias else ""
    return f" and {prefix}asoud_branch=%s", [branch]


def _document_total(
    doctype: str,
    field: str,
    company: str,
    posting_date: str,
    branch: str | None,
) -> float:
    import frappe

    branch_clause, branch_values = _context_clause(branch)
    value = frappe.db.sql(
        f"""
        select coalesce(sum({field}), 0)
          from `tab{doctype}`
         where docstatus=1 and company=%s and posting_date=%s {branch_clause}
        """,
        tuple([company, posting_date, *branch_values]),
    )[0][0]
    return float(value or 0)


def _treasury_totals(
    company: str,
    branch: str | None,
    as_of_date: str,
) -> dict[str, float]:
    import frappe

    from asoud_core.services.treasury import ledger_balance

    filters: dict[str, Any] = {"company": company, "enabled": 1}
    if branch:
        filters["branch"] = branch
    totals = {"Bank": 0.0, "Cash": 0.0, "Petty Cash": 0.0}
    for account in frappe.get_all(
        "ASOUD Treasury Account",
        filters=filters,
        fields=["treasury_type", "ledger_account"],
        limit_page_length=0,
    ):
        account_type = account.treasury_type
        if account_type in totals:
            totals[account_type] += float(
                ledger_balance(account.ledger_account, company, as_of_date) or 0
            )
    return totals


def _cash_flow(company: str, branch: str | None, today: str) -> list[dict[str, Any]]:
    import frappe
    from frappe.utils import add_months, get_first_day

    first_month = str(get_first_day(add_months(today, -5)))
    branch_clause, branch_values = _context_clause(branch)
    rows = frappe.db.sql(
        f"""
        select date_format(posting_date, '%%Y-%%m') period,
               coalesce(sum(base_received_amount), 0) receipts,
               coalesce(sum(base_paid_amount), 0) payments
          from `tabPayment Entry`
         where docstatus=1 and company=%s and posting_date between %s and %s
               {branch_clause}
         group by date_format(posting_date, '%%Y-%%m')
         order by period
        """,
        tuple([company, first_month, today, *branch_values]),
        as_dict=True,
    )
    indexed = {
        str(row.period): {
            "receipts": float(row.receipts or 0),
            "payments": float(row.payments or 0),
        }
        for row in rows
    }
    periods = [
        str(add_months(first_month, offset))[:7]
        for offset in range(6)
    ]
    return [
        {
            "period": period,
            **indexed.get(period, {"receipts": 0.0, "payments": 0.0}),
        }
        for period in periods
    ]


def _income_mix(
    company: str,
    branch: str | None,
    from_date: str,
    to_date: str,
) -> list[dict[str, Any]]:
    import frappe

    branch_clause, branch_values = _context_clause(branch, "si")
    rows = frappe.db.sql(
        f"""
        select case when coalesce(item.is_stock_item, 0)=1
                    then 'goods' else 'services' end category,
               coalesce(sum(sii.base_net_amount), 0) amount
          from `tabSales Invoice Item` sii
          join `tabSales Invoice` si on si.name=sii.parent
          left join `tabItem` item on item.name=sii.item_code
         where si.docstatus=1 and si.company=%s
               and si.posting_date between %s and %s {branch_clause}
         group by category
        """,
        tuple([company, from_date, to_date, *branch_values]),
        as_dict=True,
    )
    return [
        {"category": str(row.category), "amount": float(row.amount or 0)}
        for row in rows
    ]


def workspace_snapshot(
    company: str,
    branch: str | None = None,
) -> dict[str, Any]:
    import frappe
    from frappe.utils import add_days, get_first_day, now_datetime, nowdate

    from asoud_core.permissions import can_access_context
    from asoud_core.services.approval import inbox
    from asoud_core.services.operational_workbench import contracts, recent_documents

    branch = branch or None
    if not can_access_context(frappe.session.user, company, branch):
        frappe.throw("Not permitted", frappe.PermissionError)

    today = nowdate()
    yesterday = str(add_days(today, -1))
    month_start = str(get_first_day(today))
    sales = _document_total("Sales Invoice", "base_grand_total", company, today, branch)
    receipts = _document_total(
        "Payment Entry", "base_received_amount", company, today, branch
    )
    payments = _document_total(
        "Payment Entry", "base_paid_amount", company, today, branch
    )
    previous_sales = _document_total(
        "Sales Invoice", "base_grand_total", company, yesterday, branch
    )
    previous_receipts = _document_total(
        "Payment Entry", "base_received_amount", company, yesterday, branch
    )
    previous_payments = _document_total(
        "Payment Entry", "base_paid_amount", company, yesterday, branch
    )
    treasury = _treasury_totals(company, branch, today)
    approvals = inbox(company, branch, "incoming", 5)
    notifications = frappe.get_list(
        "Notification Log",
        filters={"for_user": frappe.session.user},
        fields=[
            "name",
            "subject",
            "type",
            "document_type",
            "document_name",
            "read",
            "creation",
        ],
        order_by="creation desc",
        page_length=5,
    )
    return {
        "company": company,
        "branch": branch,
        "as_of_date": today,
        "generated_at": str(now_datetime()),
        "currency": frappe.db.get_value("Company", company, "default_currency"),
        "cards": [
            {
                "key": "sales_today",
                "value": sales,
                "trend": percentage_change(sales, previous_sales),
            },
            {
                "key": "receipts_today",
                "value": receipts,
                "trend": percentage_change(receipts, previous_receipts),
            },
            {
                "key": "payments_today",
                "value": payments,
                "trend": percentage_change(payments, previous_payments),
            },
            {"key": "bank_balance", "value": treasury["Bank"], "trend": None},
            {"key": "cash_balance", "value": treasury["Cash"], "trend": None},
            {
                "key": "petty_cash_balance",
                "value": treasury["Petty Cash"],
                "trend": None,
            },
        ],
        "cash_flow": _cash_flow(company, branch, today),
        "income_mix": _income_mix(company, branch, month_start, today),
        "recent_operations": recent_documents(company, branch, 8),
        "approval_inbox": approvals,
        "notifications": [dict(row) for row in notifications],
        "quick_create_contracts": contracts(),
    }
