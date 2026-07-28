from __future__ import annotations

from asoud_core.phase_one_demo import COMPANY_A


def restoration_fingerprint() -> dict:
    import frappe

    from asoud_iran.services.standard_reports import build_standard_report

    frappe.set_user("Administrator")
    if not frappe.db.exists("Company", COMPANY_A):
        raise AssertionError("Restored site is missing the controlled company")
    report = build_standard_report(
        company=COMPANY_A,
        report_type="trial_balance",
        from_date="2026-03-21",
        to_date="2027-05-31",
    )
    return {
        "company_count": frappe.db.count("Company"),
        "gl_entry_count": frappe.db.count(
            "GL Entry", {"company": COMPANY_A, "is_cancelled": 0}
        ),
        "opening_import_count": frappe.db.count(
            "ASOUD Opening Balance Import",
            {"company": COMPANY_A, "docstatus": 1},
        ),
        "trial_balance_checksum": report["checksum"],
        "trial_balance_rows": report["row_count"],
    }
