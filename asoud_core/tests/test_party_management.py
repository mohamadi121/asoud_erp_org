import pytest

from asoud_core.services.party_management import (
    ROLE_DEFINITIONS,
    _opening_values,
    _role_values,
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


def test_company_policy_is_scoped_to_selected_customer_or_supplier_role():
    values = normalize_party_payload(
        {
            "person_type": "Natural",
            "first_name": "Ali",
            "last_name": "Mohammadi",
            "roles": ["Customer", "Supplier"],
            "company_policies": [
                {
                    "role": "Customer",
                    "enabled": False,
                    "default_branch": "HQ",
                    "credit_limit": 25_000_000,
                    "default_account": "Debtors - A",
                },
                {
                    "role": "Supplier",
                    "credit_limit": 99,
                    "default_account": "Creditors - A",
                },
            ],
        }
    )
    assert values["company_policies"]["Customer"]["enabled"] is False
    assert values["company_policies"]["Customer"]["credit_limit"] == 25_000_000
    assert values["company_policies"]["Supplier"]["credit_limit"] == 0

    with pytest.raises(ValueError, match="selected customer or supplier"):
        normalize_party_payload(
            {
                "person_type": "Natural",
                "first_name": "Ali",
                "last_name": "Mohammadi",
                "roles": ["Employee"],
                "company_policies": [{"role": "Employee"}],
            }
        )


def test_preserved_company_rows_drop_frappe_child_metadata():
    role = _role_values(
        {
            "name": "ROW-1",
            "parent": "PARTY-1",
            "company": "Company B",
            "role": "Customer",
            "role_code": "10001",
            "code_key": "Company B|Customer|10001",
            "enabled": 1,
        }
    )
    opening = _opening_values(
        {
            "name": "ROW-2",
            "parent": "PARTY-1",
            "company": "Company B",
            "role": "Customer",
            "balance_state": "Debit",
            "amount": 100,
            "status": "Draft",
        }
    )
    assert "name" not in role and "parent" not in role
    assert "name" not in opening and "parent" not in opening
    assert role["company"] == opening["company"] == "Company B"
