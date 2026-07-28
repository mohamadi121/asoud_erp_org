from frappe.model.document import Document


class ASOUDTaxEvent(Document):
    def before_insert(self) -> None:
        import frappe

        if not getattr(frappe.flags, "asoud_tax_gateway", False):
            frappe.throw("Tax events can only be created by the gateway")

    def validate(self) -> None:
        import frappe

        if not self.is_new():
            frappe.throw("Tax events are immutable")

    def on_trash(self) -> None:
        import frappe

        frappe.throw("Tax events are immutable")
