from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
import hashlib
import json
from typing import Any, Protocol
from urllib.parse import urlparse

TAX_SCHEMA_VERSION = "1.0"
INVOICE_KINDS = {"Original", "Correction", "Cancellation", "Return"}
TERMINAL_STATES = {"Accepted", "Rejected"}


def canonical_json(value: Any) -> str:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"), default=str)


def checksum(value: Any) -> str:
    return hashlib.sha256(canonical_json(value).encode("utf-8")).hexdigest()


def build_tax_invoice(
    *,
    company_identity: dict[str, Any],
    invoice: dict[str, Any],
    items: list[dict[str, Any]],
    invoice_kind: str = "Original",
    reference_tax_uid: str | None = None,
) -> dict[str, Any]:
    """Build an immutable, provider-neutral Iranian tax invoice envelope.

    Mapping to a production provider is deliberately kept in a versioned adapter;
    the accounting source and this canonical snapshot never depend on one vendor.
    """
    if invoice_kind not in INVOICE_KINDS:
        raise ValueError("Unsupported tax invoice kind")
    if invoice_kind != "Original" and not reference_tax_uid:
        raise ValueError("A correction, cancellation or return requires the original tax UID")
    required_identity = ("national_id", "economic_code")
    if any(not str(company_identity.get(key) or "").strip() for key in required_identity):
        raise ValueError("Company national ID and economic code are required")
    if not items:
        raise ValueError("A tax invoice requires at least one item")

    normalized_items = []
    total_before_tax = total_tax = total_payable = 0
    for position, source in enumerate(items, 1):
        quantity = float(source.get("quantity") or 0)
        unit_price = float(source.get("unit_price") or 0)
        discount = float(source.get("discount") or 0)
        tax = float(source.get("tax") or 0)
        if quantity <= 0 or unit_price < 0 or discount < 0 or tax < 0:
            raise ValueError("Tax invoice quantities and monetary values must be non-negative")
        before_tax = round(quantity * unit_price - discount, 2)
        payable = round(before_tax + tax, 2)
        if before_tax < 0:
            raise ValueError("Item discount cannot exceed gross value")
        normalized_items.append(
            {
                "position": position,
                "item_code": str(source.get("item_code") or ""),
                "description": str(source.get("description") or ""),
                "quantity": quantity,
                "unit": str(source.get("unit") or ""),
                "unit_price": unit_price,
                "discount": discount,
                "before_tax": before_tax,
                "tax": tax,
                "payable": payable,
            }
        )
        total_before_tax += before_tax
        total_tax += tax
        total_payable += payable

    envelope = {
        "schema_version": TAX_SCHEMA_VERSION,
        "invoice_kind": invoice_kind,
        "source": {
            "doctype": str(invoice.get("doctype") or "Sales Invoice"),
            "name": str(invoice.get("name") or ""),
            "posting_date": str(invoice.get("posting_date") or ""),
            "currency": str(invoice.get("currency") or "IRR"),
        },
        "seller": {
            "national_id": str(company_identity["national_id"]).strip(),
            "economic_code": str(company_identity["economic_code"]).strip(),
        },
        "buyer": {
            "name": str(invoice.get("buyer_name") or ""),
            "national_id": str(invoice.get("buyer_national_id") or ""),
            "economic_code": str(invoice.get("buyer_economic_code") or ""),
        },
        "reference_tax_uid": reference_tax_uid,
        "items": normalized_items,
        "totals": {
            "before_tax": round(total_before_tax, 2),
            "tax": round(total_tax, 2),
            "payable": round(total_payable, 2),
        },
    }
    envelope["checksum"] = checksum(envelope)
    return envelope


def validate_https_endpoint(base_url: str, allowed_hosts: set[str]) -> str:
    parsed = urlparse(base_url)
    if parsed.scheme != "https" or not parsed.hostname or parsed.username or parsed.password:
        raise ValueError("Production tax endpoint must be a credential-free HTTPS URL")
    if parsed.hostname.lower() not in {host.lower() for host in allowed_hosts}:
        raise ValueError("Tax endpoint host is not allowlisted")
    return base_url.rstrip("/")


@dataclass(frozen=True)
class GatewayResult:
    state: str
    provider_reference: str
    response: dict[str, Any]


class TaxAdapter(Protocol):
    def submit(self, payload: dict[str, Any], idempotency_key: str) -> GatewayResult: ...


class SandboxTaxAdapter:
    """Deterministic local adapter. It can never be selected as a production signer."""

    def submit(self, payload: dict[str, Any], idempotency_key: str) -> GatewayResult:
        if not idempotency_key:
            raise ValueError("Idempotency key is required")
        digest = checksum({"key": idempotency_key, "payload": payload})
        state = "Rejected" if payload.get("_sandbox_force_reject") else "Accepted"
        return GatewayResult(
            state=state,
            provider_reference=f"SBX-{digest[:24].upper()}",
            response={
                "sandbox": True,
                "received_at": datetime.now(timezone.utc).isoformat(),
                "payload_checksum": payload.get("checksum") or checksum(payload),
            },
        )


def assert_production_credentials(
    *,
    environment: str,
    certificate_reference: str | None,
    secret_reference: str | None,
) -> None:
    if environment != "Production":
        return
    if not certificate_reference or not secret_reference:
        raise ValueError(
            "Production tax transmission is fail-closed until certificate and secret "
            "references are configured"
        )
