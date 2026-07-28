"""Pure domain PoC for Iranian accounting-document numbering.

The technical Frappe ``name`` and immutable temporary number are distinct from the
final accounting number. Final numbers may be recalculated only before a legal
lock. Persistence and permissions are deliberately delegated to future adapters.
"""

from __future__ import annotations

from dataclasses import dataclass, field, replace
from datetime import date, datetime
from typing import Iterable

try:
    from enum import StrEnum
except ImportError:  # Python 3.10 compatibility
    from enum import Enum

    class StrEnum(str, Enum):
        def __str__(self) -> str:
            return self.value


class NumberingError(ValueError):
    """Raised when a numbering invariant is violated."""


class DocumentState(StrEnum):
    APPROVED = "approved"
    FINAL_NUMBERED = "final_numbered"


@dataclass(frozen=True, slots=True)
class AccountingDocument:
    document_id: str
    company: str
    fiscal_year: str
    posting_date: date
    created_at: datetime
    temporary_number: int
    state: DocumentState = DocumentState.APPROVED
    final_number: int | None = None
    legally_locked: bool = False

    def __post_init__(self) -> None:
        if self.temporary_number <= 0:
            raise NumberingError("temporary_number must be positive")


@dataclass(frozen=True, slots=True)
class NumberHistory:
    document_id: str
    old_final_number: int | None
    new_final_number: int
    batch_id: str
    changed_at: datetime
    reason: str


@dataclass(frozen=True, slots=True)
class NumberingResult:
    documents: tuple[AccountingDocument, ...]
    history: tuple[NumberHistory, ...]


@dataclass(slots=True)
class TemporaryNumberSequence:
    """Issue immutable temporary numbers per company and fiscal year."""

    _last_numbers: dict[tuple[str, str], int] = field(default_factory=dict)

    def issue(self, company: str, fiscal_year: str) -> int:
        key = (company, fiscal_year)
        next_number = self._last_numbers.get(key, 0) + 1
        self._last_numbers[key] = next_number
        return next_number


class FinalNumberingService:
    """Assign a deterministic contiguous final sequence to an approved date range."""

    @staticmethod
    def renumber(
        documents: Iterable[AccountingDocument],
        *,
        company: str,
        fiscal_year: str,
        from_date: date,
        to_date: date,
        batch_id: str,
        changed_at: datetime,
        reason: str,
        start_number: int = 1,
    ) -> NumberingResult:
        if from_date > to_date:
            raise NumberingError("from_date must not be after to_date")
        if start_number <= 0:
            raise NumberingError("start_number must be positive")
        if not reason.strip():
            raise NumberingError("a reason is required")

        all_documents = tuple(documents)
        selected = [
            document
            for document in all_documents
            if document.company == company
            and document.fiscal_year == fiscal_year
            and from_date <= document.posting_date <= to_date
        ]
        if any(document.legally_locked for document in selected):
            raise NumberingError("legally locked documents cannot be renumbered")
        if any(document.state not in {DocumentState.APPROVED, DocumentState.FINAL_NUMBERED} for document in selected):
            raise NumberingError("all selected documents must be approved")

        ordered = sorted(
            selected,
            key=lambda document: (
                document.posting_date,
                document.created_at,
                document.temporary_number,
                document.document_id,
            ),
        )
        replacements: dict[str, AccountingDocument] = {}
        history: list[NumberHistory] = []
        for offset, document in enumerate(ordered):
            final_number = start_number + offset
            replacements[document.document_id] = replace(
                document,
                final_number=final_number,
                state=DocumentState.FINAL_NUMBERED,
            )
            if document.final_number != final_number:
                history.append(
                    NumberHistory(
                        document_id=document.document_id,
                        old_final_number=document.final_number,
                        new_final_number=final_number,
                        batch_id=batch_id,
                        changed_at=changed_at,
                        reason=reason,
                    )
                )

        result = tuple(replacements.get(document.document_id, document) for document in all_documents)
        FinalNumberingService._assert_invariants(result, selected_ids=set(replacements))
        return NumberingResult(documents=result, history=tuple(history))

    @staticmethod
    def _assert_invariants(
        documents: tuple[AccountingDocument, ...], *, selected_ids: set[str]
    ) -> None:
        document_ids = [document.document_id for document in documents]
        if len(document_ids) != len(set(document_ids)):
            raise NumberingError("document ids must be unique")

        temporary_keys = [
            (document.company, document.fiscal_year, document.temporary_number)
            for document in documents
        ]
        if len(temporary_keys) != len(set(temporary_keys)):
            raise NumberingError("temporary numbers must be unique per company/fiscal year")

        selected = [document for document in documents if document.document_id in selected_ids]
        final_numbers = [document.final_number for document in selected]
        if None in final_numbers or len(final_numbers) != len(set(final_numbers)):
            raise NumberingError("final numbers must be present and unique in the batch")

        final_keys = [
            (document.company, document.fiscal_year, document.final_number)
            for document in documents
            if document.final_number is not None
        ]
        if len(final_keys) != len(set(final_keys)):
            raise NumberingError("final numbers must be unique per company/fiscal year")
