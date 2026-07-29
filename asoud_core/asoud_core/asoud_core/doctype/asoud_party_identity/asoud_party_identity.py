try:
    from frappe.model.document import Document
except ModuleNotFoundError:  # pragma: no cover
    Document = object


class ASOUDPartyIdentity(Document):
    def validate(self) -> None:
        import frappe

        from asoud_core.services.party_management import (
            ROLE_DEFINITIONS,
            ascii_digits,
        )

        self.display_name = (self.display_name or "").strip()
        self.first_name = (self.first_name or "").strip()
        self.last_name = (self.last_name or "").strip()
        self.company_name = (self.company_name or "").strip()
        self.national_id = ascii_digits(self.national_id or "")
        if self.person_type == "Natural":
            if not self.first_name or not self.last_name:
                frappe.throw("First name and last name are required for a natural person")
            self.display_name = self.display_name or f"{self.first_name} {self.last_name}".strip()
        elif self.person_type == "Legal":
            if not self.company_name:
                frappe.throw("Legal entity name is required")
            self.display_name = self.display_name or self.company_name
        else:
            frappe.throw("Unsupported person type")
        if self.national_id:
            duplicate = frappe.db.exists(
                "ASOUD Party Identity",
                {"national_id": self.national_id, "name": ["!=", self.name or ""]},
            )
            if duplicate:
                frappe.throw("National ID is already registered")
        branch_company = (
            frappe.db.get_value("ASOUD Branch", self.branch, "company")
            if self.branch
            else self.company
        )
        if branch_company != self.company:
            frappe.throw("Default branch must belong to the primary company")
        seen_roles: set[tuple[str, str]] = set()
        for row in self.roles:
            if row.role not in ROLE_DEFINITIONS:
                frappe.throw(f"Unsupported party role: {row.role}")
            row.company = row.company or self.company
            key = (row.company, row.role)
            if key in seen_roles:
                frappe.throw("A role can only be assigned once per company")
            seen_roles.add(key)
            row.code_key = (
                f"{row.company}|{row.role}|{row.role_code}" if row.role_code else None
            )
        if not seen_roles:
            frappe.throw("At least one party role is required")
        for row in self.opening_balances:
            row.company = row.company or self.company
            if (row.company, row.role) not in seen_roles:
                frappe.throw("Opening balance role must be assigned to the person")
            if row.balance_state == "None":
                row.amount = 0
            elif float(row.amount or 0) <= 0:
                frappe.throw("Opening balance amount must be positive")
