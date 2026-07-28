from __future__ import annotations

import re


_PERSIAN_ARABIC_DIGITS = str.maketrans(
    "۰۱۲۳۴۵۶۷۸۹٠١٢٣٤٥٦٧٨٩",
    "01234567890123456789",
)


def normalize_digits(value: str) -> str:
    return (value or "").translate(_PERSIAN_ARABIC_DIGITS)


def is_valid_iranian_national_id(value: str) -> bool:
    digits = re.sub(r"\D", "", normalize_digits(value))
    if len(digits) != 10 or len(set(digits)) == 1:
        return False
    checksum = sum(int(digits[index]) * (10 - index) for index in range(9)) % 11
    expected = checksum if checksum < 2 else 11 - checksum
    return int(digits[-1]) == expected


def validate_employee_national_id(value: str | None) -> None:
    if not value:
        return
    if not is_valid_iranian_national_id(value):
        import frappe

        frappe.throw("Iranian employee national ID is invalid")
