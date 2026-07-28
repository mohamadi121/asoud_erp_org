from frappe.model.document import Document


class ASOUDAccountingDocument(Document):
    def validate(self) -> None:
        if self.source_key != f"{self.source_doctype}::{self.source_name}":
            self.source_key = f"{self.source_doctype}::{self.source_name}"

