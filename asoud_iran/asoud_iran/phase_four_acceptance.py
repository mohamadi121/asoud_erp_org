from __future__ import annotations

from asoud_core.phase_one_demo import COMPANY_B, FISCAL_YEAR_1405

PHASE4_COMPANY = COMPANY_B


def _account(number: str) -> str:
    import frappe

    account = frappe.db.get_value(
        "Account", {"company": PHASE4_COMPANY, "account_number": number}, "name"
    )
    if not account:
        raise AssertionError(f"Account {number} does not exist")
    return account


def _detail(detail_type: str) -> str:
    import frappe

    title = f"Phase Four {detail_type}"
    existing = frappe.db.exists(
        "ASOUD Floating Detail", {"holding": "ASOUD-DEMO", "detail_title": title}
    )
    if existing:
        return existing
    return (
        frappe.get_doc(
            {
                "doctype": "ASOUD Floating Detail",
                "detail_title": title,
                "holding": "ASOUD-DEMO",
                "detail_type": detail_type,
                "enabled": 1,
                "company_codes": [
                    {
                        "company": PHASE4_COMPANY,
                        "detail_code": f"P4-{detail_type[:3].upper()}",
                        "enabled": 1,
                    }
                ],
            }
        )
        .insert(ignore_permissions=True)
        .name
    )


def _party(doctype: str, name: str) -> str:
    import frappe

    if frappe.db.exists(doctype, name):
        return name
    account_type = "Receivable" if doctype == "Customer" else "Payable"
    if not frappe.db.exists("Party Type", doctype):
        frappe.get_doc(
            {
                "doctype": "Party Type",
                "party_type": doctype,
                "account_type": account_type,
            }
        ).insert(ignore_permissions=True)
    if doctype == "Customer":
        groups = frappe.get_all("Customer Group", filters={"is_group": 0}, pluck="name", limit=1)
        if not groups:
            roots = frappe.get_all("Customer Group", filters={"is_group": 1}, pluck="name", limit=1)
            root = roots[0] if roots else frappe.get_doc(
                {
                    "doctype": "Customer Group",
                    "customer_group_name": "All Customer Groups",
                    "is_group": 1,
                }
            ).insert(ignore_permissions=True).name
            group = frappe.get_doc(
                {
                    "doctype": "Customer Group",
                    "customer_group_name": "ASOUD Customers",
                    "parent_customer_group": root,
                    "is_group": 0,
                }
            ).insert(ignore_permissions=True).name
        else:
            group = groups[0]
        territories = frappe.get_all("Territory", filters={"is_group": 0}, pluck="name", limit=1)
        if not territories:
            roots = frappe.get_all("Territory", filters={"is_group": 1}, pluck="name", limit=1)
            root = roots[0] if roots else frappe.get_doc(
                {
                    "doctype": "Territory",
                    "territory_name": "All Territories",
                    "is_group": 1,
                }
            ).insert(ignore_permissions=True).name
            territory = frappe.get_doc(
                {
                    "doctype": "Territory",
                    "territory_name": "ASOUD Territory",
                    "parent_territory": root,
                    "is_group": 0,
                }
            ).insert(ignore_permissions=True).name
        else:
            territory = territories[0]
        values = {
            "doctype": "Customer",
            "customer_name": name,
            "customer_type": "Company",
            "customer_group": group,
            "territory": territory,
        }
    else:
        groups = frappe.get_all("Supplier Group", filters={"is_group": 0}, pluck="name", limit=1)
        if not groups:
            roots = frappe.get_all("Supplier Group", filters={"is_group": 1}, pluck="name", limit=1)
            root = roots[0] if roots else frappe.get_doc(
                {
                    "doctype": "Supplier Group",
                    "supplier_group_name": "All Supplier Groups",
                    "is_group": 1,
                }
            ).insert(ignore_permissions=True).name
            group = frappe.get_doc(
                {
                    "doctype": "Supplier Group",
                    "supplier_group_name": "ASOUD Suppliers",
                    "parent_supplier_group": root,
                    "is_group": 0,
                }
            ).insert(ignore_permissions=True).name
        else:
            group = groups[0]
        values = {
            "doctype": "Supplier",
            "supplier_name": name,
            "supplier_group": group,
            "supplier_type": "Company",
        }
    return frappe.get_doc(values).insert(ignore_permissions=True).name


def _source_entry(marker: str, accounts: list[dict]) -> str:
    import frappe

    existing = frappe.db.exists("Journal Entry", {"user_remark": marker, "docstatus": 1})
    if existing:
        return existing
    branch = frappe.db.get_value(
        "ASOUD Branch", {"company": PHASE4_COMPANY, "branch_code": "HQ"}, "name"
    )
    for row in accounts:
        row["asoud_branch"] = branch
    doc = frappe.get_doc(
        {
            "doctype": "Journal Entry",
            "voucher_type": "Journal Entry",
            "company": PHASE4_COMPANY,
            "posting_date": "2027-03-19",
            "asoud_branch": branch,
            "user_remark": marker,
            "accounts": accounts,
        }
    ).insert(ignore_permissions=True)
    doc.submit()
    return doc.name


