from __future__ import annotations

from asoud_core.phase_one_demo import (
    COMPANY_A,
    COMPANY_B,
    HOLDING_CODE,
    USERS,
    ensure_phase_one_demo,
)

POSTING_DATE = "2026-11-15"


def _account(company: str, code: str) -> str:
    import frappe

    name = frappe.db.get_value(
        "Account", {"company": company, "account_number": code}, "name"
    )
    if not name:
        raise AssertionError(f"Missing account {code} in {company}")
    return name


def _ensure_account(
    company: str,
    code: str,
    title: str,
    parent_code: str,
    root_type: str,
) -> str:
    import frappe

    existing = frappe.db.get_value(
        "Account", {"company": company, "account_number": code}, "name"
    )
    if existing:
        return existing
    return (
        frappe.get_doc(
            {
                "doctype": "Account",
                "account_name": title,
                "account_number": code,
                "parent_account": _account(company, parent_code),
                "company": company,
                "root_type": root_type,
                "report_type": "Balance Sheet",
                "account_currency": "IRR",
                "is_group": 0,
            }
        )
        .insert(ignore_permissions=True)
        .name
    )


def _branch(company: str) -> str:
    import frappe

    branch = frappe.db.get_value(
        "ASOUD Branch", {"company": company, "branch_code": "HQ"}, "name"
    )
    if not branch:
        raise AssertionError(f"Missing HQ branch in {company}")
    return branch


def _stock_adjustment(company: str) -> str:
    import frappe

    account = frappe.db.get_value("Company", company, "stock_adjustment_account")
    if not account:
        raise AssertionError(f"Stock adjustment account is missing in {company}")
    return account


def _cost_detail() -> str:
    import frappe

    title = "Phase Seven Intercompany Cost Center"
    existing = frappe.db.exists(
        "ASOUD Floating Detail",
        {"holding": HOLDING_CODE, "detail_title": title},
    )
    if existing:
        detail = frappe.get_doc("ASOUD Floating Detail", existing)
    else:
        detail = frappe.get_doc(
            {
                "doctype": "ASOUD Floating Detail",
                "detail_title": title,
                "holding": HOLDING_CODE,
                "detail_type": "Cost Center",
                "enabled": 1,
            }
        ).insert(ignore_permissions=True)
    mapped = {row.company for row in detail.company_codes}
    changed = False
    for company, code in ((COMPANY_A, "P7-CCA"), (COMPANY_B, "P7-CCB")):
        if company not in mapped:
            detail.append(
                "company_codes",
                {"company": company, "detail_code": code, "enabled": 1},
            )
            changed = True
    if changed:
        detail.save(ignore_permissions=True)
    return detail.name


def _settlement_detail(company: str) -> str | None:
    import frappe

    account = _stock_adjustment(company)
    required = frappe.db.exists(
        "ASOUD Account Detail Rule",
        {"company": company, "account": account, "enabled": 1, "required": 1},
    )
    return _cost_detail() if required else None


def _ensure_mappings() -> int:
    import frappe

    accounts = frappe.get_all(
        "Account",
        filters={"company": ["in", (COMPANY_A, COMPANY_B)], "is_group": 0},
        fields=["name", "company", "account_number", "account_name", "root_type"],
    )
    for account in accounts:
        code = account.account_number or f"NAME::{account.account_name}"
        existing = frappe.db.exists(
            "ASOUD Consolidation Account Map",
            {
                "holding": HOLDING_CODE,
                "company": account.company,
                "account": account.name,
            },
        )
        if not existing:
            frappe.get_doc(
                {
                    "doctype": "ASOUD Consolidation Account Map",
                    "holding": HOLDING_CODE,
                    "company": account.company,
                    "account": account.name,
                    "consolidation_code": code,
                    "consolidation_title": account.account_name,
                    "enabled": 1,
                }
            ).insert(ignore_permissions=True)
    return len(accounts)


