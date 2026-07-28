from datetime import date, datetime, timezone

import pytest

from asoud_core.accounting_document.numbering import (
    AccountingDocument,
    FinalNumberingService,
    NumberingError,
    TemporaryNumberSequence,
)


UTC = timezone.utc


def document(identifier: str, day: int, temporary: int, final: int | None = None):
    return AccountingDocument(
        document_id=identifier,
        company="ASOUD",
        fiscal_year="1405",
        posting_date=date(2026, 4, day),
        created_at=datetime(2026, 4, day, 10, tzinfo=UTC),
        temporary_number=temporary,
        final_number=final,
    )


def test_temporary_sequence_is_isolated_by_company_and_year():
    sequence = TemporaryNumberSequence()
    assert sequence.issue("A", "1405") == 1
    assert sequence.issue("A", "1405") == 2
    assert sequence.issue("B", "1405") == 1
    assert sequence.issue("A", "1406") == 1


def test_final_numbering_sorts_by_posting_date_and_preserves_temporary_number():
    documents = [document("late", 3, 1), document("early", 1, 2)]
    result = FinalNumberingService.renumber(
        documents,
        company="ASOUD",
        fiscal_year="1405",
        from_date=date(2026, 4, 1),
        to_date=date(2026, 4, 30),
        batch_id="batch-1",
        changed_at=datetime(2026, 5, 1, tzinfo=UTC),
        reason="initial numbering",
    )
    by_id = {item.document_id: item for item in result.documents}
    assert by_id["early"].final_number == 1
    assert by_id["late"].final_number == 2
    assert by_id["early"].temporary_number == 2
    assert by_id["late"].temporary_number == 1


def test_late_document_causes_renumbering_and_keeps_complete_history():
    existing = [document("first", 2, 1, 1), document("second", 3, 2, 2)]
    late = document("late", 1, 3)
    result = FinalNumberingService.renumber(
        [*existing, late],
        company="ASOUD",
        fiscal_year="1405",
        from_date=date(2026, 4, 1),
        to_date=date(2026, 4, 30),
        batch_id="batch-2",
        changed_at=datetime(2026, 5, 2, tzinfo=UTC),
        reason="insert late approved document",
    )
    by_id = {item.document_id: item for item in result.documents}
    assert [by_id[key].final_number for key in ("late", "first", "second")] == [1, 2, 3]
    history = {item.document_id: (item.old_final_number, item.new_final_number) for item in result.history}
    assert history == {"late": (None, 1), "first": (1, 2), "second": (2, 3)}


def test_legal_lock_blocks_renumbering():
    from dataclasses import replace

    locked = replace(document("locked", 1, 1, 1), legally_locked=True)
    with pytest.raises(NumberingError, match="legally locked"):
        FinalNumberingService.renumber(
            [locked],
            company="ASOUD",
            fiscal_year="1405",
            from_date=date(2026, 4, 1),
            to_date=date(2026, 4, 30),
            batch_id="batch-3",
            changed_at=datetime(2026, 5, 2, tzinfo=UTC),
            reason="must fail",
        )


def test_partial_batch_cannot_collide_with_an_existing_final_number():
    previous = document("previous", 1, 1, 1)
    current = document("current", 2, 2)
    with pytest.raises(NumberingError, match="final numbers must be unique"):
        FinalNumberingService.renumber(
            [previous, current],
            company="ASOUD",
            fiscal_year="1405",
            from_date=date(2026, 4, 2),
            to_date=date(2026, 4, 2),
            batch_id="batch-4",
            changed_at=datetime(2026, 5, 2, tzinfo=UTC),
            reason="invalid start number",
            start_number=1,
        )
