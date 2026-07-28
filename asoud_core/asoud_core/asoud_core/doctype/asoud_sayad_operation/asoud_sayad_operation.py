from frappe.model.document import Document


class ASOUDSayadOperation(Document):
    def validate(self) -> None:
        import frappe

        from asoud_core.services.banking import validate_sayad_id

        try:
            self.sayad_id = validate_sayad_id(self.sayad_id)
        except ValueError as exc:
            frappe.throw(str(exc))
        cheque = frappe.db.get_value(
            "ASOUD Cheque", self.cheque, ["company", "branch"], as_dict=True
        )
        if not cheque or cheque.company != self.company or cheque.branch != self.branch:
            frappe.throw("Sayad operation and cheque context must match")
        if not self.is_new() and not getattr(frappe.flags, "asoud_sayad_gateway", False):
            frappe.throw("Sayad state can only be changed by the gateway")
