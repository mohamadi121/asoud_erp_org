from decimal import Decimal

import pytest

from asoud_iran.closing_opening.engine import (
    AccountBalance,
    AccountKind,
    FiscalClosingEngine,
    FiscalClosingError,
    ZERO,
)


def sample_balances():
    return [
        AccountBalance("Cash", AccountKind.PERMANENT, Decimal("1200")),
        AccountBalance("Payables", AccountKind.PERMANENT, Decimal("-200")),
        AccountBalance("Capital", AccountKind.PERMANENT, Decimal("-600")),
        AccountBalance("Revenue", AccountKind.REVENUE, Decimal("-1000")),
        AccountBalance("Expense", AccountKind.EXPENSE, Decimal("600")),
    ]


def generate(completed=None):
    return FiscalClosingEngine.generate(
        sample_balances(),
        batch_key="ASOUD-1405",
        retained_earnings_account="Retained Earnings",
        closing_control_account="Closing Control",
        opening_control_account="Opening Control",
        completed_batch_keys=completed,
    )


def test_all_generated_vouchers_are_balanced():
    result = generate()
    for voucher in result.vouchers:
        debit = sum((line.debit for line in voucher.lines), ZERO)
        credit = sum((line.credit for line in voucher.lines), ZERO)
        assert debit == credit


def test_profit_is_transferred_and_temporary_accounts_are_not_reopened():
    result = generate()
    assert result.closing_profit == Decimal("400")
    assert result.opening is not None
    opened_accounts = {line.account for line in result.opening.lines}
    assert "Revenue" not in opened_accounts
    assert "Expense" not in opened_accounts
    assert "Retained Earnings" in opened_accounts


def test_closing_then_opening_restores_permanent_balances_exactly_once():
    result = generate()
    effects = {}
    for voucher in result.vouchers:
        for line in voucher.lines:
            effects[line.account] = effects.get(line.account, ZERO) + line.signed_effect

    original = {item.account: item for item in sample_balances()}
    assert original["Cash"].balance + effects["Cash"] == Decimal("1200")
    assert original["Payables"].balance + effects["Payables"] == Decimal("-200")
    assert original["Capital"].balance + effects["Capital"] == Decimal("-600")
    assert original["Revenue"].balance + effects["Revenue"] == ZERO
    assert original["Expense"].balance + effects["Expense"] == ZERO


def test_opening_lines_exactly_restore_adjusted_permanent_closing_lines():
    result = generate()
    assert result.permanent_closing is not None
    assert result.opening is not None
    excluded = {"Closing Control", "Opening Control"}
    closing = {
        line.account: line.signed_effect
        for line in result.permanent_closing.lines
        if line.account not in excluded
    }
    opening = {
        line.account: line.signed_effect
        for line in result.opening.lines
        if line.account not in excluded
    }
    assert opening == {account: -effect for account, effect in closing.items()}


def test_completed_batch_cannot_be_generated_twice():
    with pytest.raises(FiscalClosingError, match="already been completed"):
        generate(completed={"ASOUD-1405"})


def test_existing_retained_earnings_is_preserved_and_current_profit_added_once():
    balances = [
        AccountBalance("Cash", AccountKind.PERMANENT, Decimal("1300")),
        AccountBalance("Payables", AccountKind.PERMANENT, Decimal("-200")),
        AccountBalance("Capital", AccountKind.PERMANENT, Decimal("-600")),
        AccountBalance("Retained Earnings", AccountKind.PERMANENT, Decimal("-100")),
        AccountBalance("Revenue", AccountKind.REVENUE, Decimal("-1000")),
        AccountBalance("Expense", AccountKind.EXPENSE, Decimal("600")),
    ]
    result = FiscalClosingEngine.generate(
        balances,
        batch_key="ASOUD-1405-existing-retained",
        retained_earnings_account="Retained Earnings",
        closing_control_account="Closing Control",
        opening_control_account="Opening Control",
    )
    effects = {}
    for voucher in result.vouchers:
        for line in voucher.lines:
            effects[line.account] = effects.get(line.account, ZERO) + line.signed_effect
    assert Decimal("-100") + effects["Retained Earnings"] == Decimal("-500")


def test_unbalanced_source_trial_balance_is_rejected():
    with pytest.raises(FiscalClosingError, match="trial balance"):
        FiscalClosingEngine.generate(
            [AccountBalance("Cash", AccountKind.PERMANENT, Decimal("1"))],
            batch_key="bad",
            retained_earnings_account="Retained Earnings",
            closing_control_account="Closing Control",
            opening_control_account="Opening Control",
        )


def test_party_and_dimensions_survive_permanent_close_and_open():
    balances = [
        AccountBalance(
            "Receivable",
            AccountKind.PERMANENT,
            Decimal("100"),
            party_type="Customer",
            party="CUST-1",
            cost_center="Main",
            branch="Tehran",
            floating_detail="FD-1",
        ),
        AccountBalance("Capital", AccountKind.PERMANENT, Decimal("-100")),
    ]
    result = FiscalClosingEngine.generate(
        balances,
        batch_key="dimensional",
        retained_earnings_account="Retained Earnings",
        closing_control_account="Closing Control",
        opening_control_account="Opening Control",
    )
    assert result.permanent_closing is not None
    assert result.opening is not None
    source = balances[0]
    closing_line = next(line for line in result.permanent_closing.lines if line.account == "Receivable")
    opening_line = next(line for line in result.opening.lines if line.account == "Receivable")
    assert closing_line.identity == source.identity
    assert opening_line.identity == source.identity
    assert closing_line.signed_effect == -opening_line.signed_effect
