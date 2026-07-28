from frappe.model.document import Document


class ASOUDEmployeeDocument(Document):
    def validate(self) -> None:
        from asoud_hr.services.organization import validate_employee_document

        validate_employee_document(self)

