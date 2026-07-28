from frappe.model.document import Document


class ASOUDOrganizationPosition(Document):
    def validate(self) -> None:
        from asoud_hr.services.organization import validate_position

        validate_position(self)