def _ensure_transfer(marker: str, amount: int) -> str:
    import frappe

    from asoud_core.services.intercompany import accept_destination, approve_source

    existing = frappe.db.exists(
        "ASOUD Intercompany Transfer", {"idempotency_key": marker}
    )
    if existing:
        doc = frappe.get_doc("ASOUD Intercompany Transfer", existing)
        if doc.docstatus == 0 and doc.status == "Requested":
            approve_source(doc.name)
        if doc.docstatus == 0 and doc.status == "Source Approved":
            accept_destination(doc.name)
        return doc.name
    transfer = frappe.get_doc(
        {
            "doctype": "ASOUD Intercompany Transfer",
            "transfer_type": "Money",
            "posting_date": POSTING_DATE,
            "source_company": COMPANY_A,
            "source_branch": _branch(COMPANY_A),
            "destination_company": COMPANY_B,
            "destination_branch": _branch(COMPANY_B),
            "source_settlement_account": _account(COMPANY_A, "111003"),
            "source_intercompany_account": _account(COMPANY_A, "112099"),
            "destination_settlement_account": _account(COMPANY_B, "111003"),
            "destination_intercompany_account": _account(COMPANY_B, "211099"),
            "amount": amount,
            "currency": "IRR",
            "idempotency_key": marker,
            "reason": f"Controlled phase-seven transfer {marker}",
            "status": "Requested",
        }
    ).insert(ignore_permissions=True)
    approve_source(transfer.name)
    accept_destination(transfer.name)
    return transfer.name


def _ensure_goods_vouchers() -> tuple[str, str, int]:
    import frappe

    from asoud_core.phase_five_acceptance import GOODS

    source_branch = _branch(COMPANY_A)
    destination_branch = _branch(COMPANY_B)
    source_warehouse = frappe.db.get_value(
        "Warehouse",
        {"company": COMPANY_A, "warehouse_name": "ASOUD Phase Five HQ"},
        "name",
    )
    if not source_warehouse:
        raise AssertionError("Phase-five source warehouse is missing")
    destination_warehouse = frappe.db.get_value(
        "Warehouse",
        {"company": COMPANY_B, "warehouse_name": "ASOUD Phase Seven Receipt"},
        "name",
    )
    if not destination_warehouse:
        destination_warehouse = (
            frappe.get_doc(
                {
                    "doctype": "Warehouse",
                    "warehouse_name": "ASOUD Phase Seven Receipt",
                    "company": COMPANY_B,
                    "is_group": 0,
                    "asoud_branch": destination_branch,
                }
            )
            .insert(ignore_permissions=True)
            .name
        )
    profile_key = f"{GOODS}|{COMPANY_B}"
    if not frappe.db.exists("ASOUD Item Company Profile", profile_key):
        frappe.get_doc(
            {
                "doctype": "ASOUD Item Company Profile",
                "item": GOODS,
                "company": COMPANY_B,
                "enabled": 1,
                "default_branch": destination_branch,
                "default_warehouse": destination_warehouse,
                "income_account": _account(COMPANY_B, "410001"),
                "expense_account": _account(COMPANY_B, "510001"),
            }
        ).insert(ignore_permissions=True)

    def stock_entry(
        purpose: str,
        marker: str,
        *,
        source: str | None = None,
        destination: str | None = None,
    ) -> str:
        existing = frappe.db.exists(
            "Stock Entry",
            {
                "company": COMPANY_A if source else COMPANY_B,
                "remarks": marker,
                "docstatus": 1,
            },
        )
        if existing:
            return existing
        item = {"item_code": GOODS, "qty": 1, "basic_rate": 1000}
        if source:
            item["s_warehouse"] = source
        if destination:
            item["t_warehouse"] = destination
        document = frappe.get_doc(
            {
                "doctype": "Stock Entry",
                "stock_entry_type": purpose,
                "purpose": purpose,
                "company": COMPANY_A if source else COMPANY_B,
                "from_warehouse": source,
                "to_warehouse": destination,
                "posting_date": POSTING_DATE,
                "asoud_branch": source_branch if source else destination_branch,
                "remarks": marker,
                "items": [item],
            }
        ).insert(ignore_permissions=True)
        document.submit()
        return document.name

    source = stock_entry(
        "Material Issue",
        "ASOUD-P7-GOODS-SOURCE",
        source=source_warehouse,
    )
    destination = stock_entry(
        "Material Receipt",
        "ASOUD-P7-GOODS-DESTINATION",
        destination=destination_warehouse,
    )
    source_value = int(
        round(float(frappe.db.get_value("Stock Entry", source, "total_outgoing_value")))
    )
    destination_value = int(
        round(
            float(
                frappe.db.get_value(
                    "Stock Entry", destination, "total_incoming_value"
                )
            )
        )
    )
    if source_value != destination_value or source_value <= 0:
        raise AssertionError(
            f"Goods voucher values differ: source={source_value}, destination={destination_value}"
        )
    return source, destination, source_value


