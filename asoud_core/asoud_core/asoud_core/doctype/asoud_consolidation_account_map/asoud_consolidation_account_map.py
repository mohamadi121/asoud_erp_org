from frappe.model.document import Document


class ASOUDConsolidationAccountMap(Document):
    def validate(self) -> None:
        import frappe

        company_holding = frappe.db.get_value("Company", self.company, "asoud_holding")
        account = frappe.db.get_value(
            "Account", self.account, ["company", "is_group", "root_type"], as_dict=True
        )
        if company_holding != self.holding:
            frappe.throw("Mapped company must belong to the selected holding")
        if not account or account.company != self.company or account.is_group:
            frappe.throw("Mapped account must be a leaf account of the selected company")
        self.root_type = account.root_type
        duplicate = frappe.db.exists(
            "ASOUD Consolidation Account Map",
            {
                "holding": self.holding,
                "company": self.company,
                "account": self.account,
                "name": ["!=", self.name],
            },
        )
        if duplicate:
            frappe.throw("This company account already has a consolidation mapping")
