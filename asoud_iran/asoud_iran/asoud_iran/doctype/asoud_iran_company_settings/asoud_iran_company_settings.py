try:
    from frappe.model.document import Document
except ModuleNotFoundError:  # pragma: no cover
    Document = object


class ASOUDIranCompanySettings(Document):
    def validate(self) -> None:
        import frappe

        if self.base_currency != "IRR":
            frappe.throw("Iranian ledger currency must be IRR")
        if self.timezone != "Asia/Tehran":
            frappe.throw("Iranian accounting timezone must be Asia/Tehran")
        company_currency = frappe.db.get_value("Company", self.company, "default_currency")
        if company_currency != "IRR":
            frappe.throw(f"Company {self.company} must use IRR as default currency")
        if frappe.db.get_value("ASOUD COA Template", self.coa_template, "docstatus") != 1:
            frappe.throw("Only a submitted COA template can be installed")

