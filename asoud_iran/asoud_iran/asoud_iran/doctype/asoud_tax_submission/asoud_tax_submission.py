from frappe.model.document import Document


class ASOUDTaxSubmission(Document):
    def validate(self) -> None:
        import frappe

        if self.invoice_kind != "Original" and not self.reference_tax_uid:
            frappe.throw("Adjusting tax invoices require the original tax UID")
        if self.has_value_changed("payload_json") and not getattr(
            frappe.flags, "asoud_tax_gateway", False
        ):
            frappe.throw("Tax payload snapshots can only be written by the gateway")

    def on_trash(self) -> None:
        import frappe

        if self.status not in {"Draft", "Queued"}:
            frappe.throw("Transmitted tax evidence cannot be deleted")
