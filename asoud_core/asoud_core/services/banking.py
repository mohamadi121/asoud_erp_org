from __future__ import annotations

import csv
from dataclasses import dataclass
from datetime import date
from decimal import Decimal, InvalidOperation
import hashlib
import io
import json
import re
from typing import Any

SAYAD_STATES = {
    "Draft": {"Issued", "Cancelled"},
    "Issued": {"Confirmed", "Rejected", "Transferred", "Cancelled"},
    "Confirmed": {"Transferred", "Settled", "Returned"},
    "Transferred": {"Confirmed", "Settled", "Returned"},
    "Rejected": set(),
    "Settled": set(),
    "Returned": set(),
    "Cancelled": set(),
}


def statement_checksum(content: bytes) -> str:
    return hashlib.sha256(content).hexdigest()


def scoped_fingerprint(scope: str, digest: str) -> str:
    if not scope or not re.fullmatch(r"[0-9a-f]{64}", digest):
        raise ValueError("A scope and SHA-256 digest are required")
    return hashlib.sha256(f"{scope}:{digest}".encode()).hexdigest()


def _amount(value: Any) -> Decimal:
    try:
        amount = Decimal(str(value or "0").replace(",", "")).quantize(Decimal("0.01"))
    except InvalidOperation as exc:
        raise ValueError("Invalid bank statement amount") from exc
    if amount < 0:
        raise ValueError("Bank statement amounts must be non-negative")
    return amount


def parse_statement_csv(content: bytes) -> list[dict[str, Any]]:
    """Parse the documented ASOUD interchange CSV; never guess a bank's private format."""
    text = content.decode("utf-8-sig")
    reader = csv.DictReader(io.StringIO(text))
    required = {"date", "reference", "description", "deposit", "withdrawal"}
    if not reader.fieldnames or not required.issubset(set(reader.fieldnames)):
        raise ValueError(f"Statement columns must include: {', '.join(sorted(required))}")
    rows = []
    seen: set[str] = set()
    for index, source in enumerate(reader, 2):
        try:
            posting_date = date.fromisoformat(str(source["date"]).strip()).isoformat()
        except ValueError as exc:
            raise ValueError(f"Invalid ISO date at CSV row {index}") from exc
        deposit, withdrawal = _amount(source["deposit"]), _amount(source["withdrawal"])
        if (deposit > 0) == (withdrawal > 0):
            raise ValueError(f"CSV row {index} must contain exactly one deposit or withdrawal")
        reference = str(source["reference"] or "").strip()
        fingerprint = hashlib.sha256(
            json.dumps(
                [posting_date, reference, str(deposit), str(withdrawal)],
                separators=(",", ":"),
            ).encode()
        ).hexdigest()
        if fingerprint in seen:
            raise ValueError(f"Duplicate bank transaction at CSV row {index}")
        seen.add(fingerprint)
        rows.append(
            {
                "posting_date": posting_date,
                "reference": reference,
                "description": str(source["description"] or "").strip(),
                "deposit": float(deposit),
                "withdrawal": float(withdrawal),
                "fingerprint": fingerprint,
            }
        )
    if not rows:
        raise ValueError("Bank statement is empty")
    return rows


@dataclass(frozen=True)
class ReconciliationCandidate:
    voucher: str
    score: int
    reasons: tuple[str, ...]


def reconciliation_candidates(
    transaction: dict[str, Any],
    ledger_rows: list[dict[str, Any]],
    *,
    date_tolerance_days: int = 3,
) -> list[ReconciliationCandidate]:
    target_amount = Decimal(str(transaction["deposit"] or transaction["withdrawal"]))
    target_date = date.fromisoformat(str(transaction["posting_date"]))
    candidates = []
    for row in ledger_rows:
        if Decimal(str(row.get("amount") or 0)).quantize(Decimal("0.01")) != target_amount:
            continue
        row_date = date.fromisoformat(str(row["posting_date"]))
        days = abs((row_date - target_date).days)
        if days > date_tolerance_days:
            continue
        score, reasons = 70 - (days * 5), ["exact_amount", f"date_delta:{days}"]
        if transaction.get("reference") and transaction["reference"] == row.get("reference"):
            score += 30
            reasons.append("exact_reference")
        candidates.append(
            ReconciliationCandidate(str(row["voucher"]), score, tuple(reasons))
        )
    return sorted(candidates, key=lambda candidate: (-candidate.score, candidate.voucher))


def validate_sayad_id(value: str) -> str:
    normalized = re.sub(r"\s+", "", str(value or ""))
    if not re.fullmatch(r"\d{16}", normalized):
        raise ValueError("Sayad ID must contain exactly 16 digits")
    return normalized


def transition_sayad(current: str, target: str) -> str:
    if target not in SAYAD_STATES.get(current, set()):
        raise ValueError(f"Invalid Sayad transition: {current} -> {target}")
    return target


def assert_bank_production_ready(
    *, environment: str, secret_reference: str | None, provider_profile: str | None
) -> None:
    if environment == "Production" and (not secret_reference or not provider_profile):
        raise ValueError(
            "Production bank/Sayad access is fail-closed until a contracted provider "
            "profile and secret reference are configured"
        )
