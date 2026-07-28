"""Pure double-entry PoC for real Iranian closing/opening vouchers.

The engine models a continuous ledger safely:

1. temporary profit-and-loss balances close into retained earnings;
2. permanent balances close against a dedicated closing control account;
3. only those permanent balances reopen against an opening control account.

Consequently the next-year balance is restored once, not duplicated, while revenue
and expense accounts start at zero. The caller persists the generated vouchers via
ERPNext Journal Entry/GL Entry adapters in the production implementation.
"""

from __future__ import annotations

from dataclasses import dataclass
from decimal import Decimal
from enum import StrEnum
from typing import Iterable


ZERO = Decimal("0")


class FiscalClosingError(ValueError):
    """Raised when a fiscal-closing invariant is violated."""


class AccountKind(StrEnum):
    PERMANENT = "permanent"
    REVENUE = "revenue"
    EXPENSE = "expense"


@dataclass(frozen=True, slots=True)
class AccountBalance:
    account: str
    kind: AccountKind
    balance: Decimal
    party_type: str | None = None
    party: str | None = None
    cost_center: str | None = None
    project: str | None = None
    finance_book: str | None = None
    branch: str | None = None
    floating_detail: str | None = None

    @property
    def identity(self) -> tuple[str, ...]:
        return (
            self.account,
            self.party_type or "",
            self.party or "",
            self.cost_center or "",
            self.project or "",
            self.finance_book or "",
            self.branch or "",
            self.floating_detail or "",
        )


@dataclass(frozen=True, slots=True)
class VoucherLine:
    account: str
    debit: Decimal = ZERO
    credit: Decimal = ZERO
    party_type: str | None = None
    party: str | None = None
    cost_center: str | None = None
    project: str | None = None
    finance_book: str | None = None
    branch: str | None = None
    floating_detail: str | None = None

    def __post_init__(self) -> None:
        if self.debit < ZERO or self.credit < ZERO:
            raise FiscalClosingError("debit and credit cannot be negative")
        if (self.debit == ZERO) == (self.credit == ZERO):
            raise FiscalClosingError("a line must contain exactly one positive side")

    @property
    def signed_effect(self) -> Decimal:
        """Debit-positive signed effect used by this domain model."""

        return self.debit - self.credit

    @property
    def identity(self) -> tuple[str, ...]:
        return (
            self.account,
            self.party_type or "",
            self.party or "",
            self.cost_center or "",
            self.project or "",
            self.finance_book or "",
            self.branch or "",
            self.floating_detail or "",
        )


@dataclass(frozen=True, slots=True)
class Voucher:
    voucher_type: str
    batch_key: str
    lines: tuple[VoucherLine, ...]

    def __post_init__(self) -> None:
        if not self.lines:
            raise FiscalClosingError("voucher must contain lines")
        debit = sum((line.debit for line in self.lines), ZERO)
        credit = sum((line.credit for line in self.lines), ZERO)
        if debit != credit:
            raise FiscalClosingError(f"unbalanced voucher: debit={debit}, credit={credit}")


@dataclass(frozen=True, slots=True)
class FiscalCloseResult:
    profit_loss_closing: Voucher | None
    permanent_closing: Voucher | None
    opening: Voucher | None
    closing_profit: Decimal

    @property
    def vouchers(self) -> tuple[Voucher, ...]:
        return tuple(
            voucher
            for voucher in (self.profit_loss_closing, self.permanent_closing, self.opening)
            if voucher is not None
        )


