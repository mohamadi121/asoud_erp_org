from __future__ import annotations

from erpnext.accounts.doctype.journal_entry.journal_entry import JournalEntry


class ASOUDJournalEntry(JournalEntry):
    """Extend the standard v15 GL map without modifying ERPNext core."""

    def build_gl_map(self):
        gl_map = super().build_gl_map()
        source_rows = [
            row
            for row in self.get("accounts")
            if row.debit or row.credit or self.voucher_type == "Exchange Gain Or Loss"
        ]
        for gl_entry, source in zip(gl_map, source_rows, strict=True):
            gl_entry["asoud_branch"] = source.get("asoud_branch") or self.get("asoud_branch")
            if not source.get("asoud_floating_detail"):
                continue
            gl_entry.update(
                {
                    "asoud_floating_detail": source.asoud_floating_detail,
                    "asoud_detail_code": source.asoud_detail_code,
                    "asoud_detail_type": source.asoud_detail_type,
                    "asoud_source_row": source.name,
                    # ASOUD detail is an accounting dimension. Different details
                    # on the same account must never be merged into one GL row.
                    "_skip_merge": 1,
                }
            )
        return gl_map
