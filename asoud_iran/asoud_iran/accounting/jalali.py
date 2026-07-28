from __future__ import annotations

from datetime import date


class JalaliDateError(ValueError):
    """Raised for an invalid Gregorian or Jalali calendar value."""


def gregorian_to_jalali(year: int, month: int, day: int) -> tuple[int, int, int]:
    date(year, month, day)
    month_days = (0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334)
    adjusted_year = year + 1 if month > 2 else year
    days = (
        355666
        + (365 * year)
        + ((adjusted_year + 3) // 4)
        - ((adjusted_year + 99) // 100)
        + ((adjusted_year + 399) // 400)
        + day
        + month_days[month - 1]
    )
    jalali_year = -1595 + (33 * (days // 12053))
    days %= 12053
    jalali_year += 4 * (days // 1461)
    days %= 1461
    if days > 365:
        jalali_year += (days - 1) // 365
        days = (days - 1) % 365
    if days < 186:
        return jalali_year, 1 + (days // 31), 1 + (days % 31)
    return jalali_year, 7 + ((days - 186) // 30), 1 + ((days - 186) % 30)


def jalali_to_gregorian(year: int, month: int, day: int) -> tuple[int, int, int]:
    if not (1 <= month <= 12 and 1 <= day <= 31):
        raise JalaliDateError("Invalid Jalali month or day")
    source_year = year
    year += 1595
    days = (
        -355668
        + (365 * year)
        + ((year // 33) * 8)
        + (((year % 33) + 3) // 4)
        + day
        + ((month - 1) * 31 if month < 7 else ((month - 7) * 30) + 186)
    )
    gregorian_year = 400 * (days // 146097)
    days %= 146097
    if days > 36524:
        days -= 1
        gregorian_year += 100 * (days // 36524)
        days %= 36524
        if days >= 365:
            days += 1
    gregorian_year += 4 * (days // 1461)
    days %= 1461
    if days > 365:
        gregorian_year += (days - 1) // 365
        days = (days - 1) % 365
    gregorian_day = days + 1
    leap = (
        gregorian_year % 4 == 0
        and gregorian_year % 100 != 0
        or gregorian_year % 400 == 0
    )
    gregorian_month_days = (
        0,
        31,
        29 if leap else 28,
        31,
        30,
        31,
        30,
        31,
        31,
        30,
        31,
        30,
        31,
    )
    gregorian_month = 1
    while gregorian_month <= 12 and gregorian_day > gregorian_month_days[gregorian_month]:
        gregorian_day -= gregorian_month_days[gregorian_month]
        gregorian_month += 1
    result = gregorian_year, gregorian_month, gregorian_day
    if gregorian_to_jalali(*result) != (source_year, month, day):
        raise JalaliDateError("Invalid Jalali date")
    return result


def parse_jalali(value: str) -> date:
    """Parse YYYY-MM-DD or YYYY/MM/DD into a canonical Gregorian date."""
    normalized = str(value).strip().replace("/", "-")
    try:
        parts = tuple(int(part) for part in normalized.split("-"))
    except ValueError as exc:
        raise JalaliDateError("Jalali date must use YYYY-MM-DD") from exc
    if len(parts) != 3:
        raise JalaliDateError("Jalali date must use YYYY-MM-DD")
    try:
        return date(*jalali_to_gregorian(*parts))
    except (TypeError, ValueError) as exc:
        if isinstance(exc, JalaliDateError):
            raise
        raise JalaliDateError("Invalid Jalali date") from exc


def format_jalali(value: date | str) -> str:
    if isinstance(value, str):
        try:
            value = date.fromisoformat(value)
        except ValueError as exc:
            raise JalaliDateError("Gregorian date must use YYYY-MM-DD") from exc
    year, month, day = gregorian_to_jalali(value.year, value.month, value.day)
    return f"{year:04d}-{month:02d}-{day:02d}"

