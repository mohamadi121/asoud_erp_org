from __future__ import annotations

import json
from pathlib import Path


DOCTYPE_ROOT = (
    Path(__file__).parents[1]
    / "asoud_core"
    / "asoud_core"
    / "doctype"
)


def test_every_exported_doctype_has_an_importable_controller_module() -> None:
    missing: list[str] = []
    for definition in DOCTYPE_ROOT.glob("*/*.json"):
        payload = json.loads(definition.read_text(encoding="utf-8"))
        if payload.get("doctype") != "DocType":
            continue
        controller = definition.with_suffix(".py")
        if not controller.is_file():
            missing.append(payload.get("name") or definition.stem)

    assert missing == [], f"Missing DocType Python controllers: {missing}"
