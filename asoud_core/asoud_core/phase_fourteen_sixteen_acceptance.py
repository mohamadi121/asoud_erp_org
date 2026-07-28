from __future__ import annotations

from decimal import Decimal
import json


REQUIRED_DOCTYPES = {
    "ASOUD Bank Connection": {"company", "branch", "environment", "secret_reference"},
    "ASOUD Bank Statement Import": {"file_checksum", "row_count", "status"},
    "ASOUD Bank Statement Line": {"fingerprint", "match_status", "matched_voucher"},
    "ASOUD Sayad Operation": {"sayad_id", "idempotency_key", "state"},
    "ASOUD Sayad Event": {"operation", "from_state", "to_state"},
    "ASOUD FX Policy": {"holding", "reporting_currency", "cta_account_code"},
    "ASOUD FX Rate": {"rate_type", "effective_from", "rate", "source_reference"},
    "ASOUD Tax Settings": {"company", "environment", "certificate_reference"},
    "ASOUD Tax Submission": {"idempotency_key", "payload_checksum", "status"},
    "ASOUD Tax Event": {"submission", "from_status", "to_status"},
}


def _assert_meta() -> dict[str, list[str]]:
    import frappe

    result = {}
    for doctype, required in REQUIRED_DOCTYPES.items():
        meta = frappe.get_meta(doctype)
        fields = {field.fieldname for field in meta.fields}
        missing = sorted(required - fields)
        if missing:
            raise AssertionError(f"{doctype} is missing fields: {missing}")
        result[doctype] = sorted(required)
    return result


def _pure_controls() -> dict:
    from asoud_core.services.banking import (
        parse_statement_csv,
        reconciliation_candidates,
        transition_sayad,
    )
    from asoud_core.services.currency_translation import translate_balances
    from asoud_iran.services.tax_gateway import SandboxTaxAdapter, build_tax_invoice

    tax_payload = build_tax_invoice(
        company_identity={"national_id": "10100000000", "economic_code": "411111111111"},
        invoice={"name": "ACCEPTANCE", "posting_date": "2026-07-26", "currency": "IRR"},
        items=[{"item_code": "A", "quantity": 1, "unit_price": 100, "tax": 10}],
    )
    first = SandboxTaxAdapter().submit(tax_payload, "phase-14")
    second = SandboxTaxAdapter().submit(tax_payload, "phase-14")
    if first.provider_reference != second.provider_reference or first.state != "Accepted":
        raise AssertionError("Tax sandbox idempotency failed")

    rows = parse_statement_csv(
        b"date,reference,description,deposit,withdrawal\n"
        b"2026-07-26,PHASE15,Acceptance,100,0\n"
    )
    matches = reconciliation_candidates(
        rows[0],
        [
            {
                "voucher": "PE-ACCEPTANCE",
                "posting_date": "2026-07-26",
                "reference": "PHASE15",
                "amount": 100,
            }
        ],
    )
    if len(matches) != 1 or matches[0].score != 100:
        raise AssertionError("Bank reconciliation scoring failed")
    if transition_sayad("Draft", "Issued") != "Issued":
        raise AssertionError("Sayad state machine failed")

    translated = translate_balances(
        [
            {"account_code": "A", "root_type": "Asset", "currency": "USD", "balance": 10},
            {"account_code": "I", "root_type": "Income", "currency": "USD", "balance": -8},
        ],
        {
            ("USD", "Closing"): Decimal("600000"),
            ("USD", "Average"): Decimal("550000"),
        },
        reporting_currency="IRR",
        cta_account_code="CTA",
    )
    if sum(Decimal(str(row["balance"])) for row in translated.rows) != 0:
        raise AssertionError("Currency translation did not balance through CTA")
    return {
        "tax_reference": first.provider_reference,
        "tax_checksum": tax_payload["checksum"],
        "bank_fingerprint": rows[0]["fingerprint"],
        "bank_match_score": matches[0].score,
        "translation_cta": float(translated.cta),
    }


