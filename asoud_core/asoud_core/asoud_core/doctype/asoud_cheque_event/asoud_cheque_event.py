from frappe.model.document import Document


class ASOUDChequeEvent(Document):
    def before_insert(self) -> None:
        import frappe

        if not getattr(frappe.flags, "asoud_cheque_transition", False):
            frappe.throw("Cheque events can only be created by the transition service")
        self.event_by = frappe.session.user

    def validate(self) -> None:
        import frappe

        if not self.is_new():
            frappe.throw("Cheque events are immutable")
