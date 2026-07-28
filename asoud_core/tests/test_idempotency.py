import pytest

from asoud_core.services.idempotency import request_digest, validate_request_key


def test_idempotency_digest_is_stable_for_equivalent_payloads():
    assert request_digest({"b": 2, "a": 1}) == request_digest({"a": 1, "b": 2})
    assert request_digest({"a": 1}) != request_digest({"a": 2})


def test_idempotency_key_is_long_and_header_safe():
    assert validate_request_key("pwa-20260726-1234567890") == "pwa-20260726-1234567890"
    for invalid in ("short", "contains space and is long", "../unsafe-key-value"):
        with pytest.raises(ValueError):
            validate_request_key(invalid)
