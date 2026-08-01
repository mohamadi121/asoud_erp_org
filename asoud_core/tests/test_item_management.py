import pytest

from asoud_core.services.item_management import normalize_item_payload


def test_normalizes_goods_and_company_policy():
    values = normalize_item_payload(
        {
            "item_name": "کالای نمونه",
            "item_kind": "Goods",
            "item_group": "Products",
            "stock_uom": "Nos",
            "enabled": False,
            "default_branch": "HQ",
            "default_warehouse": "Stores - A",
        }
    )
    assert values["item_kind"] == "Goods"
    assert values["enabled"] is False
    assert values["default_branch"] == "HQ"


def test_service_rejects_invalid_kind_and_empty_name():
    with pytest.raises(ValueError, match="Item name"):
        normalize_item_payload({"item_kind": "Service"})
    with pytest.raises(ValueError, match="Unsupported item kind"):
        normalize_item_payload({"item_name": "X", "item_kind": "Asset"})
