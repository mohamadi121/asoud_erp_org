from frappe.model.document import Document


class ASOUDBankReconciliation(Document):
    def validate(self) -> None:
        from asoud_core.services.treasury import validate_bank_reconciliation

        validate_bank_reconciliation(self)

    def on_submit(self) -> None:
        self.db_set("status", "Reconciled" if not self.difference else "Exception")

    def on_cancel(self) -> None:
        self.db_set("status", "Cancelled")
