from __future__ import annotations


def run_approval_page_acceptance() -> dict:
    import frappe

    from asoud_core import __version__
    from asoud_core.services.approval import inbox, policy_catalog

    company = frappe.db.get_value("Company", {"is_group": 0}, "name")
    if not company:
        raise AssertionError("A non-group company is required")
    incoming = inbox(company, view="incoming", limit=20)
    outgoing = inbox(company, view="outgoing", limit=20)
    history = inbox(company, view="history", limit=20)
    filtered = inbox(
        company,
        view="history",
        limit=20,
        search="__acceptance_no_match__",
        status="Approved",
    )
    if incoming.get("view") != "incoming":
        raise AssertionError("Incoming approval view is invalid")
    if outgoing.get("view") != "outgoing":
        raise AssertionError("Outgoing approval view is invalid")
    if history.get("view") != "history":
        raise AssertionError("Approval history view is invalid")
    if filtered.get("items"):
        raise AssertionError("Approval search filter is not applied")
    for result in (incoming, outgoing, history):
        counts = result.get("counts") or {}
        if not {"incoming", "outgoing", "history"} <= set(counts):
            raise AssertionError("Approval counters are incomplete")
    return {
        "status": "passed",
        "app_version": __version__,
        "company": company,
        "incoming": len(incoming["items"]),
        "outgoing": len(outgoing["items"]),
        "history": len(history["items"]),
        "policies": len(policy_catalog(company)),
        "search_and_status_filter": "passed",
        "detail_and_action_contract": "covered_by_automated_tests",
    }
