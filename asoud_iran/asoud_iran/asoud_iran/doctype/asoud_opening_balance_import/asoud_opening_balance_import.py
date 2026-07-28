from frappe.model.document import Document


class ASOUDOpeningBalanceImport(Document):
    def validate(self) -> None:
        from asoud_iran.services.opening_import import validate_import

        validate_import(self)

    def on_submit(self) -> None:
        from asoud_iran.services.opening_import import post_import

        self.db_set("journal_entry", post_import(self))
        self.db_set("status", "Imported")

    def before_cancel(self) -> None:
        from asoud_core.services.treasury import cancel_linked_journal

        cancel_linked_journal(self.journal_entry)

    def on_cancel(self) -> None:
        self.db_set("status", "Cancelled")
