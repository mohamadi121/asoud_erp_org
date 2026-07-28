from __future__ import annotations

from frappe.model.document import Document


class ASOUDPartyCompanyProfile(Document):
    def autoname(self) -> None:
        self.profile_key = self._key()
        self.name = self.profile_key

    def validate(self) -> None:
        import frappe

        self.profile_key = self._key()
        if not frappe.db.exists(self.party_type, self.party):
            frappe.throw(f"{self.party_type} does not exist")
        if self.default_branch:
            branch = frappe.db.get_value(
                "ASOUD Branch", self.default_branch, ["company", "enabled"], as_dict=True
            )
            if not branch or branch.company != self.company or not branch.enabled:
                frappe.throw("Default branch must be an enabled branch of the profile company")
        if self.default_account:
            account = frappe.db.get_value(
                "Account", self.default_account, ["company", "account_type"], as_dict=True
            )
            expected = "Receivable" if self.party_type == "Customer" else "Payable"
            if not account or account.company != self.company or account.account_type != expected:
                frappe.throw(f"Default account must be a {expected} account of the profile company")

    def _key(self) -> str:
        if not self.party_type or not self.party or not self.company:
            return ""
        return f"{self.party_type}|{self.party}|{self.company}"
