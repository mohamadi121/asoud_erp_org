from frappe.model.document import Document


class ASOUDIdempotencyRecord(Document):
    def before_save(self) -> None:
        import frappe

        if not self.is_new():
            frappe.throw("Idempotency records are immutable")

    def on_trash(self) -> None:
        import frappe

        frappe.throw("Idempotency records cannot be deleted")
