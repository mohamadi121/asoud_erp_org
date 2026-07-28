import json

import pytest

from asoud_core.services.operational_workbench import (
    CONTRACTS,
    contracts,
    sanitize_payload,
)


def test_contracts_cover_the_primary_operational_areas():
    assert {
        "Sales Invoice",
        "Purchase Invoice",
        "Payment Entry",
        "Stock Entry",
        "Journal Entry",
        "ASOUD Treasury Transaction",
        "ASOUD Cheque",
        "ASOUD Intercompany Transfer",
    } <= set(CONTRACTS)


def test_payload_is_allowlisted_and_child_rows_are_sanitized():
    clean = sanitize_payload(
        "Sales Invoice",
        json.dumps(
            {
                "customer": "CUST-1",
                "posting_date": "2026-07-26",
                "owner": "Administrator",
                "company": "A",
                "docstatus": 1,
                "items": [
                    {
                        "item_code": "ITEM-1",
                        "qty": 2,
                        "rate": 10,
                        "warehouse": "Stores - A",
                        "doctype": "Sales Invoice Item",
                    }
                ],
            }
        ),
    )
    assert clean == {
        "customer": "CUST-1",
        "posting_date": "2026-07-26",
        "items": [
            {
                "item_code": "ITEM-1",
                "qty": 2,
                "rate": 10,
                "warehouse": "Stores - A",
            }
        ],
    }


def test_unknown_document_type_and_invalid_children_fail_closed():
    with pytest.raises(ValueError, match="Unsupported"):
        sanitize_payload("User", {})
    with pytest.raises(ValueError, match="non-empty"):
        sanitize_payload("Journal Entry", {"accounts": []})


def test_custom_contract_fields_match_the_v15_doctype_contracts():
    assert "target_treasury_account" in CONTRACTS["ASOUD Treasury Transaction"].fields
    assert "counter_account" in CONTRACTS["ASOUD Treasury Transaction"].fields
    assert "bank_treasury_account" in CONTRACTS["ASOUD Cheque"].fields
    assert (
        "source_intercompany_account"
        in CONTRACTS["ASOUD Intercompany Transfer"].fields
    )


def test_contract_payload_exposes_typed_form_schema_and_child_requirement():
    sales = next(
        item for item in contracts() if item["document_type"] == "Sales Invoice"
    )
    payment = next(
        item for item in contracts() if item["document_type"] == "Payment Entry"
    )
    assert sales["field_specs"][0]["fieldname"] == "customer"
    assert sales["field_specs"][0]["fieldtype"]
    assert sales["child_field_specs"][0]["fieldname"] == "item_code"
    assert sales["child_required"] is True
    assert payment["child_required"] is False
