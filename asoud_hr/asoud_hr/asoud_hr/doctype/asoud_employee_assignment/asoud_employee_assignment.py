from frappe.model.document import Document


class ASOUDEmployeeAssignment(Document):
    def validate(self) -> None:
        from asoud_hr.services.organization import validate_assignment

        validate_assignment(self)

    def on_update(self) -> None:
        if self.active:
            from asoud_hr.services.organization import apply_active_assignment

            apply_active_assignment(self)

