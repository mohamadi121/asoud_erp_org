from frappe.model.document import Document


class ASOUDCashCount(Document):
    def validate(self) -> None:
        from asoud_core.services.treasury import validate_cash_count

        validate_cash_count(self)

    def on_submit(self) -> None:
        from asoud_core.services.treasury import post_cash_count

        journal = post_cash_count(self)
        if journal:
            self.db_set("journal_entry", journal)
            self.db_set("status", "Adjusted")
        else:
            self.db_set("status", "Balanced")

    def before_cancel(self) -> None:
        from asoud_core.services.treasury import cancel_linked_journal

        cancel_linked_journal(self.journal_entry)

    def on_cancel(self) -> None:
        self.db_set("status", "Cancelled")
