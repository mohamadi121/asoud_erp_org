from __future__ import annotations

from collections import defaultdict
import hashlib
import json
from typing import Any

TRANSFER_STATES = ("Requested", "Source Approved", "Completed", "Reversed")
TRANSFER_TYPES = ("Money", "Goods", "Service", "Expense", "Asset", "Journal")


def elimination_lines(
    amount: float,
    source_code: str,
    destination_code: str,
) -> list[dict[str, float | str]]:
    """Return a balanced elimination without touching either legal ledger."""
    return [
        {"account_code": source_code, "debit": 0.0, "credit": float(amount)},
        {"account_code": destination_code, "debit": float(amount), "credit": 0.0},
    ]


def aggregate_consolidation(
    balances: list[dict[str, Any]],
    adjustments: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    """Aggregate canonical balances and adjustments by holding account code."""
    rows: dict[str, dict[str, Any]] = defaultdict(
        lambda: {
            "account_code": "",
            "account_title": "",
            "root_type": "",
            "raw_balance": 0.0,
            "elimination": 0.0,
            "consolidated_balance": 0.0,
        }
    )
    for item in balances:
        code = str(item["account_code"])
        row = rows[code]
        row.update(
            {
                "account_code": code,
                "account_title": item.get("account_title") or code,
                "root_type": item.get("root_type") or "",
            }
        )
        row["raw_balance"] += float(item.get("balance") or 0)
    for item in adjustments:
        code = str(item["account_code"])
        row = rows[code]
        row["account_code"] = code
        row["account_title"] = row["account_title"] or item.get("account_title") or code
        row["root_type"] = row["root_type"] or item.get("root_type") or ""
        row["elimination"] += float(item.get("debit") or 0) - float(
            item.get("credit") or 0
        )
    for row in rows.values():
        row["raw_balance"] = round(row["raw_balance"], 2)
        row["elimination"] = round(row["elimination"], 2)
        row["consolidated_balance"] = round(
            row["raw_balance"] + row["elimination"], 2
        )
    return sorted(rows.values(), key=lambda row: row["account_code"])


def _account(name: str, company: str):
    import frappe

    row = frappe.db.get_value(
        "Account",
        name,
        ["name", "company", "is_group", "root_type", "account_name"],
        as_dict=True,
    )
    if not row or row.company != company or row.is_group:
        frappe.throw("Every intercompany account must be a leaf account of its company")
    return row


def _branch(name: str, company: str) -> None:
    import frappe

    row = frappe.db.get_value(
        "ASOUD Branch", name, ["company", "enabled"], as_dict=True
    )
    if not row or row.company != company or not row.enabled:
        frappe.throw("Intercompany branch must be enabled and belong to its company")


def _assert_context(user: str, company: str, branch: str) -> None:
    import frappe

    from asoud_core.permissions import can_access_context

    if not can_access_context(user, company, branch):
        frappe.throw("Not permitted for this company and branch", frappe.PermissionError)


def validate_intercompany_transfer(doc) -> None:
    import frappe
    from frappe.utils import flt

    if doc.source_company == doc.destination_company:
        frappe.throw("Source and destination companies must be different")
    source_holding = frappe.db.get_value(
        "Company", doc.source_company, "asoud_holding"
    )
    destination_holding = frappe.db.get_value(
        "Company", doc.destination_company, "asoud_holding"
    )
    if not source_holding or source_holding != destination_holding:
        frappe.throw("Both companies must belong to the same enabled holding")
    if doc.holding and doc.holding != source_holding:
        frappe.throw("Transfer holding does not match the selected companies")
    doc.holding = source_holding
    if doc.transfer_type not in TRANSFER_TYPES:
        frappe.throw("Unsupported intercompany transfer type")
    if flt(doc.amount) <= 0:
        frappe.throw("Intercompany amount must be greater than zero")
    _branch(doc.source_branch, doc.source_company)
    _branch(doc.destination_branch, doc.destination_company)
    for fieldname, company in (
        ("source_settlement_account", doc.source_company),
        ("source_intercompany_account", doc.source_company),
        ("destination_settlement_account", doc.destination_company),
        ("destination_intercompany_account", doc.destination_company),
    ):
        _account(doc.get(fieldname), company)
    for account_field, detail_field, company in (
        (
            "source_settlement_account",
            "source_settlement_detail",
            doc.source_company,
        ),
        (
            "source_intercompany_account",
            "source_intercompany_detail",
            doc.source_company,
        ),
        (
            "destination_settlement_account",
            "destination_settlement_detail",
            doc.destination_company,
        ),
        (
            "destination_intercompany_account",
            "destination_intercompany_detail",
            doc.destination_company,
        ),
    ):
        _validate_account_detail(doc.get(account_field), doc.get(detail_field), company)
    if doc.source_settlement_account == doc.source_intercompany_account:
        frappe.throw("Source settlement and intercompany accounts must differ")
    if doc.destination_settlement_account == doc.destination_intercompany_account:
        frappe.throw("Destination settlement and intercompany accounts must differ")
    if doc.transfer_type == "Goods":
        _validate_supporting_voucher(
            doc.source_voucher_type,
            doc.source_voucher,
            doc.source_company,
            doc.amount,
            doc.posting_date,
            transfer_name=doc.name,
            voucher_field="source_voucher",
            voucher_type_field="source_voucher_type",
            allowed=("Delivery Note", "Sales Invoice", "Stock Entry"),
        )
        _validate_supporting_voucher(
            doc.destination_voucher_type,
            doc.destination_voucher,
            doc.destination_company,
            doc.amount,
            doc.posting_date,
            transfer_name=doc.name,
            voucher_field="destination_voucher",
            voucher_type_field="destination_voucher_type",
            allowed=("Purchase Receipt", "Purchase Invoice", "Stock Entry"),
        )
    if doc.reversal_of:
        original = frappe.db.get_value(
            "ASOUD Intercompany Transfer",
            doc.reversal_of,
            ["status", "reversed_by"],
            as_dict=True,
        )
        if not original or original.status != "Completed" or original.reversed_by:
            frappe.throw("Only a completed, unreversed transfer can be compensated")


def _validate_supporting_voucher(
    doctype: str | None,
    name: str | None,
    company: str,
    amount: float,
    posting_date: str,
    *,
    transfer_name: str,
    voucher_field: str,
    voucher_type_field: str,
    allowed: tuple[str, ...],
) -> None:
    import frappe
    from frappe.utils import flt, getdate

    if doctype not in allowed or not name:
        frappe.throw("Goods transfers require official source and destination vouchers")
    value_field = {
        "Delivery Note": "base_net_total",
        "Sales Invoice": "base_net_total",
        "Purchase Receipt": "base_net_total",
        "Purchase Invoice": "base_net_total",
        "Stock Entry": (
            "total_outgoing_value"
            if voucher_field == "source_voucher"
            else "total_incoming_value"
        ),
    }[doctype]
    fields = ["company", "docstatus", "posting_date", value_field]
    if doctype in {"Sales Invoice", "Purchase Invoice"}:
        fields.append("update_stock")
    row = frappe.db.get_value(doctype, name, fields, as_dict=True)
    if not row or row.company != company or row.docstatus != 1:
        frappe.throw("Supporting voucher must be submitted in the matching company")
    if doctype in {"Sales Invoice", "Purchase Invoice"} and not row.update_stock:
        frappe.throw("Invoice used for a goods transfer must update stock")
    if getdate(row.posting_date) > getdate(posting_date):
        frappe.throw("Supporting voucher cannot be dated after the transfer")
    voucher_value = flt(row.get(value_field), 2)
    if voucher_value <= 0 or abs(voucher_value - flt(amount, 2)) > 0.01:
        frappe.throw("Supporting voucher value must equal the intercompany amount")
    duplicate = frappe.db.exists(
        "ASOUD Intercompany Transfer",
        {
            voucher_field: name,
            voucher_type_field: doctype,
            "name": ["!=", transfer_name],
            "docstatus": ["!=", 2],
        },
    )
    if duplicate:
        frappe.throw("Supporting voucher is already linked to another transfer")


def _validate_account_detail(
    account: str,
    detail: str | None,
    company: str,
) -> None:
    import frappe

    rules = frappe.get_all(
        "ASOUD Account Detail Rule",
        filters={"company": company, "account": account, "enabled": 1},
        fields=["detail_type", "required"],
    )
    if any(row.required for row in rules) and not detail:
        frappe.throw(f"Floating detail is required for intercompany account {account}")
    if not detail:
        return
    mapping = frappe.db.exists(
        "ASOUD Floating Detail Company",
        {"parent": detail, "company": company, "enabled": 1},
    )
    detail_type = frappe.db.get_value(
        "ASOUD Floating Detail", detail, "detail_type"
    )
    if not mapping or detail_type not in {row.detail_type for row in rules}:
        allowed = ", ".join(sorted({row.detail_type for row in rules})) or "none"
        frappe.throw(
            f"Floating detail type {detail_type or 'missing'} is not allowed for "
            f"{account} in {company}; allowed types: {allowed}"
        )


def approve_source(name: str) -> dict[str, Any]:
    import frappe
    from frappe.utils import now_datetime

    frappe.db.sql(
        "select name from `tabASOUD Intercompany Transfer` where name=%s for update",
        name,
    )
    doc = frappe.get_doc("ASOUD Intercompany Transfer", name)
    _assert_context(frappe.session.user, doc.source_company, doc.source_branch)
    if doc.docstatus != 0 or doc.status not in ("", "Requested"):
        frappe.throw("Only a requested transfer can receive source approval")
    validate_intercompany_transfer(doc)
    doc.status = "Source Approved"
    doc.source_approved_by = frappe.session.user
    doc.source_approved_at = now_datetime()
    doc.save()
    return {"name": doc.name, "status": doc.status}


def accept_destination(name: str) -> dict[str, Any]:
    import frappe
    from frappe.utils import now_datetime

    frappe.db.sql(
        "select name from `tabASOUD Intercompany Transfer` where name=%s for update",
        name,
    )
    doc = frappe.get_doc("ASOUD Intercompany Transfer", name)
    _assert_context(frappe.session.user, doc.destination_company, doc.destination_branch)
    if doc.docstatus == 1 and doc.status == "Completed":
        return {
            "name": doc.name,
            "status": doc.status,
            "source_journal_entry": doc.source_journal_entry,
            "destination_journal_entry": doc.destination_journal_entry,
        }
    if doc.docstatus != 0 or doc.status != "Source Approved":
        frappe.throw("Destination can accept only a source-approved transfer")
    doc.destination_approved_by = frappe.session.user
    doc.destination_approved_at = now_datetime()
    doc.save()
    doc.submit()
    doc.reload()
    return {
        "name": doc.name,
        "status": doc.status,
        "source_journal_entry": doc.source_journal_entry,
        "destination_journal_entry": doc.destination_journal_entry,
    }


def _journal(
    *,
    transfer,
    company: str,
    branch: str,
    debit_account: str,
    credit_account: str,
    debit_detail: str | None,
    credit_detail: str | None,
    side: str,
) -> str:
    import frappe

    marker = f"ASOUD Intercompany::{transfer.name}::{side}"
    existing = frappe.db.exists(
        "Journal Entry", {"company": company, "user_remark": marker, "docstatus": 1}
    )
    if existing:
        return existing
    journal = frappe.get_doc(
        {
            "doctype": "Journal Entry",
            "voucher_type": "Journal Entry",
            "company": company,
            "posting_date": transfer.posting_date,
            "asoud_branch": branch,
            "asoud_intercompany_transfer": transfer.name,
            "asoud_counterparty_company": (
                transfer.destination_company
                if side == "Source"
                else transfer.source_company
            ),
            "user_remark": marker,
            "accounts": [
                {
                    "account": debit_account,
                    "debit_in_account_currency": transfer.amount,
                    "asoud_floating_detail": debit_detail,
                },
                {
                    "account": credit_account,
                    "credit_in_account_currency": transfer.amount,
                    "asoud_floating_detail": credit_detail,
                },
            ],
        }
    ).insert(ignore_permissions=True)
    journal.submit()
    return journal.name


def post_intercompany_transfer(doc) -> tuple[str, str]:
    source = _journal(
        transfer=doc,
        company=doc.source_company,
        branch=doc.source_branch,
        debit_account=doc.source_intercompany_account,
        credit_account=doc.source_settlement_account,
        debit_detail=doc.source_intercompany_detail,
        credit_detail=doc.source_settlement_detail,
        side="Source",
    )
    destination = _journal(
        transfer=doc,
        company=doc.destination_company,
        branch=doc.destination_branch,
        debit_account=doc.destination_settlement_account,
        credit_account=doc.destination_intercompany_account,
        debit_detail=doc.destination_settlement_detail,
        credit_detail=doc.destination_intercompany_detail,
        side="Destination",
    )
    return source, destination


def reverse_transfer(name: str, posting_date: str, reason: str) -> str:
    import frappe

    original = frappe.get_doc("ASOUD Intercompany Transfer", name)
    if original.transfer_type == "Goods":
        frappe.throw(
            "Goods compensation requires explicit return stock vouchers and a new transfer"
        )
    _assert_context(
        frappe.session.user, original.source_company, original.source_branch
    )
    _assert_context(
        frappe.session.user, original.destination_company, original.destination_branch
    )
    if original.docstatus != 1 or original.status != "Completed" or original.reversed_by:
        frappe.throw("Transfer is not eligible for compensation")
    idempotency_key = f"REV::{original.name}"
    existing = frappe.db.exists(
        "ASOUD Intercompany Transfer", {"idempotency_key": idempotency_key}
    )
    if existing:
        return existing
    reversal = frappe.get_doc(
        {
            "doctype": "ASOUD Intercompany Transfer",
            "transfer_type": original.transfer_type,
            "posting_date": posting_date,
            "source_company": original.destination_company,
            "source_branch": original.destination_branch,
            "destination_company": original.source_company,
            "destination_branch": original.source_branch,
            "source_settlement_account": original.destination_settlement_account,
            "source_intercompany_account": original.destination_intercompany_account,
            "source_settlement_detail": original.destination_settlement_detail,
            "source_intercompany_detail": original.destination_intercompany_detail,
            "destination_settlement_account": original.source_settlement_account,
            "destination_intercompany_account": original.source_intercompany_account,
            "destination_settlement_detail": original.source_settlement_detail,
            "destination_intercompany_detail": original.source_intercompany_detail,
            "amount": original.amount,
            "currency": original.currency,
            "idempotency_key": idempotency_key,
            "reason": f"Compensation for {original.name}: {reason}",
            "reversal_of": original.name,
            "status": "Requested",
        }
    ).insert()
    approve_source(reversal.name)
    accept_destination(reversal.name)
    original.db_set("reversed_by", reversal.name)
    original.db_set("status", "Reversed")
    return reversal.name


def _mapped_code(holding: str, company: str, account: str):
    import frappe

    return frappe.db.get_value(
        "ASOUD Consolidation Account Map",
        {"holding": holding, "company": company, "account": account, "enabled": 1},
        ["consolidation_code", "consolidation_title", "root_type"],
        as_dict=True,
    )


def consolidation_report(
    holding: str,
    from_date: str,
    to_date: str,
) -> dict[str, Any]:
    import frappe
    from frappe.utils import getdate

    from asoud_core.permissions import can_manage_holding

    if not can_manage_holding(frappe.session.user, holding):
        frappe.throw("Holding reporting permission is required", frappe.PermissionError)
    if getdate(from_date) > getdate(to_date):
        frappe.throw("Consolidation start date must not be after end date")
    holding_currency = frappe.db.get_value(
        "ASOUD Holding", holding, "consolidation_currency"
    )
    companies = frappe.get_all(
        "Company",
        filters={"asoud_holding": holding, "is_group": 0},
        pluck="name",
        order_by="name",
    )
    if not companies:
        frappe.throw("Holding has no enabled reporting companies")
    currency_rows = frappe.get_all(
        "Company",
        filters={"name": ["in", companies]},
        fields=["name", "default_currency"],
    )
    company_currency = {row.name: row.default_currency for row in currency_rows}
    mixed_currency = set(company_currency.values()) != {holding_currency}
    policy = None
    rate_rows: list[dict[str, Any]] = []
    if mixed_currency:
        policy = frappe.db.get_value(
            "ASOUD FX Policy",
            {"holding": holding, "enabled": 1},
            ["reporting_currency", "cta_account_code", "cta_account_title"],
            as_dict=True,
        )
        if not policy or policy.reporting_currency != holding_currency:
            frappe.throw("An enabled FX policy is required for mixed-currency consolidation")
        rate_rows = frappe.get_all(
            "ASOUD FX Rate",
            filters={"holding": holding, "reporting_currency": holding_currency, "docstatus": 1},
            fields=[
                "name",
                "source_currency",
                "rate_type",
                "effective_from",
                "effective_to",
                "rate",
                "source_reference",
            ],
        )
    mappings = frappe.get_all(
        "ASOUD Consolidation Account Map",
        filters={"holding": holding, "company": ["in", companies], "enabled": 1},
        fields=[
            "company",
            "account",
            "consolidation_code",
            "consolidation_title",
            "root_type",
        ],
    )
    map_by_account = {(row.company, row.account): row for row in mappings}
    gl_rows = frappe.db.sql(
        """
        select company, account, posting_date, sum(debit-credit) balance
          from `tabGL Entry`
         where company in %(companies)s and posting_date <= %(to_date)s
           and is_cancelled=0
         group by company, account, posting_date
        """,
        {"companies": companies, "from_date": from_date, "to_date": to_date},
        as_dict=True,
    )
    balances = []
    unmapped = []
    translation_evidence: set[str] = set()
    for gl in gl_rows:
        mapping = map_by_account.get((gl.company, gl.account))
        if not mapping:
            if abs(float(gl.balance or 0)) > 0.005:
                unmapped.append(
                    {
                        "company": gl.company,
                        "account": gl.account,
                        "balance": float(gl.balance or 0),
                    }
                )
            continue
        if (
            mapping.root_type in {"Income", "Expense"}
            and getdate(gl.posting_date) < getdate(from_date)
        ):
            continue
        currency = company_currency[gl.company]
        rate_type = {
            "Asset": "Closing",
            "Liability": "Closing",
            "Income": "Average",
            "Expense": "Average",
            "Equity": "Historical",
        }.get(mapping.root_type)
        if not rate_type:
            frappe.throw(f"Unsupported consolidation root type: {mapping.root_type}")
        rate = 1.0
        if currency != holding_currency:
            from asoud_core.services.currency_translation import select_rate

            rate_date = (
                str(to_date)
                if rate_type in {"Closing", "Average"}
                else str(gl.posting_date)
            )
            try:
                rate = float(
                    select_rate(
                        rate_rows,
                        currency=currency,
                        rate_type=rate_type,
                        posting_date=rate_date,
                        period_from=str(from_date),
                        period_to=str(to_date),
                    )
                )
            except ValueError as exc:
                frappe.throw(str(exc))
            matching = [
                row
                for row in rate_rows
                if row["source_currency"] == currency and row["rate_type"] == rate_type
            ]
            translation_evidence.update(row["name"] for row in matching)
        balances.append(
            {
                "account_code": mapping.consolidation_code,
                "account_title": mapping.consolidation_title,
                "root_type": mapping.root_type,
                "balance": round(float(gl.balance or 0) * rate, 2),
                "source_currency": currency,
                "rate_type": rate_type,
                "rate": rate,
            }
        )
    cta = 0.0
    if mixed_currency:
        cta = round(-sum(float(row["balance"]) for row in balances), 2)
        if cta:
            balances.append(
                {
                    "account_code": policy.cta_account_code,
                    "account_title": policy.cta_account_title,
                    "root_type": "Equity",
                    "balance": cta,
                    "source_currency": holding_currency,
                    "rate_type": "CTA",
                    "rate": 1.0,
                }
            )
    adjustments: list[dict[str, Any]] = []
    transfers = frappe.get_all(
        "ASOUD Intercompany Transfer",
        filters={
            "holding": holding,
            "docstatus": 1,
            "posting_date": ["between", (from_date, to_date)],
        },
        fields=[
            "name",
            "amount",
            "source_company",
            "source_intercompany_account",
            "destination_company",
            "destination_intercompany_account",
        ],
    )
    for transfer in transfers:
        source = _mapped_code(
            holding, transfer.source_company, transfer.source_intercompany_account
        )
        destination = _mapped_code(
            holding,
            transfer.destination_company,
            transfer.destination_intercompany_account,
        )
        if not source or not destination:
            unmapped.append(
                {
                    "transfer": transfer.name,
                    "reason": "Intercompany account mapping is missing",
                }
            )
            continue
        elimination_amount = float(transfer.amount)
        transfer_currency = frappe.db.get_value(
            "ASOUD Intercompany Transfer", transfer.name, "currency"
        )
        if transfer_currency and transfer_currency != holding_currency:
            from asoud_core.services.currency_translation import select_rate

            try:
                elimination_amount *= float(
                    select_rate(
                        rate_rows,
                        currency=transfer_currency,
                        rate_type="Closing",
                        posting_date=str(to_date),
                        period_from=str(from_date),
                        period_to=str(to_date),
                    )
                )
            except ValueError as exc:
                frappe.throw(str(exc))
        lines = elimination_lines(
            round(elimination_amount, 2),
            source.consolidation_code,
            destination.consolidation_code,
        )
        for line, mapping in zip(lines, (source, destination), strict=True):
            line.update(
                {
                    "account_title": mapping.consolidation_title,
                    "root_type": mapping.root_type,
                    "source": transfer.name,
                }
            )
            adjustments.append(line)
    manual = frappe.get_all(
        "ASOUD Consolidation Adjustment",
        filters={
            "holding": holding,
            "docstatus": 1,
            "posting_date": ["between", (from_date, to_date)],
        },
        fields=[
            "name",
            "consolidation_code as account_code",
            "consolidation_title as account_title",
            "root_type",
            "debit",
            "credit",
        ],
    )
    adjustments.extend({**row, "source": row.name} for row in manual)
    rows = aggregate_consolidation(balances, adjustments)
    raw_difference = round(sum(float(row["raw_balance"]) for row in rows), 2)
    elimination_difference = round(
        sum(float(row["elimination"]) for row in rows), 2
    )
    consolidated_difference = round(
        sum(float(row["consolidated_balance"]) for row in rows), 2
    )
    payload = {
        "schema_version": "2.0",
        "holding": holding,
        "companies": companies,
        "reporting_currency": holding_currency,
        "from_date": from_date,
        "to_date": to_date,
        "rows": rows,
        "eliminations": adjustments,
        "unmapped": unmapped,
        "currency_translation": {
            "applied": mixed_currency,
            "cta": cta,
            "rate_evidence": sorted(translation_evidence),
        },
        "controls": {
            "raw_difference": raw_difference,
            "elimination_difference": elimination_difference,
            "consolidated_difference": consolidated_difference,
            "balanced": (
                not unmapped
                and abs(raw_difference) < 0.01
                and abs(elimination_difference) < 0.01
                and abs(consolidated_difference) < 0.01
            ),
        },
    }
    payload["checksum"] = hashlib.sha256(
        json.dumps(payload, sort_keys=True, default=str).encode()
    ).hexdigest()
    return payload
