from datetime import date

import pytest

from asoud_iran.accounting.jalali import (
    JalaliDateError,
    format_jalali,
    gregorian_to_jalali,
    jalali_to_gregorian,
    parse_jalali,
)


@pytest.mark.parametrize(
    ("gregorian", "jalali"),
    [
        ((2026, 3, 21), (1405, 1, 1)),
        ((2027, 3, 20), (1405, 12, 29)),
        ((2024, 3, 20), (1403, 1, 1)),
        ((2025, 3, 20), (1403, 12, 30)),
        ((2000, 1, 1), (1378, 10, 11)),
    ],
)
def test_known_calendar_boundaries(gregorian, jalali):
    assert gregorian_to_jalali(*gregorian) == jalali
    assert jalali_to_gregorian(*jalali) == gregorian


def test_string_helpers_round_trip():
    assert parse_jalali("1405/01/01") == date(2026, 3, 21)
    assert format_jalali("2026-03-21") == "1405-01-01"


@pytest.mark.parametrize("value", ["1404-12-30", "1405-07-31", "invalid"])
def test_invalid_jalali_dates_are_rejected(value):
    with pytest.raises(JalaliDateError):
        parse_jalali(value)
