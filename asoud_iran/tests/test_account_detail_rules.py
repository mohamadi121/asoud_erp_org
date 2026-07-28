import pytest

from asoud_iran.services.account_detail_rules import (
    normalize_account_payload,
    normalize_rule_payload,
)


def test_normalizes_account_and_detail_rules():
    assert normalize_account_payload(
        {
            "account_name": " تنخواه دفتر مرکزی ",
            "account_number": "111003",
            "parent_account": "Cash - DEMO",
            "account_type": "Cash",
            "account_currency": "irr",
            "rules": [
                {
                    "detail_type": "Employee",
                    "required": 1,
                    "enabled": True,
                    "valid_from": "2026-03-21",
                }
            ],
        }
    ) == {
        "name": None,
        "account_name": "تنخواه دفتر مرکزی",
        "account_number": "111003",
        "parent_account": "Cash - DEMO",
        "is_group": False,
        "account_type": "Cash",
        "account_currency": "IRR",
        "disabled": False,
        "rules": [
            {
                "detail_type": "Employee",
                "required": True,
                "enabled": True,
                "default_floating_detail": None,
                "valid_from": "2026-03-21",
                "valid_to": None,
            }
        ],
    }


@pytest.mark.parametrize(
    "payload",
    [
        [{"detail_type": "Unknown"}],
        [{"detail_type": "Customer"}, {"detail_type": "Customer"}],
        [
            {"detail_type": "Customer", "required": True},
            {"detail_type": "Supplier", "required": True},
        ],
        [
            {
                "detail_type": "Employee",
                "valid_from": "2026-03-21",
                "valid_to": "2026-03-20",
            }
        ],
    ],
)
def test_rejects_invalid_rule_sets(payload):
    with pytest.raises(ValueError):
        normalize_rule_payload(payload)


def test_rejects_detail_rules_for_group_account():
    with pytest.raises(ValueError):
        normalize_account_payload(
            {
                "account_name": "Cash",
                "account_number": "111",
                "parent_account": "Assets - DEMO",
                "is_group": True,
                "rules": [{"detail_type": "Employee"}],
            }
        )
