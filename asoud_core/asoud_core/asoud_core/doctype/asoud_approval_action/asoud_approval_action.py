from frappe.model.document import Document


class ASOUDApprovalAction(Document):
    def before_save(self) -> None:
        from asoud_core.services.approval import prevent_action_mutation

        prevent_action_mutation(self)

    def on_trash(self) -> None:
        import frappe

        frappe.throw("Approval actions are immutable")

