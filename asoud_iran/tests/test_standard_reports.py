import csv
import io

from asoud_iran.services.standard_reports import (
    _split_balance,
    canonical_checksum,
    render_csv,
)


def test_canonical_checksum_is_order_independent_and_utf8_safe():
    first = {"title": "دفتر روزنامه", "totals": {"debit": 10, "credit": 10}}
    second = {"totals": {"credit": 10, "debit": 10}, "title": "دفتر روزنامه"}

    assert canonical_checksum(first) == canonical_checksum(second)


def test_split_balance_keeps_debit_and_credit_sides_exclusive():
    assert _split_balance(125) == (125.0, 0.0)
    assert _split_balance(-75) == (0.0, 75.0)


def test_csv_export_has_utf8_bom_and_uses_canonical_columns():
    report = {
        "title": "دفتر روزنامه",
        "company": "شرکت نمونه",
        "branch": None,
        "from_date_jalali": "1405-01-01",
        "to_date_jalali": "1405-12-29",
        "currency": "IRR",
        "columns": [
            {"key": "account", "label": "حساب"},
            {"key": "debit", "label": "بدهکار"},
        ],
        "rows": [{"account": "نقد", "debit": 100}],
        "totals": {"debit": 100},
        "checksum": "abc",
    }

    payload = render_csv(report)
    assert payload.startswith(b"\xef\xbb\xbf")
    rows = list(csv.reader(io.StringIO(payload.decode("utf-8-sig"))))
    assert ["حساب", "بدهکار"] in rows
    assert ["نقد", "100"] in rows
