from __future__ import annotations

from frappe.model.document import Document


class ASOUDItemCompanyProfile(Document):
    def autoname(self) -> None:
        self.profile_key = self._key()
        self.name = self.profile_key

    def validate(self) -> None:
        import frappe

        self.profile_key = self._key()
        if self.default_branch:
            branch = frappe.db.get_value(
                "ASOUD Branch", self.default_branch, ["company", "enabled"], as_dict=True
            )
            if not branch or branch.company != self.company or not branch.enabled:
                frappe.throw("Default branch must be an enabled branch of the profile company")
        if self.default_warehouse:
            warehouse = frappe.db.get_value(
                "Warehouse", self.default_warehouse, ["company", "asoud_branch"], as_dict=True
            )
            if not warehouse or warehouse.company != self.company:
                frappe.throw("Default warehouse must belong to the profile company")
            if self.default_branch and warehouse.asoud_branch != self.default_branch:
                frappe.throw("Default warehouse must belong to the profile branch")
        for fieldname in ("income_account", "expense_account"):
            account = self.get(fieldname)
            if account and frappe.db.get_value("Account", account, "company") != self.company:
                frappe.throw(f"{fieldname.replace('_', ' ').title()} must belong to the profile company")

    def _key(self) -> str:
        if not self.item or not self.company:
            return ""
        return f"{self.item}|{self.company}"
