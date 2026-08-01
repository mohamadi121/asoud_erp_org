from frappe.model.document import Document


class ASOUDDocumentConsolidation(Document):
    def validate(self) -> None:
        import frappe
        from frappe.utils import getdate

        if len(self.documents or []) < 2:
            frappe.throw("A consolidation requires at least two documents")
        document_names = [item.accounting_document for item in self.documents]
        placeholders = ", ".join(["%s"] * len(document_names))
        locked_names = {
            row[0]
            for row in frappe.db.sql(
                f"select name from `tabASOUD Accounting Document` "
                f"where name in ({placeholders}) for update",
                tuple(document_names),
                as_list=True,
            )
        }
        if locked_names != set(document_names):
            frappe.throw("One or more accounting documents do not exist")
        seen: set[str] = set()
        for item in self.documents:
            if item.accounting_document in seen:
                frappe.throw("A document may appear only once in a consolidation")
            seen.add(item.accounting_document)
            row = frappe.db.get_value(
                "ASOUD Accounting Document",
                item.accounting_document,
                ["company", "posting_date", "numbering_status", "consolidation", "source_doctype", "source_name", "temporary_number"],
                as_dict=True,
            )
            if (
                not row
                or row.company != self.company
                or getdate(row.posting_date) != getdate(self.posting_date)
            ):
                frappe.throw("All consolidated documents must belong to the same company and posting date")
            if row.numbering_status != "Temporary" or row.consolidation:
                frappe.throw("Only unnumbered, unconsolidated documents can be selected")
            item.source_doctype = row.source_doctype
            item.source_name = row.source_name
            item.temporary_number = row.temporary_number

    def on_submit(self) -> None:
        import frappe

        for item in self.documents:
            frappe.db.set_value(
                "ASOUD Accounting Document",
                item.accounting_document,
                "consolidation",
                self.name,
                update_modified=False,
            )

    def on_cancel(self) -> None:
        import frappe

        numbered = frappe.db.exists(
            "ASOUD Accounting Document",
            {"consolidation": self.name, "final_number": [">", 0]},
        )
        if numbered:
            frappe.throw("A numbered consolidation cannot be cancelled; use a reversal")
        frappe.db.set_value(
            "ASOUD Accounting Document",
            {"consolidation": self.name},
            "consolidation",
            None,
            update_modified=False,
        )
