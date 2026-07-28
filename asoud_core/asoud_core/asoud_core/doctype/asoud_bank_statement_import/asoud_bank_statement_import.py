from frappe.model.document import Document


class ASOUDBankStatementImport(Document):
    def validate(self) -> None:
        import frappe

        if not getattr(frappe.flags, "asoud_bank_import", False):
            frappe.throw("Bank statement imports can only be created by the controlled importer")

    def on_trash(self) -> None:
        import frappe

        frappe.throw("Bank statement import evidence is immutable")
