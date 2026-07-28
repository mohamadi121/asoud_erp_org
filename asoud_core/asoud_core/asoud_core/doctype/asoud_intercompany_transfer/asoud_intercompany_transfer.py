from frappe.model.document import Document


class ASOUDIntercompanyTransfer(Document):
    def validate(self) -> None:
        from asoud_core.services.intercompany import validate_intercompany_transfer

        validate_intercompany_transfer(self)

    def on_submit(self) -> None:
        from asoud_core.services.intercompany import post_intercompany_transfer

        source, destination = post_intercompany_transfer(self)
        self.db_set("source_journal_entry", source)
        self.db_set("destination_journal_entry", destination)
        self.db_set("status", "Completed")

    def before_cancel(self) -> None:
        import frappe

        frappe.throw(
            "Completed intercompany transfers are immutable; create a compensating transfer"
        )
