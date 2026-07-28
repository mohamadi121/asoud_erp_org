from __future__ import annotations


def run_dashboard_acceptance() -> dict:
    import frappe

    from asoud_core import __version__
    from asoud_core.services.dashboard import workspace_snapshot

    company = frappe.db.get_value("Company", {"is_group": 0}, "name")
    if not company:
        raise AssertionError("A non-group company is required for dashboard acceptance")
    snapshot = workspace_snapshot(company)
    card_keys = {row["key"] for row in snapshot["cards"]}
    required_cards = {
        "sales_today",
        "receipts_today",
        "payments_today",
        "bank_balance",
        "cash_balance",
        "petty_cash_balance",
    }
    if card_keys != required_cards:
        raise AssertionError("Dashboard KPI contract is incomplete")
    if len(snapshot["cash_flow"]) != 6:
        raise AssertionError("Dashboard cash-flow series must contain six periods")
    if len(snapshot["quick_create_contracts"]) < 8:
        raise AssertionError("Dashboard quick-create contract coverage is incomplete")
    sales = next(
        (
            item
            for item in snapshot["quick_create_contracts"]
            if item["document_type"] == "Sales Invoice"
        ),
        None,
    )
    if not sales or not sales.get("field_specs") or not sales.get("child_field_specs"):
        raise AssertionError("Typed quick-create metadata is incomplete")
    customer = next(
        (item for item in sales["field_specs"] if item["fieldname"] == "customer"),
        None,
    )
    if not customer or customer["fieldtype"] != "Link" or not customer["required"]:
        raise AssertionError("Sales customer Link contract is invalid")
    if not sales.get("child_required"):
        raise AssertionError("Sales Invoice must require at least one child row")
    return {
        "status": "passed",
        "app_version": __version__,
        "company": company,
        "card_count": len(snapshot["cards"]),
        "cash_flow_periods": len(snapshot["cash_flow"]),
        "recent_operations": len(snapshot["recent_operations"]),
        "quick_create_contracts": len(snapshot["quick_create_contracts"]),
        "typed_field_contract": "passed",
    }
