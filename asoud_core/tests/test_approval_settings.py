import json

import pytest

from asoud_core.services.approval_settings import _normalize_payload


def test_normalizes_sequential_and_parallel_approval_rows() -> None:
    values = _normalize_payload(
        json.dumps(
            {
                "policy_title": "Purchase approval",
                "stages": [
                    {
                        "sequence": 1,
                        "stage_title": "Branch managers",
                        "approver_type": "Role",
                        "role": "Accounts Manager",
                    },
                    {
                        "sequence": 1,
                        "stage_title": "Named approver",
                        "approver_type": "User",
                        "user": "approver@example.com",
                    },
                    {
                        "sequence": 2,
                        "stage_title": "Direct manager",
                        "approver_type": "Manager",
                        "due_hours": 24,
                    },
                ],
            }
        )
    )

    assert [row["sequence"] for row in values["stages"]] == [1, 1, 2]
    assert values["stages"][0]["role"] == "Accounts Manager"
    assert values["stages"][1]["user"] == "approver@example.com"
    assert values["stages"][2]["due_hours"] == 24


@pytest.mark.parametrize(
    "stages, message",
    [
        ([], "at least one"),
        (
            [{"sequence": 1, "approver_type": "User"}],
            "user approver",
        ),
        (
            [
                {"sequence": 1, "approver_type": "Manager"},
                {"sequence": 3, "approver_type": "Manager"},
            ],
            "contiguous",
        ),
    ],
)
def test_rejects_invalid_policy_stages(stages, message) -> None:
    with pytest.raises(ValueError, match=message):
        _normalize_payload({"stages": stages})
