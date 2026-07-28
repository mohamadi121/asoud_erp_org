from frappe.model.document import Document


class ASOUDCommunicationReply(Document):
    def before_save(self) -> None:
        if not self.is_new():
            import frappe

            frappe.throw("Communication replies are immutable")

    def on_trash(self) -> None:
        import frappe

        frappe.throw("Communication replies cannot be deleted")
