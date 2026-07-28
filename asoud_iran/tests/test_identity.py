from asoud_iran.services.identity import is_valid_iranian_national_id, normalize_digits


def test_iranian_national_id_checksum():
    assert is_valid_iranian_national_id("0013542818")
    assert is_valid_iranian_national_id("۰۰۱۳۵۴۲۸۱۸")
    assert not is_valid_iranian_national_id("0013542819")
    assert not is_valid_iranian_national_id("1111111111")
    assert not is_valid_iranian_national_id("123")
    assert normalize_digits("۱۲۳٤٥") == "12345"
