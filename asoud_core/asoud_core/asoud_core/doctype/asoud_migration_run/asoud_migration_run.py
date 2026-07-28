from frappe.model.document import Document


class ASOUDMigrationRun(Document):
    def validate(self) -> None:
        import frappe

        if not self.controls:
            frappe.throw("Migration run requires reconciliation controls")
        if len(self.source_checksum or "") != 64:
            frappe.throw("Source checksum must be SHA-256")
        all_pass = True
        for row in self.controls:
            row.difference = float(row.target_value or 0) - float(row.source_value or 0)
            row.status = (
                "Pass"
                if abs(row.difference) <= abs(float(row.tolerance or 0))
                else "Fail"
            )
            all_pass = all_pass and row.status == "Pass"
        self.status = "Reconciled" if all_pass else "Failed"
        if not all_pass:
            self.decision = "Rejected"
        elif self.data_profile == "Real":
            if not self.reconciled_by or not self.reconciliation_evidence:
                frappe.throw(
                    "Real migration requires a reconciler and signed reconciliation evidence"
                )
            self.decision = "Accepted"
        else:
            self.decision = "Technical Ready"

    def before_submit(self) -> None:
        import frappe

        if self.status != "Reconciled":
            frappe.throw("Only a fully reconciled migration can be submitted")
        if not self.completed_at:
            frappe.throw("Migration completion timestamp is required")
