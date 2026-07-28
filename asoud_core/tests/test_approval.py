from datetime import date, time, timedelta

import pytest

from asoud_core.services.approval import (
    document_digest,
    next_sequence,
    normalize_date,
    normalize_stages,
    normalize_time,
    normalize_inbox_request,
    required_keys,
)


def test_approval_inbox_views_statuses_and_limits_are_fail_closed():
    assert normalize_inbox_request(" History ", "approved", 500) == (
        "history",
        "Approved",
        100,
    )
    assert normalize_inbox_request("", "", 0) == ("incoming", "", 50)
    with pytest.raises(ValueError, match="view"):
        normalize_inbox_request("all", "", 50)
    with pytest.raises(ValueError, match="status"):
        normalize_inbox_request("outgoing", "Deleted", 50)


def test_policy_stages_are_normalized_and_parallel_rows_are_preserved():
    stages = normalize_stages(
        [
            {
                "name": "finance",
                "sequence": 1,
                "stage_title": "Finance",
                "approver_type": "Role",
                "role": "Accounts Manager",
            },
            {
                "name": "ceo",
                "sequence": 2,
                "stage_title": "CEO",
                "approver_type": "User",
                "user": "ceo@example.com",
            },
            {
                "name": "controller",
                "sequence": 1,
                "stage_title": "Controller",
                "approver_type": "User",
                "user": "controller@example.com",
            },
        ]
    )

    assert [row["key"] for row in stages] == ["controller", "finance", "ceo"]
    assert required_keys(stages, 1, "All") == {"controller", "finance"}
    assert len(required_keys(stages, 1, "Any")) == 1
    assert next_sequence(stages, 1) == 2
    assert next_sequence(stages, 2) is None


def test_direct_manager_is_a_supported_dynamic_approver():
    stages = normalize_stages(
        [
            {
                "sequence": 1,
                "stage_title": "Direct Manager",
                "approver_type": "Manager",
            }
        ]
    )

    assert stages[0]["approver_type"] == "Manager"
    assert stages[0]["approver"] == "Direct Manager"


def test_policy_rejects_missing_or_non_contiguous_stages():
    with pytest.raises(ValueError, match="at least one"):
        normalize_stages([])
    with pytest.raises(ValueError, match="contiguous"):
        normalize_stages(
            [
                {
                    "sequence": 2,
                    "approver_type": "Role",
                    "role": "Accounts Manager",
                }
            ]
        )
    with pytest.raises(ValueError, match="identify"):
        normalize_stages(
            [{"sequence": 1, "approver_type": "User", "user": ""}]
        )


def test_document_digest_ignores_framework_metadata_and_approval_markers():
    original = {
        "doctype": "Payment Entry",
        "name": "PAY-1",
        "company": "A",
        "paid_amount": 100,
        "modified": "2026-01-01",
        "docstatus": 0,
        "asoud_approval_status": "Pending",
    }
    changed_metadata = {
        **original,
        "modified": "2026-01-02",
        "asoud_approval_status": "Approved",
        "asoud_approval_request": "APR-1",
        "docstatus": 1,
    }
    changed_amount = {**changed_metadata, "paid_amount": 101}

    assert document_digest(original) == document_digest(changed_metadata)
    assert document_digest(original) != document_digest(changed_amount)


def test_access_schedule_date_and_time_values_are_normalized():
    assert normalize_date("2026-07-26") == date(2026, 7, 26)
    assert normalize_date(date(2026, 7, 27)) == date(2026, 7, 27)
    assert normalize_time("08:30:15") == time(8, 30, 15)
    assert normalize_time(timedelta(hours=17, minutes=45)) == time(17, 45)
    assert normalize_date(None) is None
    assert normalize_time("") is None
