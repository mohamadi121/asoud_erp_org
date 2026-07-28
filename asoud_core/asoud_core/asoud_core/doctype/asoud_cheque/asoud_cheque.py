from frappe.model.document import Document


class ASOUDCheque(Document):
    def autoname(self) -> None:
        self.cheque_key = self._key()
        self.name = self.cheque_key

    def validate(self) -> None:
        from asoud_core.services.treasury import validate_cheque
        from asoud_core.services.banking import validate_sayad_id

        self.cheque_key = self._key()
        if self.sayad_id:
            try:
                self.sayad_id = validate_sayad_id(self.sayad_id)
            except ValueError as exc:
                import frappe

                frappe.throw(str(exc))
        validate_cheque(self)

    def _key(self) -> str:
        return f"{self.company}|{self.cheque_type}|{self.bank_name}|{self.cheque_number}" if self.company and self.cheque_type and self.bank_name and self.cheque_number else ""