def _ensure_goods_transfer() -> str:
    import frappe

    from asoud_core.services.intercompany import accept_destination, approve_source

    marker = "ASOUD-P7-GOODS-001"
    existing = frappe.db.exists(
        "ASOUD Intercompany Transfer", {"idempotency_key": marker}
    )
    if existing:
        doc = frappe.get_doc("ASOUD Intercompany Transfer", existing)
        if doc.docstatus == 0 and doc.status == "Requested":
            approve_source(doc.name)
        if doc.docstatus == 0 and doc.status == "Source Approved":
            accept_destination(doc.name)
        return doc.name
    source_voucher, destination_voucher, amount = _ensure_goods_vouchers()
    transfer = frappe.get_doc(
        {
            "doctype": "ASOUD Intercompany Transfer",
            "transfer_type": "Goods",
            "posting_date": POSTING_DATE,
            "source_company": COMPANY_A,
            "source_branch": _branch(COMPANY_A),
            "destination_company": COMPANY_B,
            "destination_branch": _branch(COMPANY_B),
            "source_settlement_account": _stock_adjustment(COMPANY_A),
            "source_settlement_detail": _settlement_detail(COMPANY_A),
            "source_intercompany_account": _account(COMPANY_A, "112099"),
            "source_voucher_type": "Stock Entry",
            "source_voucher": source_voucher,
            "destination_settlement_account": _stock_adjustment(COMPANY_B),
            "destination_settlement_detail": _settlement_detail(COMPANY_B),
            "destination_intercompany_account": _account(COMPANY_B, "211099"),
            "destination_voucher_type": "Stock Entry",
            "destination_voucher": destination_voucher,
            "amount": amount,
            "currency": "IRR",
            "idempotency_key": marker,
            "reason": "Controlled goods transfer with official stock vouchers",
            "status": "Requested",
        }
    ).insert(ignore_permissions=True)
    approve_source(transfer.name)
    accept_destination(transfer.name)
    return transfer.name


def _assert_journal(name: str, company: str, transfer: str) -> None:
    import frappe

    row = frappe.db.get_value(
        "Journal Entry",
        name,
        ["company", "docstatus", "asoud_intercompany_transfer"],
        as_dict=True,
    )
    if (
        not row
        or row.company != company
        or row.docstatus != 1
        or row.asoud_intercompany_transfer != transfer
    ):
        raise AssertionError(f"Invalid paired journal {name}")
    debit, credit = frappe.db.sql(
        """
        select coalesce(sum(debit), 0), coalesce(sum(credit), 0)
          from `tabGL Entry`
         where voucher_type='Journal Entry' and voucher_no=%s and is_cancelled=0
        """,
        name,
    )[0]
    if round(float(debit), 2) != round(float(credit), 2):
        raise AssertionError(f"Unbalanced paired journal {name}")
    if not frappe.db.exists("ASOUD Accounting Document", {"source_name": name}):
        raise AssertionError(f"Paired journal is absent from registry: {name}")


