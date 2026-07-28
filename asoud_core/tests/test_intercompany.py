from asoud_core.services.intercompany import (
    TRANSFER_STATES,
    aggregate_consolidation,
    elimination_lines,
)


def test_intercompany_state_contract_is_explicit_and_immutable_after_completion():
    assert TRANSFER_STATES == (
        "Requested",
        "Source Approved",
        "Completed",
        "Reversed",
    )


def test_elimination_of_reciprocal_receivable_and_payable_is_balanced():
    lines = elimination_lines(1250, "IC-RECEIVABLE", "IC-PAYABLE")
    assert lines == [
        {"account_code": "IC-RECEIVABLE", "debit": 0.0, "credit": 1250.0},
        {"account_code": "IC-PAYABLE", "debit": 1250.0, "credit": 0.0},
    ]
    assert sum(line["debit"] - line["credit"] for line in lines) == 0


def test_consolidation_keeps_raw_and_adjustment_layers_separate():
    rows = aggregate_consolidation(
        [
            {
                "account_code": "IC-REC",
                "account_title": "Intercompany Receivable",
                "root_type": "Asset",
                "balance": 500,
            },
            {
                "account_code": "IC-PAY",
                "account_title": "Intercompany Payable",
                "root_type": "Liability",
                "balance": -500,
            },
        ],
        elimination_lines(500, "IC-REC", "IC-PAY"),
    )
    by_code = {row["account_code"]: row for row in rows}
    assert by_code["IC-REC"]["raw_balance"] == 500
    assert by_code["IC-REC"]["elimination"] == -500
    assert by_code["IC-REC"]["consolidated_balance"] == 0
    assert by_code["IC-PAY"]["raw_balance"] == -500
    assert by_code["IC-PAY"]["elimination"] == 500
    assert by_code["IC-PAY"]["consolidated_balance"] == 0
