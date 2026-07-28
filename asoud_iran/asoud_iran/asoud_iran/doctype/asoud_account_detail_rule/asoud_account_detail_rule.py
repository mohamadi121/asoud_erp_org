try:
    from frappe.model.document import Document
except ModuleNotFoundError:  # pragma: no cover
    Document = object


class ASOUDAccountDetailRule(Document):
    def validate(self) -> None:
        import frappe

        account = frappe.db.get_value(
            "Account",
            self.account,
            ["company", "is_group"],
            as_dict=True,
        )
        if not account or account.company != self.company:
            frappe.throw("Account does not belong to the selected company")
        if account.is_group:
            frappe.throw("Floating detail rules can only target postable accounts")
        duplicate = frappe.db.exists(
            "ASOUD Account Detail Rule",
            {
                "company": self.company,
                "account": self.account,
                "detail_type": self.detail_type,
                "name": ["!=", self.name or ""],
            },
        )
        if duplicate:
            frappe.throw("This account/detail-type rule already exists")