def run_phase_four_acceptance() -> dict:
    import frappe

    from asoud_core.services.journal_numbering import run_final_numbering
    from asoud_iran.services.fiscal_closing import execute, preflight
    from asoud_iran.services.iran_setup import apply_iran_setup

    frappe.only_for("System Manager")
    frappe.set_user("Administrator")
    apply_iran_setup(PHASE4_COMPANY)
    customer = _party("Customer", "ASOUD Phase Four Customer")
    supplier = _party("Supplier", "ASOUD Phase Four Supplier")
    customer_detail = _detail("Customer")
    supplier_detail, cost_detail = _detail("Supplier"), _detail("Cost Center")
    cost_center = frappe.db.get_value("Company", PHASE4_COMPANY, "cost_center")
    receivable, payable = _account("112001"), _account("211001")
    revenue, expense = _account("410002"), _account("530002")
    _source_entry(
        "ASOUD-PHASE4-PARTY-RECEIVABLE",
        [
            {
                "account": receivable,
                "party_type": "Customer",
                "party": customer,
                "debit_in_account_currency": 500,
                "asoud_floating_detail": customer_detail,
            },
            {
                "account": revenue,
                "credit_in_account_currency": 500,
                "cost_center": cost_center,
            },
        ],
    )
    _source_entry(
        "ASOUD-PHASE4-PARTY-PAYABLE",
        [
            {
                "account": expense,
                "debit_in_account_currency": 300,
                "cost_center": cost_center,
                "asoud_floating_detail": cost_detail,
            },
            {
                "account": payable,
                "party_type": "Supplier",
                "party": supplier,
                "credit_in_account_currency": 300,
                "asoud_floating_detail": supplier_detail,
            },
        ],
    )
    run_final_numbering(
        company=PHASE4_COMPANY,
        fiscal_year=FISCAL_YEAR_1405,
        from_date="2026-03-21",
        to_date="2027-03-19",
        reason="Phase-four source numbering",
    )
    run_name = frappe.db.exists(
        "ASOUD Closing Run",
        {"company": PHASE4_COMPANY, "fiscal_year": FISCAL_YEAR_1405, "docstatus": 1},
    )
    if not run_name:
        run = frappe.get_doc(
            {
                "doctype": "ASOUD Closing Run",
                "company": PHASE4_COMPANY,
                "fiscal_year": FISCAL_YEAR_1405,
                "closing_date": "2027-03-20",
                "opening_date": "2027-03-21",
                "retained_earnings_account": _account("310003"),
                "closing_control_account": _account("310002"),
                "opening_control_account": _account("310004"),
            }
        ).insert(ignore_permissions=True)
        run.submit()
        run_name = run.name
    report = preflight(run_name)
    if not report["passed"] or report["party_balance_count"] < 2:
        raise AssertionError(f"Closing preflight did not accept party balances: {report}")
    created = execute(run_name)
    repeated = execute(run_name)
    if created != repeated:
        raise AssertionError("Closing retry created or selected different vouchers")
    run = frappe.get_doc("ASOUD Closing Run", run_name)
    if run.status != "Completed" or run.reconciliation_status != "Passed":
        raise AssertionError("Two-year reconciliation did not pass")
    for name in created.values():
        if not name:
            continue
        row = frappe.db.get_value(
            "Journal Entry",
            name,
            ["docstatus", "asoud_temporary_number", "asoud_final_number"],
            as_dict=True,
        )
        if row.docstatus != 1 or not row.asoud_temporary_number or not row.asoud_final_number:
            raise AssertionError(f"Generated voucher {name} is not submitted and final-numbered")
    opening = created["opening_journal_entry"]
    party_rows = frappe.get_all(
        "Journal Entry Account",
        filters={"parent": opening, "party": ["in", [customer, supplier]]},
        fields=["party_type", "party", "asoud_floating_detail", "asoud_branch"],
    )
    if {row.party for row in party_rows} != {customer, supplier}:
        raise AssertionError("Opening voucher lost receivable/payable party identities")
    if any(not row.asoud_floating_detail or not row.asoud_branch for row in party_rows):
        raise AssertionError("Opening voucher lost floating detail or branch dimension")
    frappe.db.commit()
    return {
        "status": "passed",
        "run": run_name,
        "preflight": "passed",
        "party_balances": report["party_balance_count"],
        "dimension_balances": report["dimension_balance_count"],
        "reconciliation": "passed",
        "retry": "idempotent",
        "vouchers": created,
    }
