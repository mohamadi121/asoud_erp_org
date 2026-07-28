from frappe.model.document import Document


class ASOUDBankStatementLine(Document):
    def validate(self) -> None:
        import frappe

        if not self.is_new() and self.has_value_changed("matched_voucher"):
            if not getattr(frappe.flags, "asoud_bank_reconcile", False):
                frappe.throw("Bank matches can only be changed by the reconciliation service")
        elif self.is_new() and not getattr(frappe.flags, "asoud_bank_import", False):
            frappe.throw("Bank lines can only be created by the controlled importer")

    def on_trash(self) -> None:
        import frappe

        frappe.throw("Bank statement evidence is immutable")
