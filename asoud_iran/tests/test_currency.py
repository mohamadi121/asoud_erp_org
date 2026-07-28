import pytest

from asoud_iran.accounting.currency import AmountError, from_irr, normalize_api_amount, to_irr


def test_toman_converts_to_exact_integer_rial():
    assert to_irr("1250.5", "TOMAN") == 12505
    assert from_irr(12505, "TOMAN") == "1250.5"


def test_api_amount_is_explicit_and_string_encoded():
    assert normalize_api_amount("250", "TOMAN") == {
        "amount": "2500",
        "unit": "IRR",
        "ledger_amount": "2500",
        "ledger_unit": "IRR",
    }


@pytest.mark.parametrize(
    ("value", "unit"),
    [
        ("0.1", "IRR"),
        ("0.01", "TOMAN"),
        (1.2, "IRR"),
        ("NaN", "IRR"),
        ("100", "USD"),
    ],
)
def test_invalid_or_inexact_amounts_are_rejected(value, unit):
    with pytest.raises(AmountError):
        to_irr(value, unit)


def test_negative_and_large_values_are_exact():
    assert to_irr("-9007199254740993", "IRR") == -9007199254740993
    assert from_irr(10**24, "IRR") == str(10**24)

