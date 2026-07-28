import pytest

from asoud_iran.services.financial_settings import _normalize_payload


def test_normalizes_financial_settings_payload():
    assert _normalize_payload(
        {
            "coa_template": " GENERAL-V1 ",
            "amount_input_unit": "toman",
            "calendar_display": "Jalali",
        }
    ) == {
        "coa_template": "GENERAL-V1",
        "amount_input_unit": "TOMAN",
        "calendar_display": "Jalali",
    }


@pytest.mark.parametrize(
    "payload",
    [
        {"coa_template": ""},
        {"coa_template": "GENERAL-V1", "amount_input_unit": "USD"},
        {"coa_template": "GENERAL-V1", "calendar_display": "Hijri"},
    ],
)
def test_rejects_invalid_financial_settings_payload(payload):
    with pytest.raises(ValueError):
        _normalize_payload(payload)
