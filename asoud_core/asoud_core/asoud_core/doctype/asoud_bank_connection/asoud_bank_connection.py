from frappe.model.document import Document


class ASOUDBankConnection(Document):
    def validate(self) -> None:
        import frappe

        from asoud_core.services.banking import assert_bank_production_ready

        try:
            assert_bank_production_ready(
                environment=self.environment,
                secret_reference=self.secret_reference,
                provider_profile=self.provider_profile,
            )
        except ValueError as exc:
            frappe.throw(str(exc))
        treasury = frappe.db.get_value(
            "ASOUD Treasury Account",
            self.treasury_account,
            ["company", "branch", "treasury_type"],
            as_dict=True,
        )
        if (
            not treasury
            or treasury.company != self.company
            or treasury.branch != self.branch
            or treasury.treasury_type != "Bank"
        ):
            frappe.throw("Bank connection requires a matching Bank treasury account")
