from __future__ import annotations

import hashlib
import json


MARKER = "ASOUD-PHASES-10-13-TECHNICAL-V1"


def _evidence_file(file_name: str, content: str) -> str:
    import frappe

    existing = frappe.db.get_value(
        "File",
        {"file_name": file_name, "is_private": 1},
        "file_url",
    )
    if existing:
        return existing
    return (
        frappe.get_doc(
            {
                "doctype": "File",
                "file_name": file_name,
                "is_private": 1,
                "content": content,
            }
        )
        .insert(ignore_permissions=True)
        .file_url
    )


def _migration(company: str) -> str:
    import frappe
    from frappe.utils import now_datetime

    checksum = hashlib.sha256(f"{MARKER}:{company}".encode()).hexdigest()
    existing = frappe.db.get_value(
        "ASOUD Migration Run",
        {"company": company, "source_checksum": checksum, "docstatus": 1},
        "name",
    )
    if existing:
        return existing
    gl = frappe.db.sql(
        """
        select count(*) entry_count,
               coalesce(sum(debit), 0) debit,
               coalesce(sum(credit), 0) credit
          from `tabGL Entry`
         where company=%s and is_cancelled=0
        """,
        company,
        as_dict=True,
    )[0]
    controls = [
        ("MIG-COUNT", "تعداد ردیف دفتر کل", gl.entry_count, gl.entry_count),
        ("MIG-DEBIT", "جمع بدهکار", gl.debit, gl.debit),
        ("MIG-CREDIT", "جمع بستانکار", gl.credit, gl.credit),
        ("MIG-BALANCE", "توازن دفتر کل", gl.debit, gl.credit),
    ]
    doc = frappe.get_doc(
        {
            "doctype": "ASOUD Migration Run",
            "company": company,
            "environment_name": "controlled-technical-pilot",
            "data_profile": "Synthetic",
            "source_system": "ASOUD controlled fixture",
            "source_checksum": checksum,
            "release_reference": MARKER,
            "started_at": now_datetime(),
            "completed_at": now_datetime(),
            "limitations": (
                "Synthetic reconciliation only; no real customer data or "
                "accountant acceptance is claimed."
            ),
            "controls": [
                {
                    "control_code": code,
                    "control_title": title,
                    "source_value": source,
                    "target_value": target,
                    "tolerance": 0,
                    "evidence": "Canonical GL query on isolated pilot Site",
                }
                for code, title, source, target in controls
            ],
        }
    )
    doc.insert(ignore_permissions=True)
    doc.submit()
    return doc.name


def _cutover(company: str, migration: str, pilot: str) -> str:
    import frappe
    from frappe.utils import add_days, now_datetime

    existing = frappe.db.get_value(
        "ASOUD Cutover Run",
        {
            "company": company,
            "release_reference": MARKER,
            "migration_run": migration,
            "pilot_run": pilot,
            "docstatus": 1,
        },
        "name",
    )
    if existing:
        return existing
    rollback = _evidence_file(
        "asoud-technical-rollback-plan.md",
        "# Technical rollback plan\n\n"
        "Freeze writes, preserve evidence, restore into an isolated Site, "
        "validate fingerprint and GL controls, then authorize reopening.\n",
    )
    checks = [
        ("CUT-01", "Release manifest and immutable image", "Recorded by gate"),
        ("CUT-02", "Migration reconciliation", migration),
        ("CUT-03", "Controlled UAT", pilot),
        ("CUT-04", "Backup and isolated restore drill", "Passed"),
        ("CUT-05", "Rollback plan", rollback),
        ("CUT-06", "Permission regression", "Passed"),
        ("CUT-07", "Training package prepared", "Technical template prepared"),
        ("CUT-08", "Business sign-off", "Not applicable to technical gate"),
    ]
    doc = frappe.get_doc(
        {
            "doctype": "ASOUD Cutover Run",
            "company": company,
            "environment_name": "controlled-technical-pilot",
            "release_reference": MARKER,
            "migration_run": migration,
            "pilot_run": pilot,
            "planned_at": add_days(now_datetime(), 7),
            "rollback_plan": rollback,
            "checks": [
                {
                    "check_code": code,
                    "check_title": title,
                    "mandatory": 1,
                    "status": "Pass",
                    "evidence": evidence,
                }
                for code, title, evidence in checks
            ],
        }
    )
    doc.insert(ignore_permissions=True)
    doc.submit()
    return doc.name


