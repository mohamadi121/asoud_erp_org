from frappe.model.document import Document


class ASOUDConsolidationAdjustment(Document):
    def validate(self) -> None:
        import frappe
        from frappe.utils import flt

        debit = flt(self.debit)
        credit = flt(self.credit)
        if debit < 0 or credit < 0 or (debit > 0) == (credit > 0):
            frappe.throw("Adjustment must contain exactly one positive debit or credit")
        if not frappe.db.exists("ASOUD Holding", {"name": self.holding, "enabled": 1}):
            frappe.throw("Adjustment holding must be enabled")
