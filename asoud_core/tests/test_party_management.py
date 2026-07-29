import pytest

from asoud_core.services.party_management import (
    ROLE_DEFINITIONS,
    ascii_digits,
    normalize_party_payload,
)


def test_ascii_digits_normalizes_persian_and_arabic_digits():
    assert ascii_digits("۰۹۱٢٣") == "09123"


def test_normalize_natural_person_with_multiple_roles_and_opening_balance():
    values = normalize_party_payload(
        {
            "person_type": "Natural",
            "first_name": "احمد",
            "last_name": "سماوات",
            "father_name": "علی",
            "birth_certificate_number": "۱۲۳۴",
            "birth_place": "تهران",
            "national_id": "۰۰۱۲۳۴۵۶۷۸",
            "roles": ["Customer", "Supplier", "Customer"],
            "opening_balances": [
                {
                    "role": "Customer",
                    "balance_state": "Debit",
                    "amount": 25_000_000,
                }
            ],
        }
    )
    assert values["display_name"] == "احمد سماوات"
    assert values["national_id"] == "0012345678"
    assert values["roles"] == ["Customer", "Supplier"]
    assert values["birth_certificate_number"] == "1234"
    assert values["opening_balances"][0]["amount"] == 25_000_000


def test_normalize_legal_person_requires_company_name():
    with pytest.raises(ValueError, match="Legal entity name"):
        normalize_party_payload({"person_type": "Legal", "roles": ["Supplier"]})


def test_opening_balance_requires_selected_role_and_positive_amount():
    with pytest.raises(ValueError, match="selected"):
        normalize_party_payload(
            {
                "person_type": "Natural",
                "first_name": "علی",
                "last_name": "محمدی",
                "roles": ["Customer"],
                "opening_balances": [{"role": "Supplier", "balance_state": "Credit"}],
            }
        )
    with pytest.raises(ValueError, match="positive"):
        normalize_party_payload(
            {
                "person_type": "Natural",
                "first_name": "علی",
                "last_name": "محمدی",
                "roles": ["Customer"],
                "opening_balances": [
                    {"role": "Customer", "balance_state": "Debit", "amount": 0}
                ],
            }
        )


def test_role_ranges_match_approved_code_families():
    assert ROLE_DEFINITIONS["Customer"]["start"] == 10000
    assert ROLE_DEFINITIONS["Supplier"]["start"] == 15000
    assert ROLE_DEFINITIONS["Employee"]["start"] == 6000
