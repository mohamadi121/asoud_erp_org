from frappe.model.document import Document


class ASOUDTaxSettings(Document):
    def validate(self) -> None:
        import frappe

        from asoud_iran.services.tax_gateway import (
            assert_production_credentials,
            validate_https_endpoint,
        )

        if self.environment == "Production":
            hosts = {value.strip() for value in (self.allowed_hosts or "").split(",") if value.strip()}
            try:
                self.base_url = validate_https_endpoint(self.base_url, hosts)
                assert_production_credentials(
                    environment=self.environment,
                    certificate_reference=self.certificate_reference,
                    secret_reference=self.secret_reference,
                )
            except ValueError as exc:
                frappe.throw(str(exc))
        if self.enabled and not frappe.db.get_value(
            "Company", self.company, "asoud_national_id"
        ):
            frappe.throw("Tax transmission requires the company national ID")