class FiscalClosingEngine:
    """Generate balanced, reproducible fiscal closing/opening vouchers."""

    @staticmethod
    def generate(
        balances: Iterable[AccountBalance],
        *,
        batch_key: str,
        retained_earnings_account: str,
        closing_control_account: str,
        opening_control_account: str,
        completed_batch_keys: set[str] | None = None,
    ) -> FiscalCloseResult:
        if not batch_key.strip():
            raise FiscalClosingError("batch_key is required")
        if completed_batch_keys and batch_key in completed_batch_keys:
            raise FiscalClosingError("this fiscal closing batch has already been completed")

        balance_list = tuple(balance for balance in balances if balance.balance != ZERO)
        FiscalClosingEngine._assert_unique_accounts(balance_list)
        reserved = {retained_earnings_account, closing_control_account, opening_control_account}
        if len(reserved) != 3 or any(not account.strip() for account in reserved):
            raise FiscalClosingError("control accounts must be non-empty and distinct")
        if any(
            balance.account in {closing_control_account, opening_control_account}
            for balance in balance_list
        ):
            raise FiscalClosingError("input balances cannot contain opening/closing control accounts")
        if sum((balance.balance for balance in balance_list), ZERO) != ZERO:
            raise FiscalClosingError("source trial balance must be balanced")

        temporary = tuple(
            balance for balance in balance_list if balance.kind in {AccountKind.REVENUE, AccountKind.EXPENSE}
        )
        permanent = tuple(balance for balance in balance_list if balance.kind == AccountKind.PERMANENT)

        pnl_voucher, closing_profit = FiscalClosingEngine._close_temporary(
            temporary, batch_key=batch_key, retained_earnings_account=retained_earnings_account
        )
        adjusted_by_account = {balance.identity: balance for balance in permanent}
        if closing_profit != ZERO:
            retained_key = (retained_earnings_account, "", "", "", "", "", "", "")
            previous = adjusted_by_account.get(
                retained_key,
                AccountBalance(retained_earnings_account, AccountKind.PERMANENT, ZERO),
            )
            adjusted_by_account[retained_key] = AccountBalance(
                retained_earnings_account,
                AccountKind.PERMANENT,
                previous.balance - closing_profit,
            )
        adjusted_permanent = list(adjusted_by_account.values())

        permanent_voucher = FiscalClosingEngine._close_permanent(
            adjusted_permanent,
            batch_key=batch_key,
            control_account=closing_control_account,
        )
        opening_voucher = FiscalClosingEngine._open_permanent(
            adjusted_permanent,
            batch_key=batch_key,
            control_account=opening_control_account,
        )
        result = FiscalCloseResult(
            profit_loss_closing=pnl_voucher,
            permanent_closing=permanent_voucher,
            opening=opening_voucher,
            closing_profit=closing_profit,
        )
        FiscalClosingEngine._assert_no_double_count(
            balance_list,
            result,
            retained_earnings_account=retained_earnings_account,
        )
        return result

    @staticmethod
    def _line(balance: AccountBalance, *, debit: Decimal = ZERO, credit: Decimal = ZERO) -> VoucherLine:
        return VoucherLine(
            account=balance.account,
            debit=debit,
            credit=credit,
            party_type=balance.party_type,
            party=balance.party,
            cost_center=balance.cost_center,
            project=balance.project,
            finance_book=balance.finance_book,
            branch=balance.branch,
            floating_detail=balance.floating_detail,
        )

    @staticmethod
    def _opposite_line(balance: AccountBalance) -> VoucherLine:
        if balance.balance > ZERO:
            return FiscalClosingEngine._line(balance, credit=balance.balance)
        return FiscalClosingEngine._line(balance, debit=-balance.balance)

    @staticmethod
    def _same_side_line(balance: AccountBalance) -> VoucherLine:
        if balance.balance > ZERO:
            return FiscalClosingEngine._line(balance, debit=balance.balance)
        return FiscalClosingEngine._line(balance, credit=-balance.balance)

    @staticmethod
    def _balancing_line(account: str, existing: Iterable[VoucherLine]) -> VoucherLine:
        net = sum((line.signed_effect for line in existing), ZERO)
        if net > ZERO:
            return VoucherLine(account=account, credit=net)
        if net < ZERO:
            return VoucherLine(account=account, debit=-net)
        raise FiscalClosingError("a zero balancing line is not valid")

    @staticmethod
    def _close_temporary(
        balances: tuple[AccountBalance, ...], *, batch_key: str, retained_earnings_account: str
    ) -> tuple[Voucher | None, Decimal]:
        if not balances:
            return None, ZERO
        lines = [FiscalClosingEngine._opposite_line(balance) for balance in balances]
        net_before_close = sum((balance.balance for balance in balances), ZERO)
        if net_before_close != ZERO:
            lines.append(FiscalClosingEngine._balancing_line(retained_earnings_account, lines))
        # If temporary accounts net to zero, their opposite lines already balance.
        voucher = Voucher("profit_loss_closing", batch_key, tuple(lines))
        # Credit balances are negative in the debit-positive convention, so profit is -net.
        return voucher, -net_before_close

    @staticmethod
    def _close_permanent(
        balances: list[AccountBalance], *, batch_key: str, control_account: str
    ) -> Voucher | None:
        if not balances:
            return None
        lines = [FiscalClosingEngine._opposite_line(balance) for balance in balances]
        net = sum((line.signed_effect for line in lines), ZERO)
        if net != ZERO:
            lines.append(FiscalClosingEngine._balancing_line(control_account, lines))
        return Voucher("permanent_closing", batch_key, tuple(lines))

    @staticmethod
    def _open_permanent(
        balances: list[AccountBalance], *, batch_key: str, control_account: str
    ) -> Voucher | None:
        if not balances:
            return None
        lines = [FiscalClosingEngine._same_side_line(balance) for balance in balances]
        net = sum((line.signed_effect for line in lines), ZERO)
        if net != ZERO:
            lines.append(FiscalClosingEngine._balancing_line(control_account, lines))
        return Voucher("opening", batch_key, tuple(lines))

    @staticmethod
    def _assert_unique_accounts(balances: tuple[AccountBalance, ...]) -> None:
        identities = [balance.identity for balance in balances]
        if len(identities) != len(set(identities)):
            raise FiscalClosingError("each account/dimension identity must appear once")

    @staticmethod
    def _assert_no_double_count(
        original: tuple[AccountBalance, ...],
        result: FiscalCloseResult,
        *,
        retained_earnings_account: str,
    ) -> None:
        effects: dict[tuple[str, ...], Decimal] = {}
        for voucher in result.vouchers:
            for line in voucher.lines:
                effects[line.identity] = effects.get(line.identity, ZERO) + line.signed_effect

        for balance in original:
            ending = balance.balance + effects.get(balance.identity, ZERO)
            expected = balance.balance if balance.kind == AccountKind.PERMANENT else ZERO
            if balance.identity == (retained_earnings_account, "", "", "", "", "", "", ""):
                expected -= result.closing_profit
            if ending != expected:
                raise FiscalClosingError(
                    f"closing/opening invariant failed for {balance.account}: {ending} != {expected}"
                )
