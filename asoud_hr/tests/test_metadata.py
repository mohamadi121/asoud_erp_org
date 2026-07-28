import json
from pathlib import Path


def test_all_doctype_metadata_is_valid_json_and_uses_asoud_hr_module():
    root = Path("asoud_hr/asoud_hr/doctype")
    files = list(root.glob("*/*.json"))
    assert len(files) >= 11
    for path in files:
        data = json.loads(path.read_text(encoding="utf-8"))
        assert data["doctype"] == "DocType"
        assert data["module"] == "ASOUD HR"


def test_no_duplicate_core_master_doctypes_are_declared():
    names = {
        json.loads(path.read_text(encoding="utf-8"))["name"]
        for path in Path("asoud_hr/asoud_hr/doctype").glob("*/*.json")
    }
    assert not {
        "ASOUD Holding",
        "ASOUD Branch",
        "ASOUD User Context",
        "ASOUD User Access",
        "ASOUD Approval Request",
        "ASOUD Audit Event",
    } & names

