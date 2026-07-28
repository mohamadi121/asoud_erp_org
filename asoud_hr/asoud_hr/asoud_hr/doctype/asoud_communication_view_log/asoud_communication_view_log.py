from frappe.model.document import Document


class ASOUDCommunicationViewLog(Document):
    def before_save(self) -> None:
        if not self.is_new():
            import frappe

            frappe.throw("Communication view logs are immutable")

    def on_trash(self) -> None:
        import frappe

        frappe.throw("Communication view logs cannot be deleted")
