from frappe.model.document import Document


class ASOUDSayadEvent(Document):
    def before_insert(self) -> None:
        import frappe

        if not getattr(frappe.flags, "asoud_sayad_gateway", False):
            frappe.throw("Sayad events can only be created by the gateway")

    def validate(self) -> None:
        import frappe

        if not self.is_new():
            frappe.throw("Sayad events are immutable")

    def on_trash(self) -> None:
        import frappe

        frappe.throw("Sayad events are immutable")
