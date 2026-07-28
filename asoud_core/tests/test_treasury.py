from asoud_core.services.treasury import (
    INCOMING_TRANSITIONS,
    OUTGOING_TRANSITIONS,
    _row,
)


def test_incoming_cheque_supports_return_and_recovery_without_invalid_shortcut():
    assert ("Received", "Returned") in INCOMING_TRANSITIONS
    assert ("Returned", "Received") in INCOMING_TRANSITIONS
    assert ("Draft", "Cleared") not in INCOMING_TRANSITIONS
    assert ("Returned", "Cleared") not in INCOMING_TRANSITIONS


def test_outgoing_cheque_requires_issue_before_clearance():
    assert ("Draft", "Issued") in OUTGOING_TRANSITIONS
    assert ("Issued", "Cleared") in OUTGOING_TRANSITIONS
    assert ("Draft", "Cleared") not in OUTGOING_TRANSITIONS


def test_journal_row_keeps_party_and_floating_detail_dimensions():
    row = _row(
        "Receivable - A",
        1250,
        debit=True,
        detail="CUSTOMER-DETAIL",
        party_type="Customer",
        party="CUSTOMER-1",
    )

    assert row == {
        "account": "Receivable - A",
        "debit_in_account_currency": 1250,
        "asoud_floating_detail": "CUSTOMER-DETAIL",
        "party_type": "Customer",
        "party": "CUSTOMER-1",
    }
