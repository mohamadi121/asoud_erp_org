from __future__ import annotations

from asoud_core.phase_one_demo import COMPANY_A, FISCAL_YEAR_1405


def _accounts():
    import frappe

    rows = frappe.db.sql(
        """
        select acc.name, acc.root_type
          from `tabAccount` acc
         where acc.company=%s and acc.is_group=0
           and acc.root_type in ('Asset', 'Equity')
           and not exists (
               select 1 from `tabASOUD Account Detail Rule` rule
                where rule.account=acc.name and rule.company=acc.company
                  and rule.enabled=1 and rule.required=1
           )
         order by acc.root_type, acc.name
        """,
        COMPANY_A,
        as_dict=True,
    )
    by_root = {row.root_type: row.name for row in rows}
    if set(by_root) != {"Asset", "Equity"}:
        # Iranian setup requires dimensions on every managed leaf. Reuse a
        # configured detail in that case.
        asset = frappe.db.get_value(
            "Account", {"company": COMPANY_A, "account_number": "111001"}, "name"
        )
        equity = frappe.db.get_value(
            "Account", {"company": COMPANY_A, "account_number": "310001"}, "name"
        )
        detail = frappe.db.get_value(
            "ASOUD Floating Detail Company",
            {"company": COMPANY_A, "enabled": 1},
            "parent",
        )
        return asset, equity, detail
    return by_root["Asset"], by_root["Equity"], None


def _entry(marker: str, posting_date: str, amount: int):
    import frappe

    existing = frappe.db.exists("Journal Entry", {"user_remark": marker, "docstatus": 1})
    if existing:
        return existing
    debit, credit, detail = _accounts()
    rows = [
        {"account": debit, "debit_in_account_currency": amount},
        {"account": credit, "credit_in_account_currency": amount},
    ]
    if detail:
        rows[0]["asoud_floating_detail"] = detail
    return (
        frappe.get_doc(
            {
                "doctype": "Journal Entry",
                "voucher_type": "Journal Entry",
                "company": COMPANY_A,
                "posting_date": posting_date,
                "user_remark": marker,
                "accounts": rows,
            }
        )
        .insert(ignore_permissions=True)
        .submit()
        .name
    )


def run_phase_three_acceptance() -> dict:
    import frappe

    from asoud_core.services.journal_numbering import run_final_numbering

    frappe.only_for("System Manager")
    frappe.set_user("Administrator")
    first = _entry("ASOUD-PHASE3-MERGE-A", "2026-09-10", 101)
    second = _entry("ASOUD-PHASE3-MERGE-B", "2026-09-10", 102)
    registry = frappe.get_all(
        "ASOUD Accounting Document",
        filters={"source_name": ["in", [first, second]]},
        fields=["name", "source_name", "temporary_number", "final_number"],
        order_by="source_name",
    )
    if len(registry) != 2 or any(not row.temporary_number for row in registry):
        raise AssertionError("Cross-DocType registry did not capture submitted documents")
    temporary_before = {row.name: row.temporary_number for row in registry}
    consolidation = frappe.db.exists(
        "ASOUD Document Consolidation",
        {"company": COMPANY_A, "posting_date": "2026-09-10", "docstatus": 1},
    )
    if not consolidation:
        consolidation = frappe.get_doc(
            {
                "doctype": "ASOUD Document Consolidation",
                "company": COMPANY_A,
                "posting_date": "2026-09-10",
                "reason": "Phase-three same-day selected consolidation",
                "documents": [{"accounting_document": row.name} for row in registry],
            }
        ).insert(ignore_permissions=True)
        consolidation.submit()
        consolidation = consolidation.name
    batch = run_final_numbering(
        company=COMPANY_A,
        fiscal_year=FISCAL_YEAR_1405,
        from_date="2026-09-10",
        to_date="2026-09-10",
        reason="Phase-three aggregate numbering",
    )
    repeated = run_final_numbering(
        company=COMPANY_A,
        fiscal_year=FISCAL_YEAR_1405,
        from_date="2026-09-10",
        to_date="2026-09-10",
        reason="Phase-three aggregate numbering",
    )
    if batch != repeated:
        raise AssertionError("Numbering idempotency key did not return the completed batch")
    after = frappe.get_all(
        "ASOUD Accounting Document",
        filters={"name": ["in", list(temporary_before)]},
        fields=["name", "temporary_number", "final_number", "consolidation"],
    )
    if {row.temporary_number for row in after} != set(temporary_before.values()):
        raise AssertionError("Temporary numbers changed")
    if len({row.final_number for row in after}) != 1:
        raise AssertionError("Consolidated sources did not share one final legal number")
    if any(row.consolidation != consolidation for row in after):
        raise AssertionError("Consolidation drill-down link is missing")
    if frappe.db.count(
        "ASOUD Number History", {"accounting_document": ["in", list(temporary_before)]}
    ) < 2:
        raise AssertionError("General numbering history is incomplete")
    required_fields = {"asoud_temporary_number", "asoud_final_number", "asoud_numbering_status"}
    supported = (
        "Journal Entry",
        "Sales Invoice",
        "Purchase Invoice",
        "Payment Entry",
        "Stock Entry",
        "Delivery Note",
        "Purchase Receipt",
    )
    missing = {
        doctype: sorted(required_fields - {field.fieldname for field in frappe.get_meta(doctype).fields})
        for doctype in supported
        if not required_fields <= {field.fieldname for field in frappe.get_meta(doctype).fields}
    }
    if missing:
        raise AssertionError(f"Numbering fields missing from supported documents: {missing}")
    frappe.db.commit()
    return {
        "status": "passed",
        "registry_documents": len(after),
        "numbering_units": 1,
        "batch": batch,
        "consolidation": consolidation,
        "idempotency": "passed",
        "history": "passed",
    }
