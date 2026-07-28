from frappe.model.document import Document


class ASOUDApprovalPolicy(Document):
    def validate(self) -> None:
        from asoud_core.services.approval import validate_policy

        validate_policy(self)