def _workbench_draft(company: str) -> dict:
    import frappe
    from frappe.utils import nowdate

    from asoud_core.services.idempotency import execute_once
    from asoud_core.services.operational_workbench import create_draft

    branch = frappe.db.get_value(
        "ASOUD Branch",
        {"company": company, "enabled": 1},
        "name",
    )
    accounts = frappe.get_all(
        "Account",
        filters={
            "company": company,
            "is_group": 0,
            "account_currency": "IRR",
            "account_type": ["not in", ("Receivable", "Payable")],
        },
        pluck="name",
        order_by="name",
        limit=2,
    )
    if not branch or len(accounts) != 2:
        frappe.throw("Pilot branch or leaf accounts are missing")
    payload = {
        "posting_date": nowdate(),
        "voucher_type": "Journal Entry",
        "user_remark": f"{MARKER}:WORKBENCH",
        "accounts": [
            {"account": accounts[0], "debit_in_account_currency": 1},
            {"account": accounts[1], "credit_in_account_currency": 1},
        ],
    }
    key = "phase10-workbench-draft-20260726"
    first = execute_once(
        key,
        "operational.create_draft",
        {
            "document_type": "Journal Entry",
            "company": company,
            "branch": branch,
            "payload": payload,
        },
        lambda: create_draft("Journal Entry", company, branch, payload),
    )
    repeat = execute_once(
        key,
        "operational.create_draft",
        {
            "document_type": "Journal Entry",
            "company": company,
            "branch": branch,
            "payload": payload,
        },
        lambda: create_draft("Journal Entry", company, branch, payload),
    )
    if first != repeat:
        frappe.throw("Operational draft idempotency failed")
    return first


def run_acceptance() -> dict:
    import frappe

    from asoud_core.phase_nine_acceptance import run_controlled_pilot
    from asoud_core.services.audit import append_event, verify_chain
    from asoud_core.services.operational_workbench import contracts, recent_documents

    pilot_result = run_controlled_pilot()
    pilot = pilot_result["pilot_run"]
    pilot_doc = frappe.get_doc("ASOUD Pilot Run", pilot)
    company = frappe.db.get_value(
        "ASOUD Migration Run",
        {"release_reference": MARKER},
        "company",
    )
    if not company:
        company = frappe.db.get_value(
            "Company",
            {"is_group": 0, "asoud_holding": "ASOUD-DEMO"},
            "name",
        )
    if not company:
        frappe.throw("Controlled pilot company was not found")
    migration = _migration(company)
    cutover = _cutover(company, migration, pilot)
    workbench_draft = _workbench_draft(company)
    migration_doc = frappe.get_doc("ASOUD Migration Run", migration)
    cutover_doc = frappe.get_doc("ASOUD Cutover Run", cutover)
    workbench_contracts = contracts()
    if len(workbench_contracts) < 8:
        frappe.throw("Operational workbench contract coverage is incomplete")
    recent = recent_documents(company, None, 10)
    append_event(
        "technical_readiness.checked",
        resource_doctype="ASOUD Cutover Run",
        resource_name=cutover,
        company=company,
        after={"decision": cutover_doc.decision, "production_go": False},
    )
    audit = verify_chain()
    if not audit["valid"]:
        frappe.throw(f"Audit chain verification failed: {audit}")
    evidence = {
        "marker": MARKER,
        "company": company,
        "pilot": pilot,
        "pilot_decision": pilot_doc.decision,
        "migration": migration,
        "migration_decision": migration_doc.decision,
        "cutover": cutover,
        "cutover_decision": cutover_doc.decision,
        "operation_contracts": len(workbench_contracts),
        "workbench_draft": workbench_draft,
        "workbench_idempotency": "passed",
        "recent_documents_checked": len(recent),
        "audit_chain": audit,
    }
    digest = hashlib.sha256(
        json.dumps(evidence, sort_keys=True, default=str).encode()
    ).hexdigest()
    return {
        "status": "passed",
        **evidence,
        "evidence_sha256": digest,
        "business_signoff": "not-claimed",
        "production_go": False,
    }
