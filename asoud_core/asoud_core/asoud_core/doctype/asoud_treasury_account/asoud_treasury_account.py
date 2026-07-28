from frappe.model.document import Document


class ASOUDTreasuryAccount(Document):
    def autoname(self) -> None:
        self.account_key = self._key()
        self.name = self.account_key

    def validate(self) -> None:
        import frappe

        self.account_key = self._key()
        branch = frappe.db.get_value(
            "ASOUD Branch", self.branch, ["company", "enabled"], as_dict=True
        )
        if not branch or not branch.enabled or branch.company != self.company:
            frappe.throw("Treasury branch must be enabled and belong to the company")
        account = frappe.db.get_value(
            "Account", self.ledger_account, ["company", "is_group"], as_dict=True
        )
        if not account or account.company != self.company or account.is_group:
            frappe.throw("Treasury ledger account must be a leaf account of the company")
        duplicate = frappe.db.exists(
            "ASOUD Treasury Account",
            {
                "ledger_account": self.ledger_account,
                "enabled": 1,
                "name": ["!=", self.name or ""],
            },
        )
        if duplicate:
            frappe.throw("Each enabled treasury account must have a unique ledger account")
        if self.treasury_type == "Bank" and self.bank_account:
            bank_company = frappe.db.get_value("Bank Account", self.bank_account, "company")
            if bank_company != self.company:
                frappe.throw("Bank Account must belong to the treasury company")

    def _key(self) -> str:
        return f"{self.company}|{self.branch}|{self.account_code}" if self.company and self.branch and self.account_code else ""
