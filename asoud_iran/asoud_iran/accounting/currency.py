from __future__ import annotations

from decimal import Decimal, InvalidOperation
from typing import Any

IRR = "IRR"
TOMAN = "TOMAN"
SUPPORTED_UNITS = (IRR, TOMAN)


class AmountError(ValueError):
    """Raised when an amount cannot be represented as an exact rial value."""


def _decimal(value: Any) -> Decimal:
    if isinstance(value, float):
        raise AmountError("Floating-point amounts are not accepted; send a string or integer")
    try:
        amount = Decimal(str(value).strip())
    except (InvalidOperation, ValueError) as exc:
        raise AmountError("Amount is not a valid decimal number") from exc
    if not amount.is_finite():
        raise AmountError("Amount must be finite")
    return amount


def to_irr(value: Any, unit: str) -> int:
    """Convert an explicit IRR/Toman amount to an exact integer rial amount."""
    normalized_unit = str(unit).strip().upper()
    if normalized_unit not in SUPPORTED_UNITS:
        raise AmountError(f"Unsupported amount unit: {unit}")
    result = _decimal(value) * (10 if normalized_unit == TOMAN else 1)
    integral = result.to_integral_value()
    if result != integral:
        raise AmountError("Amount resolves to a fractional rial")
    return int(integral)


def from_irr(value: Any, unit: str) -> str:
    """Render an integer rial value using an explicit output unit."""
    rial = _decimal(value)
    if rial != rial.to_integral_value():
        raise AmountError("Ledger amount must be an integer rial value")
    normalized_unit = str(unit).strip().upper()
    if normalized_unit == IRR:
        return str(int(rial))
    if normalized_unit != TOMAN:
        raise AmountError(f"Unsupported amount unit: {unit}")
    toman = rial / 10
    return format(toman, "f").rstrip("0").rstrip(".") if toman else "0"


def normalize_api_amount(value: Any, input_unit: str, output_unit: str = IRR) -> dict[str, str]:
    """Return a transport-safe amount; API numbers are always encoded as strings."""
    rial = to_irr(value, input_unit)
    return {
        "amount": from_irr(rial, output_unit),
        "unit": output_unit.upper(),
        "ledger_amount": str(rial),
        "ledger_unit": IRR,
    }

