from frappe.model.document import Document


class ASOUDApprovalDelegation(Document):
    def validate(self) -> None:
        import frappe

        if self.principal_user == self.delegate_user:
            frappe.throw("Principal and delegate must be different users")
        if self.ends_on <= self.starts_on:
            frappe.throw("Delegation end must be after its start")
        if self.branch:
            branch_company = frappe.db.get_value("ASOUD Branch", self.branch, "company")
            if not branch_company or branch_company != self.company:
                frappe.throw("Delegation branch must belong to its company")

