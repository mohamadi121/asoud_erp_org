from frappe.model.document import Document


class ASOUDAuditEvent(Document):
    def before_save(self) -> None:
        import frappe

        if not self.is_new():
            frappe.throw("Audit events are append-only")

    def on_trash(self) -> None:
        import frappe

        frappe.throw("Audit events cannot be deleted")
