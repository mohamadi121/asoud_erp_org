from frappe.model.document import Document


class ASOUDPilotRun(Document):
    def validate(self) -> None:
        import frappe

        if not self.scenarios:
            frappe.throw("Pilot run requires at least one UAT scenario")
        statuses = {row.status for row in self.scenarios}
        self.passed_scenarios = sum(row.status == "Pass" for row in self.scenarios)
        self.total_scenarios = len(self.scenarios)
        if self.docstatus == 0:
            self.status = "Passed" if statuses == {"Pass"} else "Failed"
        if self.data_profile == "Real":
            if not self.business_signoff or not self.accepted_by:
                frappe.throw(
                    "Real-data pilot requires attached business sign-off and accepter"
                )
            self.decision = "Go" if statuses == {"Pass"} else "No-Go"
        else:
            self.decision = "Technical Go Only" if statuses == {"Pass"} else "No-Go"

    def before_submit(self) -> None:
        import frappe

        if any(row.status != "Pass" for row in self.scenarios):
            frappe.throw("A pilot run can be submitted only when every scenario passes")
        if not self.completed_at:
            frappe.throw("Pilot completion timestamp is required")
