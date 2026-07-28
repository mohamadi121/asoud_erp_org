from frappe.model.document import Document


class ASOUDTreasuryTransaction(Document):
    def validate(self) -> None:
        from asoud_core.services.treasury import validate_treasury_transaction

        validate_treasury_transaction(self)

    def on_submit(self) -> None:
        from asoud_core.services.treasury import post_treasury_transaction

        self.db_set("journal_entry", post_treasury_transaction(self))
        self.db_set("status", "Posted")

    def before_cancel(self) -> None:
        from asoud_core.services.treasury import cancel_linked_journal

        cancel_linked_journal(self.journal_entry)

    def on_cancel(self) -> None:
        self.db_set("status", "Cancelled")
