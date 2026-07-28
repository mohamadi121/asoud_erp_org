from frappe.model.document import Document


class ASOUDBranch(Document):
    def validate(self) -> None:
        import frappe

        if not self.is_new():
            previous_company = frappe.db.get_value("ASOUD Branch", self.name, "company")
            if previous_company and previous_company != self.company:
                frappe.throw("A branch company cannot be changed after the branch is created")

        self.holding = frappe.db.get_value("Company", self.company, "asoud_holding")
        self._validate_company_link("Warehouse", self.default_warehouse)
        self._validate_company_link("Cost Center", self.default_cost_center)

    def _validate_company_link(self, doctype: str, value: str | None) -> None:
        if not value:
            return
        import frappe

        linked_company = frappe.db.get_value(doctype, value, "company")
        if linked_company != self.company:
            frappe.throw(f"The selected {doctype} does not belong to the branch company")
