from __future__ import annotations

import pytest

from asoud_iran.services.floating_detail_management import (
    normalize_detail_payload,
    normalize_group_payload,
)


def test_normalize_group_payload() -> None:
    assert normalize_group_payload(
        {
            "group_title": "  مشتریان ",
            "group_code": " cus ",
            "detail_type": "Customer",
        }
    ) == {
        "name": None,
        "group_title": "مشتریان",
        "group_code": "CUS",
        "detail_type": "Customer",
        "parent_group": None,
        "enabled": True,
    }


def test_group_rejects_unknown_type() -> None:
    with pytest.raises(ValueError, match="Unsupported"):
        normalize_group_payload(
            {"group_title": "x", "group_code": "x", "detail_type": "Unknown"}
        )


def test_normalize_detail_requires_complete_reference_pair() -> None:
    with pytest.raises(ValueError, match="provided together"):
        normalize_detail_payload(
            {
                "detail_title": "مشتری نمونه",
                "detail_group": "CUS",
                "detail_code": "1001",
                "reference_doctype": "Customer",
            }
        )


def test_normalize_detail_payload() -> None:
    result = normalize_detail_payload(
        {
            "detail_title": " مشتری نمونه ",
            "detail_group": "CUS",
            "detail_code": " 1001 ",
            "enabled": 1,
            "company_enabled": True,
        }
    )
    assert result["detail_title"] == "مشتری نمونه"
    assert result["detail_code"] == "1001"
    assert result["enabled"] is True
