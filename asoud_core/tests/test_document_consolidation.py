import pytest

from asoud_core.services.document_consolidation import _normalize_document_names


def test_normalizes_selected_document_names():
    assert _normalize_document_names('[" AD-2 ", "AD-1"]') == ["AD-2", "AD-1"]


def test_rejects_duplicate_document_selection():
    with pytest.raises(ValueError, match="only once"):
        _normalize_document_names(["AD-1", "AD-1"])


def test_rejects_non_list_document_payload():
    with pytest.raises(ValueError, match="JSON list"):
        _normalize_document_names('{"name": "AD-1"}')
