import pytest

from asoud_iran.services.tax_gateway import (
    SandboxTaxAdapter,
    assert_production_credentials,
    build_tax_invoice,
    validate_https_endpoint,
)


def _payload(kind="Original", reference=None):
    return build_tax_invoice(
        company_identity={"national_id": "10100000000", "economic_code": "411111111111"},
        invoice={
            "name": "SINV-1",
            "posting_date": "2026-07-26",
            "currency": "IRR",
            "buyer_name": "Buyer",
        },
        items=[
            {
                "item_code": "A",
                "quantity": 2,
                "unit": "عدد",
                "unit_price": 100,
                "discount": 10,
                "tax": 19,
            }
        ],
        invoice_kind=kind,
        reference_tax_uid=reference,
    )


def test_tax_payload_is_canonical_balanced_and_deterministic():
    first = _payload()
    second = _payload()
    assert first["checksum"] == second["checksum"]
    assert first["totals"] == {"before_tax": 190.0, "tax": 19.0, "payable": 209.0}


def test_adjusting_invoice_requires_original_uid():
    with pytest.raises(ValueError, match="original tax UID"):
        _payload("Correction")


def test_sandbox_is_idempotent_and_explicit():
    result1 = SandboxTaxAdapter().submit(_payload(), "SINV-1:Original")
    result2 = SandboxTaxAdapter().submit(_payload(), "SINV-1:Original")
    assert result1.provider_reference == result2.provider_reference
    assert result1.state == "Accepted"
    assert result1.response["sandbox"] is True


def test_production_is_fail_closed_and_endpoint_is_allowlisted():
    with pytest.raises(ValueError, match="fail-closed"):
        assert_production_credentials(
            environment="Production", certificate_reference=None, secret_reference=None
        )
    assert (
        validate_https_endpoint("https://tax.example.test/v1", {"tax.example.test"})
        == "https://tax.example.test/v1"
    )
    with pytest.raises(ValueError, match="allowlisted"):
        validate_https_endpoint("https://evil.example/v1", {"tax.example.test"})
