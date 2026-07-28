from decimal import Decimal

import pytest

from asoud_core.services.currency_translation import select_rate, translate_balances


def test_translation_uses_accounting_policy_and_balances_with_cta():
    result = translate_balances(
        [
            {"account_code": "A", "root_type": "Asset", "currency": "USD", "balance": 10},
            {"account_code": "I", "root_type": "Income", "currency": "USD", "balance": -8},
            {"account_code": "E", "root_type": "Equity", "currency": "USD", "balance": -2},
        ],
        {
            ("USD", "Closing"): Decimal("600000"),
            ("USD", "Average"): Decimal("550000"),
            ("USD", "Historical"): Decimal("500000"),
        },
        reporting_currency="IRR",
        cta_account_code="CTA",
    )
    by_code = {row["account_code"]: row for row in result.rows}
    assert by_code["A"]["rate_type"] == "Closing"
    assert by_code["I"]["rate_type"] == "Average"
    assert by_code["E"]["rate_type"] == "Historical"
    assert sum(Decimal(str(row["balance"])) for row in result.rows) == 0


def test_translation_fails_when_evidence_rate_is_missing():
    with pytest.raises(ValueError, match="Missing Closing rate"):
        translate_balances(
            [{"account_code": "A", "root_type": "Asset", "currency": "EUR", "balance": 1}],
            {},
            reporting_currency="IRR",
            cta_account_code="CTA",
        )


def test_rate_selection_rejects_ambiguous_evidence():
    row = {
        "source_currency": "USD",
        "rate_type": "Closing",
        "effective_from": "2026-07-26",
        "effective_to": None,
        "rate": 600000,
    }
    with pytest.raises(ValueError, match="found 2"):
        select_rate(
            [row, dict(row)],
            currency="USD",
            rate_type="Closing",
            posting_date="2026-07-26",
            period_from="2026-03-21",
            period_to="2027-03-20",
        )
