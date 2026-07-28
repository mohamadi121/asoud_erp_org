from frappe.model.document import Document


class ASOUDPettyCashClaim(Document):
    def validate(self) -> None:
        from asoud_core.services.treasury import validate_petty_cash_claim

        validate_petty_cash_claim(self)

    def on_submit(self) -> None:
        from asoud_core.services.treasury import post_petty_cash_claim

        self.db_set("journal_entry", post_petty_cash_claim(self))
        self.db_set("status", "Settled")

    def before_cancel(self) -> None:
        from asoud_core.services.treasury import cancel_linked_journal

        cancel_linked_journal(self.journal_entry)

    def on_cancel(self) -> None:
        self.db_set("status", "Cancelled")