def _assert_permission_denial() -> None:
    import frappe

    from asoud_core.services.intercompany import consolidation_report

    frappe.set_user(USERS["accountant"])
    try:
        consolidation_report(HOLDING_CODE, "2026-03-21", "2027-03-20")
    except frappe.PermissionError:
        pass
    else:
        raise AssertionError("Limited accountant accessed holding consolidation")
    finally:
        frappe.set_user("Administrator")


def run_phase_seven_acceptance() -> dict:
    import frappe

    from asoud_core.services.intercompany import (
        accept_destination,
        consolidation_report,
        reverse_transfer,
    )
    from asoud_core.phase_five_acceptance import run_phase_five_acceptance
    from asoud_iran.services.iran_setup import apply_iran_setup

    frappe.only_for("System Manager")
    demo = ensure_phase_one_demo()
    frappe.set_user("Administrator")
    apply_iran_setup(COMPANY_A)
    apply_iran_setup(COMPANY_B)
    run_phase_five_acceptance()
    for company in (COMPANY_A, COMPANY_B):
        _ensure_account(
            company,
            "112099",
            "Intercompany Receivable",
            "112000",
            "Asset",
        )
        _ensure_account(
            company,
            "211099",
            "Intercompany Payable",
            "211000",
            "Liability",
        )
    mapped_accounts = _ensure_mappings()
    main = _ensure_transfer("ASOUD-P7-MONEY-001", 10_000)
    goods = _ensure_goods_transfer()
    compensation_source = _ensure_transfer("ASOUD-P7-COMP-001", 1_000)
    compensation = frappe.db.get_value(
        "ASOUD Intercompany Transfer", compensation_source, "reversed_by"
    )
    if not compensation:
        compensation = reverse_transfer(
            compensation_source, POSTING_DATE, "Controlled compensation test"
        )
    main_doc = frappe.get_doc("ASOUD Intercompany Transfer", main)
    _assert_journal(main_doc.source_journal_entry, COMPANY_A, main)
    _assert_journal(main_doc.destination_journal_entry, COMPANY_B, main)
    repeated = accept_destination(main)
    if repeated["source_journal_entry"] != main_doc.source_journal_entry:
        raise AssertionError("Destination acceptance is not idempotent")
    frappe.db.commit()
    try:
        main_doc.cancel()
    except frappe.ValidationError:
        frappe.db.rollback()
    else:
        raise AssertionError("Direct cancellation of a completed transfer was accepted")
    # The rollback above affects only the failed cancellation savepoint in Frappe;
    # reload and explicitly preserve all committed acceptance fixtures.
    frappe.db.commit()
    report = consolidation_report(
        HOLDING_CODE, "2026-03-21", "2027-03-20"
    )
    if not report["controls"]["balanced"]:
        raise AssertionError(f"Consolidation controls failed: {report['controls']}")
    if report["unmapped"]:
        raise AssertionError(f"Unmapped consolidation activity: {report['unmapped']}")
    if not any(row["source"] == main for row in report["eliminations"]):
        raise AssertionError("Main transfer elimination is missing")
    _assert_permission_denial()
    frappe.db.commit()
    return {
        "status": "passed",
        "holding": demo["holding"],
        "main_transfer": main,
        "goods_transfer": goods,
        "compensated_transfer": compensation_source,
        "compensation": compensation,
        "paired_journals": [
            main_doc.source_journal_entry,
            main_doc.destination_journal_entry,
        ],
        "mapped_accounts": mapped_accounts,
        "consolidation_rows": len(report["rows"]),
        "elimination_rows": len(report["eliminations"]),
        "controls": report["controls"],
        "permission": "passed",
        "idempotency": "passed",
        "immutability": "passed",
    }
