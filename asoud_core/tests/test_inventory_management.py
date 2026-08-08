import pytest

from asoud_core.services.inventory_management import normalize_setting_payload


def test_normalizes_company_warehouse_setting() -> None:
    values = normalize_setting_payload(
        "Warehouse",
        {
            "warehouse_name": "مواد اولیه",
            "branch": "HQ",
            "warehouse_type": "Raw Material",
            "is_group": False,
        },
    )
    assert values["warehouse_name"] == "مواد اولیه"
    assert values["branch"] == "HQ"
    assert values["is_group"] is False


def test_normalizes_unit_conversion() -> None:
    values = normalize_setting_payload(
        "UOM Conversion Factor",
        {
            "category": "Weight",
            "from_uom": "Kg",
            "to_uom": "Gram",
            "value": 1000,
        },
    )
    assert values["value"] == 1000


@pytest.mark.parametrize(
    "setting_type,payload,message",
    [
        ("Warehouse", {}, "Warehouse name"),
        ("UOM", {}, "Unit of measure"),
        (
            "UOM Conversion Factor",
            {"category": "Weight", "from_uom": "Kg", "to_uom": "Kg", "value": 1},
            "different",
        ),
        (
            "UOM Conversion Factor",
            {"category": "Weight", "from_uom": "Kg", "to_uom": "Gram", "value": 0},
            "positive",
        ),
    ],
)
def test_rejects_invalid_inventory_settings(setting_type, payload, message) -> None:
    with pytest.raises(ValueError, match=message):
        normalize_setting_payload(setting_type, payload)