def _integration_controls() -> dict:
    import frappe

    company = "ASOUD Demo Trading"
    holding = frappe.db.get_value("Company", company, "asoud_holding")
    if not holding:
        raise AssertionError("Controlled demo holding is unavailable")
    if not frappe.db.get_value("Company", company, "asoud_national_id"):
        frappe.db.set_value("Company", company, "asoud_national_id", "10100000000")
    if not frappe.db.get_value("Company", company, "asoud_economic_code"):
        frappe.db.set_value("Company", company, "asoud_economic_code", "411111111111")

    tax_settings = frappe.db.exists("ASOUD Tax Settings", company)
    if not tax_settings:
        tax_settings = frappe.get_doc(
            {
                "doctype": "ASOUD Tax Settings",
                "company": company,
                "enabled": 1,
                "environment": "Sandbox",
                "provider": "ASOUD Sandbox",
                "adapter_version": "1.0",
            }
        ).insert(ignore_permissions=True).name
    invoice = frappe.db.get_value(
        "Sales Invoice",
        {"company": company, "docstatus": 1},
        "name",
        order_by="posting_date asc, name asc",
    )
    if not invoice:
        raise AssertionError("Submitted controlled Sales Invoice is unavailable")
    from asoud_iran.services.tax_submission import dispatch, queue_sales_invoice

    queued = queue_sales_invoice(invoice)
    tax_result = dispatch(queued["name"])
    repeated_tax = queue_sales_invoice(invoice)
    if (
        tax_result["status"] != "Accepted"
        or repeated_tax["name"] != queued["name"]
        or frappe.db.count("ASOUD Tax Event", {"submission": queued["name"]}) != 2
    ):
        raise AssertionError("End-to-end tax sandbox control failed")

    treasury = frappe.db.get_value(
        "ASOUD Treasury Account",
        {"company": company, "treasury_type": "Bank", "enabled": 1},
        ["name", "branch"],
        as_dict=True,
    )
    if not treasury:
        raise AssertionError("Controlled bank treasury account is unavailable")
    connection = frappe.db.exists(
        "ASOUD Bank Connection", {"treasury_account": treasury.name}
    )
    if not connection:
        connection = frappe.get_doc(
            {
                "doctype": "ASOUD Bank Connection",
                "company": company,
                "branch": treasury.branch,
                "treasury_account": treasury.name,
                "bank_name": "ASOUD Sandbox Bank",
                "environment": "Sandbox",
                "enabled": 1,
            }
        ).insert(ignore_permissions=True).name
    from asoud_core.services.bank_statement import import_csv

    statement = (
        b"date,reference,description,deposit,withdrawal\n"
        b"2026-07-26,P15-E2E,Controlled acceptance,125,0\n"
    )
    bank_first = import_csv(connection, "phase-15-controlled.csv", statement)
    bank_second = import_csv(connection, "phase-15-controlled.csv", statement)
    if bank_first["name"] != bank_second["name"] or not bank_second["duplicate"]:
        raise AssertionError("Bank statement import idempotency failed")

    cheque = frappe.db.get_value(
        "ASOUD Cheque",
        {"company": company, "cheque_type": "Outgoing"},
        ["name", "branch"],
        as_dict=True,
    )
    if not cheque:
        raise AssertionError("Controlled outgoing cheque is unavailable")
    sayad = frappe.db.exists(
        "ASOUD Sayad Operation", {"idempotency_key": "PHASE-15-SAYAD-E2E"}
    )
    if not sayad:
        sayad = frappe.get_doc(
            {
                "doctype": "ASOUD Sayad Operation",
                "company": company,
                "branch": cheque.branch,
                "cheque": cheque.name,
                "sayad_id": "1234567890123456",
                "operation_type": "Issue",
                "idempotency_key": "PHASE-15-SAYAD-E2E",
            }
        ).insert(ignore_permissions=True).name
    sayad_state = frappe.db.get_value("ASOUD Sayad Operation", sayad, "state")
    if sayad_state == "Draft":
        from asoud_core.services.sayad import sandbox_transition

        sayad_result = sandbox_transition(sayad, "Issued")
        sayad_state = sayad_result["state"]
    if sayad_state != "Issued" or frappe.db.count(
        "ASOUD Sayad Event", {"operation": sayad}
    ) != 1:
        raise AssertionError("End-to-end Sayad sandbox control failed")

    holding_currency = frappe.db.get_value(
        "ASOUD Holding", holding, "consolidation_currency"
    )
    policy = frappe.db.exists("ASOUD FX Policy", holding)
    if not policy:
        policy = frappe.get_doc(
            {
                "doctype": "ASOUD FX Policy",
                "holding": holding,
                "reporting_currency": holding_currency,
                "cta_account_code": "CTA",
                "cta_account_title": "Currency Translation Adjustment",
                "enabled": 1,
            }
        ).insert(ignore_permissions=True).name
    rate_names = []
    for rate_type, start, end, rate in (
        ("Closing", "2026-07-26", None, 600000),
        ("Average", "2026-03-21", "2027-03-20", 550000),
        ("Historical", "2026-03-21", None, 500000),
    ):
        name = (
            f"{holding}|USD|{holding_currency}|{rate_type}|{start}|{end or '-'}"
        )
        if not frappe.db.exists("ASOUD FX Rate", name):
            rate_doc = frappe.get_doc(
                {
                    "doctype": "ASOUD FX Rate",
                    "holding": holding,
                    "source_currency": "USD",
                    "reporting_currency": holding_currency,
                    "rate_type": rate_type,
                    "effective_from": start,
                    "effective_to": end,
                    "rate": rate,
                    "source_reference": "ASOUD controlled synthetic evidence",
                    "approved_by": "Administrator",
                }
            ).insert(ignore_permissions=True)
            rate_doc.submit()
            name = rate_doc.name
        rate_names.append(name)
    if frappe.db.count(
        "ASOUD FX Rate", {"name": ["in", rate_names], "docstatus": 1}
    ) != 3:
        raise AssertionError("Approved FX evidence control failed")
    return {
        "tax_submission": queued["name"],
        "tax_status": tax_result["status"],
        "bank_import": bank_first["name"],
        "bank_rows": bank_first["row_count"],
        "sayad_operation": sayad,
        "sayad_state": sayad_state,
        "fx_policy": policy,
        "approved_fx_rates": rate_names,
    }


def run_acceptance() -> dict:
    import frappe

    installed = set(frappe.get_installed_apps())
    if not {"asoud_core", "asoud_iran"}.issubset(installed):
        raise AssertionError("ASOUD applications are not installed")
    result = {
        "schema_version": "1.0",
        "status": "passed",
        "phases": [14, 15, 16],
        "versions": {
            "frappe": frappe.get_attr("frappe.__version__"),
            "erpnext": frappe.get_attr("erpnext.__version__"),
            "asoud_core": frappe.get_attr("asoud_core.__version__"),
            "asoud_iran": frappe.get_attr("asoud_iran.__version__"),
        },
        "metadata": _assert_meta(),
        "controls": _pure_controls(),
        "integration": _integration_controls(),
        "production_connectivity": {
            "tax": "blocked_pending_official_credentials_and_adapter",
            "bank_sayad": "blocked_pending_contracted_provider_credentials",
            "claimed": False,
        },
    }
    result["canonical"] = json.dumps(result, sort_keys=True, default=str)
    return result
