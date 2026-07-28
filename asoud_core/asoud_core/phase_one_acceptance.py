from __future__ import annotations

from typing import Any

from asoud_core.phase_one_demo import (
    COMPANY_A,
    COMPANY_B,
    FISCAL_YEAR_1405,
    TRANSACTION_DOCTYPES,
    USERS,
)


def _leaf_account(company: str, root_type: str) -> str:
    import frappe

    accounts = frappe.get_all(
        "Account",
        filters={"company": company, "root_type": root_type, "is_group": 0},
        pluck="name",
        order_by="name",
        limit=1,
    )
    if not accounts:
        frappe.throw(f"No leaf {root_type} account exists for {company}")
    return accounts[0]


def _ensure_journal_entry(
    marker: str,
    *,
    company: str,
    branch: str,
    posting_date: str,
    amount: int,
) -> str:
    import frappe

    existing = frappe.db.exists("Journal Entry", {"user_remark": marker, "docstatus": 1})
    if existing:
        return existing
    debit_account = _leaf_account(company, "Asset")
    credit_account = _leaf_account(company, "Equity")
    entry = frappe.get_doc(
        {
            "doctype": "Journal Entry",
            "voucher_type": "Journal Entry",
            "company": company,
            "posting_date": posting_date,
            "asoud_branch": branch,
            "user_remark": marker,
            "accounts": [
                {
                    "account": debit_account,
                    "debit_in_account_currency": amount,
                    "credit_in_account_currency": 0,
                },
                {
                    "account": credit_account,
                    "debit_in_account_currency": 0,
                    "credit_in_account_currency": amount,
                },
            ],
        }
    )
    entry.insert(ignore_permissions=True)
    entry.submit()
    return entry.name


def _visible_markers(user: str, markers: set[str]) -> set[str]:
    import frappe

    frappe.set_user(user)
    return set(
        frappe.get_list(
            "Journal Entry",
            filters={"user_remark": ["in", sorted(markers)], "docstatus": 1},
            pluck="user_remark",
        )
    )


def _assert_context_matrix(branches: dict[str, str]) -> None:
    import frappe

    from asoud_core.api import accessible_contexts, active_context, set_active_context

    expected = {
        USERS["holding_manager"]: {
            (COMPANY_A, None),
            (COMPANY_A, branches["a_hq"]),
            (COMPANY_A, branches["a_ops"]),
            (COMPANY_B, None),
            (COMPANY_B, branches["b_hq"]),
            (COMPANY_B, branches["b_ops"]),
        },
        USERS["company_manager"]: {
            (COMPANY_A, None),
            (COMPANY_A, branches["a_hq"]),
            (COMPANY_A, branches["a_ops"]),
        },
        USERS["branch_manager"]: {(COMPANY_A, branches["a_hq"])},
        USERS["accountant"]: {(COMPANY_B, branches["b_hq"])},
    }
    for user, wanted in expected.items():
        frappe.set_user(user)
        actual = {
            (row["company"], row["branch"])
            for row in accessible_contexts()
            if row["company"] in {COMPANY_A, COMPANY_B}
        }
        if actual != wanted:
            raise AssertionError(f"Context matrix mismatch for {user}: {actual} != {wanted}")

    frappe.set_user(USERS["branch_manager"])
    set_active_context(COMPANY_A, branches["a_hq"])
    selected = active_context()
    if not selected or selected.company != COMPANY_A or selected.branch != branches["a_hq"]:
        raise AssertionError("Active company/branch was not persisted")
    try:
        set_active_context(COMPANY_B, branches["b_hq"])
    except frappe.ValidationError:
        pass
    else:
        raise AssertionError("Out-of-scope active context was accepted")


def _assert_native_user_permissions() -> None:
    import frappe

    expected = {
        USERS["holding_manager"]: {COMPANY_A, COMPANY_B},
        USERS["company_manager"]: {COMPANY_A},
        USERS["branch_manager"]: {COMPANY_A},
        USERS["accountant"]: {COMPANY_B},
    }
    for user, wanted in expected.items():
        actual = set(
            frappe.get_all(
                "User Permission",
                filters={
                    "user": user,
                    "allow": "Company",
                    "asoud_managed": 1,
                },
                pluck="for_value",
            )
        )
        if actual != wanted:
            raise AssertionError(f"Native User Permission mismatch for {user}")


