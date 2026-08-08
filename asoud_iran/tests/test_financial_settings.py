import sys
from types import SimpleNamespace

import pytest

from asoud_iran.services.financial_settings import (
    DEFAULT_ACCOUNT_FIELDS,
    _normalize_payload,
    _validate_default_accounts,
)


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
        **{fieldname: "" for fieldname in DEFAULT_ACCOUNT_FIELDS},
    }


def test_normalizes_company_default_accounts():
    values = _normalize_payload(
        {
            "coa_template": "GENERAL-V1",
            "default_receivable_account": " 112001 - A ",
            "default_bank_account": " Bank - A ",
        }
    )
    assert values["default_receivable_account"] == "112001 - A"
    assert values["default_bank_account"] == "Bank - A"


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


def test_accepts_enabled_leaf_default_account_of_active_company(monkeypatch):
    fake = SimpleNamespace(
        db=SimpleNamespace(
            get_value=lambda *args, **kwargs: SimpleNamespace(
                company="ASOUD",
                is_group=0,
                disabled=0,
                account_type="Bank",
                root_type="Asset",
            )
        ),
        throw=lambda message: (_ for _ in ()).throw(ValueError(message)),
    )
    monkeypatch.setitem(sys.modules, "frappe", fake)

    _validate_default_accounts("ASOUD", {"default_bank_account": "Bank - ASOUD"})


def test_rejects_default_account_from_another_company(monkeypatch):
    fake = SimpleNamespace(
        db=SimpleNamespace(
            get_value=lambda *args, **kwargs: SimpleNamespace(
                company="OTHER",
                is_group=0,
                disabled=0,
                account_type="Bank",
                root_type="Asset",
            )
        ),
        throw=lambda message: (_ for _ in ()).throw(ValueError(message)),
    )
    monkeypatch.setitem(sys.modules, "frappe", fake)

    with pytest.raises(ValueError, match="enabled leaf account"):
        _validate_default_accounts(
            "ASOUD", {"default_bank_account": "Bank - OTHER"}
        )
