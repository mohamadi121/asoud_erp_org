from frappe.model.document import Document


class ASOUDFXPolicy(Document):
    def validate(self) -> None:
        import frappe

        holding_currency = frappe.db.get_value(
            "ASOUD Holding", self.holding, "consolidation_currency"
        )
        if not holding_currency or holding_currency != self.reporting_currency:
            frappe.throw("FX policy currency must equal the holding consolidation currency")
        if not self.cta_account_code:
            frappe.throw("Currency translation adjustment account is required")
