from __future__ import annotations

import hashlib
import json
import re

try:
    from frappe.model.document import Document
except ModuleNotFoundError:  # pragma: no cover - permits pure unit imports
    Document = object


def template_content(template) -> list[dict]:
    return [
        {
            "account_code": row.account_code,
            "account_name": row.account_name,
            "parent_account_code": row.parent_account_code or "",
            "root_type": row.root_type,
            "is_group": int(row.is_group),
            "account_type": row.account_type or "",
            "requires_floating_detail": int(row.requires_floating_detail),
        }
        for row in sorted(template.accounts, key=lambda item: item.idx)
    ]


def content_hash(template) -> str:
    payload = json.dumps(
        template_content(template),
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    )
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


class ASOUDCOATemplate(Document):
    def validate(self) -> None:
        import frappe

        self.template_code = (self.template_code or "").strip().upper()
        self.version = (self.version or "").strip()
        if not re.fullmatch(r"[A-Z0-9_-]+", self.template_code):
            frappe.throw("Template Code may contain only A-Z, numbers, underscore and dash")
        if self.base_currency != "IRR":
            frappe.throw("Iranian chart templates must use IRR as base currency")
        seen: set[str] = set()
        for row in self.accounts:
            row.account_code = (row.account_code or "").strip()
            row.parent_account_code = (row.parent_account_code or "").strip()
            if not row.account_code.isdigit():
                frappe.throw(f"Account code must be numeric: {row.account_code}")
            if row.account_code in seen:
                frappe.throw(f"Duplicate account code: {row.account_code}")
            if row.parent_account_code and row.parent_account_code not in seen:
                frappe.throw(
                    f"Parent {row.parent_account_code} must appear before {row.account_code}"
                )
            if not row.is_group and row.account_type in {"", None}:
                row.account_type = ""
            seen.add(row.account_code)
        self.content_hash = content_hash(self)

    def before_submit(self) -> None:
        self.validate()

