import pytest

from asoud_core.services.production import validate_production_origin


def test_production_origin_requires_https_and_real_host():
    assert validate_production_origin("https://erp.example.ir/") == "https://erp.example.ir"
    with pytest.raises(ValueError, match="HTTPS"):
        validate_production_origin("http://erp.example.ir")
    with pytest.raises(ValueError, match="localhost"):
        validate_production_origin("https://localhost")


def test_production_origin_rejects_credential_and_query_injection():
    with pytest.raises(ValueError, match="credentials"):
        validate_production_origin("https://user:pass@erp.example.ir")
    with pytest.raises(ValueError, match="query"):
        validate_production_origin("https://erp.example.ir?next=bad")
