from frappe.model.document import Document


class ASOUDUserAccess(Document):
    def validate(self) -> None:
        import frappe

        if self.holding_manager:
            if self.branch:
                frappe.throw("A holding manager access grant cannot be limited to one branch")
            if not frappe.db.get_value("Company", self.company, "asoud_holding"):
                frappe.throw("The selected company must belong to a holding")
        if self.branch:
            branch_company = frappe.db.get_value("ASOUD Branch", self.branch, "company")
            if branch_company != self.company:
                frappe.throw("The selected branch does not belong to the selected company")
        duplicate = frappe.db.exists(
            "ASOUD User Access",
            {
                "user": self.user,
                "company": self.company,
                "branch": self.branch or "",
                "name": ["!=", self.name or ""],
            },
        )
        if duplicate:
            frappe.throw("This user access assignment already exists")

    def on_update(self) -> None:
        from asoud_core.services.user_permissions import sync_user_permissions

        sync_user_permissions(self.user)

    def after_delete(self) -> None:
        from asoud_core.services.user_permissions import sync_user_permissions

        sync_user_permissions(self.user)
