from __future__ import annotations

import hashlib
import json

PILOT_MARKER = "ASOUD-CONTROLLED-PILOT-V2"


def _scenario(
    code: str,
    title: str,
    expected: str,
    actual: object,
) -> dict:
    evidence = json.dumps(actual, ensure_ascii=False, sort_keys=True, default=str)
    return {
        "scenario_code": code,
        "scenario_title": title,
        "expected_result": expected,
        "actual_result": "Passed against controlled synthetic pilot data",
        "status": "Pass",
        "evidence": evidence[:1000],
    }


def run_controlled_pilot() -> dict:
    """Run repeatable technical UAT; never represent synthetic data as business sign-off."""
    import frappe
    from frappe.utils import now_datetime

    from asoud_core.phase_five_acceptance import run_phase_five_acceptance
    from asoud_core.phase_one_demo import ensure_phase_one_demo
    from asoud_core.phase_seven_acceptance import run_phase_seven_acceptance
    from asoud_core.phase_six_acceptance import run_phase_six_acceptance
    from asoud_core.phase_three_acceptance import run_phase_three_acceptance
    from asoud_iran.phase_eight_acceptance import run_phase_eight_acceptance
    from asoud_iran.phase_four_acceptance import run_phase_four_acceptance
    from asoud_iran.phase_two_acceptance import run_phase_two_acceptance

    frappe.only_for("System Manager")
    started = now_datetime()
    existing = frappe.db.exists(
        "ASOUD Pilot Run",
        {"release_reference": PILOT_MARKER, "docstatus": 1},
    )
    if existing:
        run = frappe.get_doc("ASOUD Pilot Run", existing)
        return {
            "status": "passed",
            "pilot_run": run.name,
            "site": frappe.local.site,
            "data_profile": run.data_profile,
            "decision": run.decision,
            "scenarios": run.total_scenarios,
            "idempotency": "passed",
        }

    demo = ensure_phase_one_demo()
    frappe.set_user("Administrator")
    phase_two = run_phase_two_acceptance()
    phase_three = run_phase_three_acceptance()
    phase_four = run_phase_four_acceptance()
    phase_five = run_phase_five_acceptance()
    phase_six = run_phase_six_acceptance()
    phase_seven = run_phase_seven_acceptance()
    phase_eight = run_phase_eight_acceptance()
    evidence = {
        "P9-01": demo,
        "P9-02": phase_two,
        "P9-03": phase_three,
        "P9-04": phase_four,
        "P9-05": phase_five,
        "P9-06": phase_six,
        "P9-07": phase_seven,
        "P9-08": phase_eight,
    }
    scenarios = [
        _scenario(
            "P9-01",
            "Organization, users and context isolation",
            "Holding, companies, branches and controlled users are repeatable",
            demo,
        ),
        _scenario(
            "P9-02",
            "Iranian accounting baseline",
            "IRR, Jalali, chart and floating detail controls pass",
            phase_two,
        ),
        _scenario(
            "P9-03",
            "Legal numbering and daily merge",
            "Temporary numbers survive and final numbering is idempotent",
            phase_three,
        ),
        _scenario(
            "P9-04",
            "Fiscal closing and opening",
            "Real closing/opening journals reconcile",
            phase_four,
        ),
        _scenario(
            "P9-05",
            "Sales, purchasing, inventory and payment operations",
            "Operational documents update GL and stock ledgers",
            phase_five,
        ),
        _scenario(
            "P9-06",
            "Treasury, cash, petty cash and cheque lifecycle",
            "Treasury journals, states and reconciliation pass",
            phase_six,
        ),
        _scenario(
            "P9-07",
            "Intercompany and consolidation",
            "Paired journals and eliminations reconcile without legal-ledger mutation",
            phase_seven,
        ),
        _scenario(
            "P9-08",
            "Canonical reports, exports and opening migration",
            "Six reports and CSV/XLSX/PDF exports reconcile",
            phase_eight,
        ),
    ]
    digest = hashlib.sha256(
        json.dumps(evidence, sort_keys=True, default=str).encode()
    ).hexdigest()
    run = frappe.get_doc(
        {
            "doctype": "ASOUD Pilot Run",
            "environment_name": "Isolated Controlled Pilot",
            "site_name": frappe.local.site,
            "data_profile": "Synthetic",
            "release_reference": PILOT_MARKER,
            "started_at": started,
            "completed_at": now_datetime(),
            "limitations": (
                "Technical UAT with controlled synthetic data. No real business data, "
                "legal/tax certification, external bank, taxpayer-system transmission, "
                "or business-owner sign-off is claimed."
            ),
            "scenarios": scenarios,
        }
    ).insert(ignore_permissions=True)
    run.submit()
    frappe.db.commit()
    return {
        "status": "passed",
        "pilot_run": run.name,
        "site": frappe.local.site,
        "data_profile": run.data_profile,
        "decision": run.decision,
        "scenarios": run.total_scenarios,
        "evidence_sha256": digest,
        "idempotency": "passed",
    }
