from frappe.model.document import Document


class ASOUDFXRate(Document):
    def autoname(self) -> None:
        self.name = (
            f"{self.holding}|{self.source_currency}|{self.reporting_currency}|"
            f"{self.rate_type}|{self.effective_from}|{self.effective_to or '-'}"
        )

    def validate(self) -> None:
        import frappe
        from frappe.utils import flt, getdate

        if self.source_currency == self.reporting_currency:
            frappe.throw("An FX rate requires different source and reporting currencies")
        if flt(self.rate) <= 0:
            frappe.throw("FX rate must be greater than zero")
        if self.effective_to and getdate(self.effective_from) > getdate(self.effective_to):
            frappe.throw("FX rate effective range is invalid")
        if self.rate_type == "Average" and not self.effective_to:
            frappe.throw("Average rates require an explicit period end")
        holding_currency = frappe.db.get_value(
            "ASOUD Holding", self.holding, "consolidation_currency"
        )
        if holding_currency != self.reporting_currency:
            frappe.throw("FX reporting currency must equal holding consolidation currency")
        if self.docstatus == 1 and (not self.source_reference or not self.approved_by):
            frappe.throw("Submitted FX rates require source evidence and approver")
