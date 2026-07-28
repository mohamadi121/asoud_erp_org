from __future__ import annotations

from dataclasses import dataclass
from decimal import Decimal, ROUND_HALF_UP
from typing import Any

RATE_TYPE_BY_ROOT = {
    "Asset": "Closing",
    "Liability": "Closing",
    "Income": "Average",
    "Expense": "Average",
    "Equity": "Historical",
}


@dataclass(frozen=True)
class TranslationResult:
    rows: list[dict[str, Any]]
    cta: Decimal


def required_rate_type(root_type: str) -> str:
    try:
        return RATE_TYPE_BY_ROOT[root_type]
    except KeyError as exc:
        raise ValueError(f"Unsupported consolidation root type: {root_type}") from exc


def translate_balances(
    rows: list[dict[str, Any]],
    rates: dict[tuple[str, str], Decimal | float | str],
    *,
    reporting_currency: str,
    cta_account_code: str,
    cta_account_title: str = "Currency Translation Adjustment",
) -> TranslationResult:
    translated = []
    total = Decimal("0")
    for source in rows:
        currency = str(source["currency"])
        rate_type = required_rate_type(str(source["root_type"]))
        if currency == reporting_currency:
            rate = Decimal("1")
        else:
            key = (currency, rate_type)
            if key not in rates:
                raise ValueError(f"Missing {rate_type} rate for {currency}")
            rate = Decimal(str(rates[key]))
            if rate <= 0:
                raise ValueError("Currency translation rate must be greater than zero")
        source_balance = Decimal(str(source.get("balance") or 0))
        balance = (source_balance * rate).quantize(Decimal("0.01"), ROUND_HALF_UP)
        total += balance
        translated.append(
            {
                **source,
                "source_balance": float(source_balance),
                "source_currency": currency,
                "rate_type": rate_type,
                "rate": float(rate),
                "currency": reporting_currency,
                "balance": float(balance),
            }
        )
    cta = (-total).quantize(Decimal("0.01"), ROUND_HALF_UP)
    if cta:
        translated.append(
            {
                "account_code": cta_account_code,
                "account_title": cta_account_title,
                "root_type": "Equity",
                "source_balance": 0.0,
                "source_currency": reporting_currency,
                "rate_type": "CTA",
                "rate": 1.0,
                "currency": reporting_currency,
                "balance": float(cta),
            }
        )
    return TranslationResult(translated, cta)


def select_rate(
    rate_rows: list[dict[str, Any]],
    *,
    currency: str,
    rate_type: str,
    posting_date: str,
    period_from: str,
    period_to: str,
) -> Decimal:
    """Select approved evidence deterministically; ambiguity fails instead of guessing."""
    eligible = []
    for row in rate_rows:
        if row["source_currency"] != currency or row["rate_type"] != rate_type:
            continue
        start, end = str(row["effective_from"]), str(row.get("effective_to") or row["effective_from"])
        if rate_type == "Average":
            match = start == period_from and end == period_to
        else:
            match = start <= posting_date and (not row.get("effective_to") or posting_date <= end)
        if match:
            eligible.append(row)
    if len(eligible) != 1:
        raise ValueError(
            f"Expected exactly one approved {rate_type} rate for {currency}; "
            f"found {len(eligible)}"
        )
    rate = Decimal(str(eligible[0]["rate"]))
    if rate <= 0:
        raise ValueError("Currency translation rate must be greater than zero")
    return rate
