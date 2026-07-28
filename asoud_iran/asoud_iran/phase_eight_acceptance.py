from __future__ import annotations

import time

from asoud_core.phase_one_demo import COMPANY_A, COMPANY_B, USERS

FROM_DATE = "2026-03-21"
TO_DATE = "2027-05-31"
OPENING_DATE = "2027-05-11"


def _account(code: str) -> str:
    import frappe

    account = frappe.db.get_value(
        "Account", {"company": COMPANY_A, "account_number": code}, "name"
    )
    if not account:
        raise AssertionError(f"Phase-eight account {code} is missing")
    return account


def _branch(company: str) -> str:
    import frappe

    branch = frappe.db.get_value(
        "ASOUD Branch", {"company": company, "branch_code": "HQ", "enabled": 1}, "name"
    )
    if not branch:
        raise AssertionError(f"Phase-eight HQ branch is missing for {company}")
    return branch


def _other_detail() -> str:
    import frappe

    rows = frappe.db.sql(
        """
        SELECT fd.name
          FROM `tabASOUD Floating Detail` fd
          JOIN `tabASOUD Floating Detail Company` fdc ON fdc.parent=fd.name
         WHERE fd.detail_type='Other' AND fd.enabled=1
           AND fdc.company=%s AND fdc.enabled=1
         ORDER BY fd.creation
         LIMIT 1
        """,
        COMPANY_A,
    )
    if not rows:
        raise AssertionError("Phase-eight Other floating detail is missing")
    return rows[0][0]


def _ensure_opening_import(branch: str, detail: str) -> str:
    import frappe

    reference = "ASOUD-P8-CONTROLLED-OPENING-V1"
    existing = frappe.db.exists(
        "ASOUD Opening Balance Import",
        {"company": COMPANY_A, "external_reference": reference, "docstatus": 1},
    )
    if existing:
        return existing
    doc = frappe.get_doc(
        {
            "doctype": "ASOUD Opening Balance Import",
            "company": COMPANY_A,
            "branch": branch,
            "posting_date": OPENING_DATE,
            "external_reference": reference,
            "remarks": "Controlled phase-eight opening balance migration",
            "entries": [
                {
                    "account": _account("111001"),
                    "floating_detail": detail,
                    "debit": 1234,
                    "description": "Controlled imported cash balance",
                },
                {
                    "account": _account("310001"),
                    "credit": 1234,
                    "description": "Controlled imported capital balance",
                },
            ],
        }
    ).insert(ignore_permissions=True)
    doc.submit()
    return doc.name


def _assert_report_controls(reports: dict[str, dict]) -> None:
    journal = reports["journal"]
    if journal["totals"]["difference"] != 0:
        raise AssertionError("Standard journal output is not balanced")
    trial = reports["trial_balance"]["totals"]
    if trial["opening_debit"] != trial["opening_credit"]:
        raise AssertionError("Trial-balance opening columns do not reconcile")
    if trial["period_debit"] != trial["period_credit"]:
        raise AssertionError("Trial-balance period columns do not reconcile")
    if trial["closing_debit"] != trial["closing_credit"]:
        raise AssertionError("Trial-balance closing columns do not reconcile")
    balance = reports["balance_sheet"]["totals"]
    profit = reports["profit_and_loss"]["totals"]
    if round(balance["difference"] - profit["net_profit"], 2) != 0:
        raise AssertionError(
            "Balance-sheet equation does not reconcile to unclosed current profit"
        )
    if not reports["floating_detail_ledger"]["rows"]:
        raise AssertionError("Floating-detail standard ledger is empty")
    for report in reports.values():
        if len(report["checksum"]) != 64 or report["schema_version"] != "1.0":
            raise AssertionError("Canonical report contract or checksum is invalid")


def _assert_permission_denial() -> None:
    import frappe

    from asoud_iran.services.standard_reports import build_standard_report

    frappe.set_user(USERS["accountant"])
    try:
        build_standard_report(
            company=COMPANY_A,
            report_type="trial_balance",
            from_date=FROM_DATE,
            to_date=TO_DATE,
            branch=_branch(COMPANY_A),
        )
    except frappe.PermissionError:
        pass
    else:
        raise AssertionError("Limited accountant read a forbidden company report")
    finally:
        frappe.set_user("Administrator")


def run_phase_eight_acceptance() -> dict:
    import frappe

    from asoud_iran.services.standard_reports import (
        build_standard_report,
        render_csv,
        render_pdf,
        render_xlsx,
    )

    frappe.only_for("System Manager")
    frappe.set_user("Administrator")
    branch = _branch(COMPANY_A)
    opening_import = _ensure_opening_import(branch, _other_detail())
    opening = frappe.db.get_value(
        "ASOUD Opening Balance Import",
        opening_import,
        ["journal_entry", "total_debit", "total_credit", "status"],
        as_dict=True,
    )
    if (
        not opening.journal_entry
        or opening.total_debit != opening.total_credit
        or opening.status != "Imported"
    ):
        raise AssertionError("Controlled opening balance import was not posted")
    if not frappe.db.exists(
        "ASOUD Accounting Document", {"source_name": opening.journal_entry}
    ):
        raise AssertionError("Opening balance journal is missing from the registry")

    started = time.perf_counter()
    reports = {
        report_type: build_standard_report(
            company=COMPANY_A,
            report_type=report_type,
            from_date=FROM_DATE,
            to_date=TO_DATE,
        )
        for report_type in (
            "journal",
            "general_ledger",
            "floating_detail_ledger",
            "trial_balance",
            "balance_sheet",
            "profit_and_loss",
        )
    }
    elapsed = time.perf_counter() - started
    if elapsed > 5:
        raise AssertionError(f"Six standard reports exceeded the 5-second pilot budget: {elapsed}")
    _assert_report_controls(reports)
    repeated = build_standard_report(
        company=COMPANY_A,
        report_type="trial_balance",
        from_date=FROM_DATE,
        to_date=TO_DATE,
    )
    if repeated["checksum"] != reports["trial_balance"]["checksum"]:
        raise AssertionError("Repeated report produced a different canonical checksum")

    journal = reports["journal"]
    csv_bytes = render_csv(journal)
    xlsx_bytes = render_xlsx(journal)
    pdf_bytes = render_pdf(journal)
    if not csv_bytes.startswith(b"\xef\xbb\xbf"):
        raise AssertionError("CSV output is not UTF-8 BOM")
    if not xlsx_bytes.startswith(b"PK"):
        raise AssertionError("Excel output is not a valid OOXML archive")
    if not pdf_bytes.startswith(b"%PDF"):
        raise AssertionError("PDF output is invalid")
    _assert_permission_denial()
    frappe.db.commit()
    return {
        "status": "passed",
        "opening_import": opening_import,
        "opening_journal": opening.journal_entry,
        "reports": {
            key: {
                "rows": value["row_count"],
                "checksum": value["checksum"],
            }
            for key, value in reports.items()
        },
        "exports": {
            "csv_bytes": len(csv_bytes),
            "xlsx_bytes": len(xlsx_bytes),
            "pdf_bytes": len(pdf_bytes),
        },
        "performance_seconds": round(elapsed, 3),
        "permission": "passed",
        "registry": "passed",
        "idempotency": "passed",
    }
