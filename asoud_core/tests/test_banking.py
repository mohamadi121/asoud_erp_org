import pytest

from asoud_core.services.banking import (
    assert_bank_production_ready,
    parse_statement_csv,
    reconciliation_candidates,
    scoped_fingerprint,
    transition_sayad,
    validate_sayad_id,
)


def test_statement_parser_rejects_duplicates_and_preserves_evidence():
    content = (
        b"date,reference,description,deposit,withdrawal\n"
        b"2026-07-26,R1,Receipt,1000,0\n"
    )
    row = parse_statement_csv(content)[0]
    assert row["deposit"] == 1000
    assert len(row["fingerprint"]) == 64
    with pytest.raises(ValueError, match="Duplicate"):
        parse_statement_csv(content + b"2026-07-26,R1,Receipt,1000,0\n")
    assert scoped_fingerprint("BANK-A", row["fingerprint"]) != scoped_fingerprint(
        "BANK-B", row["fingerprint"]
    )


def test_reconciliation_ranks_reference_and_date_without_auto_hiding_ambiguity():
    candidates = reconciliation_candidates(
        {
            "posting_date": "2026-07-26",
            "reference": "R1",
            "deposit": 1000,
            "withdrawal": 0,
        },
        [
            {"voucher": "PE-2", "posting_date": "2026-07-25", "reference": "", "amount": 1000},
            {"voucher": "PE-1", "posting_date": "2026-07-26", "reference": "R1", "amount": 1000},
        ],
    )
    assert candidates[0].voucher == "PE-1"
    assert candidates[0].score == 100
    assert len(candidates) == 2


def test_sayad_contract_and_production_gate_are_strict():
    assert validate_sayad_id("1234 5678 9012 3456") == "1234567890123456"
    assert transition_sayad("Draft", "Issued") == "Issued"
    with pytest.raises(ValueError, match="Invalid Sayad"):
        transition_sayad("Draft", "Settled")
    with pytest.raises(ValueError, match="fail-closed"):
        assert_bank_production_ready(
            environment="Production", secret_reference=None, provider_profile=None
        )