def _assert_numbering_and_document_permissions(branches: dict[str, str]) -> dict[str, str]:
    import frappe

    from asoud_core.services.journal_numbering import run_final_numbering

    frappe.set_user("Administrator")
    entries = {
        "a_hq": _ensure_journal_entry(
            "ASOUD-PHASE1-A-HQ-LATE",
            company=COMPANY_A,
            branch=branches["a_hq"],
            posting_date="2026-04-03",
            amount=1_300_000,
        ),
        "a_ops": _ensure_journal_entry(
            "ASOUD-PHASE1-A-OPS-EARLY",
            company=COMPANY_A,
            branch=branches["a_ops"],
            posting_date="2026-04-01",
            amount=1_100_000,
        ),
        "b_hq": _ensure_journal_entry(
            "ASOUD-PHASE1-B-HQ",
            company=COMPANY_B,
            branch=branches["b_hq"],
            posting_date="2026-04-02",
            amount=1_200_000,
        ),
    }
    a_rows = frappe.get_all(
        "Journal Entry",
        filters={"name": ["in", [entries["a_hq"], entries["a_ops"]]]},
        fields=[
            "name",
            "posting_date",
            "asoud_temporary_number",
            "asoud_final_number",
        ],
    )
    if any(not row.asoud_temporary_number for row in a_rows):
        raise AssertionError("A submitted Journal Entry has no temporary number")
    temporary_before = {row.name: row.asoud_temporary_number for row in a_rows}
    if any(not row.asoud_final_number for row in a_rows):
        run_final_numbering(
            company=COMPANY_A,
            fiscal_year=FISCAL_YEAR_1405,
            from_date="2026-04-01",
            to_date="2026-04-30",
            reason="Phase-one acceptance numbering",
        )
    a_rows = frappe.get_all(
        "Journal Entry",
        filters={"name": ["in", [entries["a_hq"], entries["a_ops"]]]},
        fields=[
            "name",
            "posting_date",
            "asoud_temporary_number",
            "asoud_final_number",
        ],
        order_by="posting_date asc",
    )
    if {row.name: row.asoud_temporary_number for row in a_rows} != temporary_before:
        raise AssertionError("Final numbering changed a temporary number")
    if not (a_rows[0].asoud_final_number < a_rows[1].asoud_final_number):
        raise AssertionError("Final numbering is not ordered by posting date")

    markers = {
        "ASOUD-PHASE1-A-HQ-LATE",
        "ASOUD-PHASE1-A-OPS-EARLY",
        "ASOUD-PHASE1-B-HQ",
    }
    expected = {
        USERS["holding_manager"]: markers,
        USERS["company_manager"]: {
            "ASOUD-PHASE1-A-HQ-LATE",
            "ASOUD-PHASE1-A-OPS-EARLY",
        },
        USERS["branch_manager"]: {"ASOUD-PHASE1-A-HQ-LATE"},
        USERS["accountant"]: {"ASOUD-PHASE1-B-HQ"},
    }
    for user, wanted in expected.items():
        actual = _visible_markers(user, markers)
        if actual != wanted:
            raise AssertionError(f"Document permission mismatch for {user}: {actual}")
    return entries


def _assert_period_lock(branches: dict[str, str]) -> str:
    import frappe

    from asoud_core.services.journal_numbering import lock_period

    frappe.set_user("Administrator")
    lock = frappe.db.exists(
        "ASOUD Period Lock",
        {
            "company": COMPANY_A,
            "from_date": "2026-06-01",
            "to_date": "2026-06-30",
            "docstatus": 1,
        },
    )
    if not lock:
        lock = lock_period(
            company=COMPANY_A,
            fiscal_year=FISCAL_YEAR_1405,
            from_date="2026-06-01",
            to_date="2026-06-30",
        )
        frappe.db.commit()
    try:
        _ensure_journal_entry(
            "ASOUD-PHASE1-MUST-BE-BLOCKED",
            company=COMPANY_A,
            branch=branches["a_hq"],
            posting_date="2026-06-15",
            amount=100_000,
        )
    except frappe.ValidationError:
        frappe.db.rollback()
    else:
        raise AssertionError("A Journal Entry was accepted inside a locked period")
    return lock


def run_phase_one_acceptance() -> dict[str, Any]:
    """Run persistent, repeatable Frappe acceptance checks for the phase-one core."""
    import frappe

    from asoud_core.phase_one_demo import ensure_phase_one_demo

    frappe.only_for("System Manager")
    data = ensure_phase_one_demo()
    branches = data["branches"]
    try:
        _assert_context_matrix(branches)
        frappe.set_user("Administrator")
        _assert_native_user_permissions()
        entries = _assert_numbering_and_document_permissions(branches)
        lock = _assert_period_lock(branches)
        missing_fields = [
            doctype
            for doctype in TRANSACTION_DOCTYPES
            if not frappe.get_meta(doctype).has_field("asoud_branch")
        ]
        if missing_fields:
            raise AssertionError(f"Missing ASOUD Branch field: {missing_fields}")
        result = {
            "status": "passed",
            "contexts": 4,
            "permission_profiles": 4,
            "journal_entries": entries,
            "period_lock": lock,
        }
        frappe.set_user("Administrator")
        frappe.db.commit()
        return result
    finally:
        frappe.set_user("Administrator")
