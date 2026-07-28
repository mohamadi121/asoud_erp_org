from frappe.model.document import Document


class ASOUDEmploymentStatusHistory(Document):
    def before_save(self) -> None:
        if not self.is_new():
            import frappe

            frappe.throw("Employment status history is immutable")

    def on_trash(self) -> None:
        import frappe

        frappe.throw("Employment status history cannot be deleted")
