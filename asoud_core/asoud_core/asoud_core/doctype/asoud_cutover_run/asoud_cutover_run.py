from frappe.model.document import Document


class ASOUDCutoverRun(Document):
    def validate(self) -> None:
        import frappe

        if not self.checks:
            frappe.throw("Cutover run requires a checklist")
        mandatory_pass = all(
            row.status == "Pass" for row in self.checks if row.mandatory
        )
        migration = frappe.get_doc("ASOUD Migration Run", self.migration_run)
        pilot = frappe.get_doc("ASOUD Pilot Run", self.pilot_run)
        if migration.company != self.company:
            frappe.throw("Migration run belongs to another company")
        technically_ready = (
            mandatory_pass
            and migration.docstatus == 1
            and migration.status == "Reconciled"
            and pilot.docstatus == 1
            and pilot.status == "Passed"
        )
        self.status = "Ready" if technically_ready else "Blocked"
        if not technically_ready:
            self.decision = "No-Go"
        elif migration.data_profile == "Real" and pilot.data_profile == "Real":
            if not self.approved_by or not self.business_signoff:
                frappe.throw(
                    "Production Go requires business approver and signed acceptance"
                )
            if pilot.decision != "Go" or migration.decision != "Accepted":
                frappe.throw("Real migration and pilot must be accepted")
            self.decision = "Production Go"
        else:
            self.decision = "Technical Ready"

    def before_submit(self) -> None:
        import frappe

        if self.status != "Ready":
            frappe.throw("A blocked cutover cannot be submitted")
