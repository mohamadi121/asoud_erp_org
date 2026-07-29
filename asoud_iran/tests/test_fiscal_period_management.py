from __future__ import annotations

import pytest

from asoud_iran.services.fiscal_period_management import (
    normalize_fiscal_period,
    normalize_fiscal_year,
    normalize_period_lock,
)


def test_normalizes_fiscal_year() -> None:
    assert normalize_fiscal_year(
        {
            "year_name": " 1406 ",
            "from_date": "2027-03-21",
            "to_date": "2028-03-19",
        }
    ) == {
        "name": None,
        "year_name": "1406",
        "from_date": "2027-03-21",
        "to_date": "2028-03-19",
        "disabled": False,
    }


def test_normalizes_standard_fiscal_period() -> None:
    result = normalize_fiscal_period(
        {
            "fiscal_year": "1406",
            "period_name": "فروردین",
            "from_date": "2027-03-21",
            "to_date": "2027-04-20",
        }
    )
    assert result["period_type"] == "Standard"
    assert result["enabled"] is True


def test_period_rejects_invalid_range_and_type() -> None:
    with pytest.raises(ValueError, match="Unsupported"):
        normalize_fiscal_period(
            {
                "fiscal_year": "1406",
                "period_name": "x",
                "period_type": "Quarter",
                "from_date": "2027-03-21",
                "to_date": "2027-04-20",
            }
        )
    with pytest.raises(ValueError, match="cannot be after"):
        normalize_fiscal_year(
            {
                "year_name": "1406",
                "from_date": "2028-03-19",
                "to_date": "2027-03-21",
            }
        )


def test_period_lock_requires_reason() -> None:
    with pytest.raises(ValueError, match="reason"):
        normalize_period_lock(
            {
                "fiscal_year": "1406",
                "from_date": "2027-03-21",
                "to_date": "2027-04-20",
            }
        )
