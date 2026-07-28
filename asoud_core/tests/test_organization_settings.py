import pytest

from asoud_core.services.organization_settings import _boolean, _digits


@pytest.mark.parametrize(
    ("raw", "expected"),
    [
        ("001-234-5678", "0012345678"),
        ("۱۴۰۰۱۲۳۴۵۶۷", "14001234567"),
        (None, ""),
    ],
)
def test_digits_normalizes_ascii_input(raw, expected):
    assert _digits(raw) == expected


@pytest.mark.parametrize("raw", [True, 1, "1", "true", "yes"])
def test_boolean_truthy(raw):
    assert _boolean(raw)


@pytest.mark.parametrize("raw", [False, 0, "0", "false", "off", ""])
def test_boolean_falsey(raw):
    assert not _boolean(raw)
