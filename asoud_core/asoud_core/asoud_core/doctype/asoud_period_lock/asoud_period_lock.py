from frappe.model.document import Document


class ASOUDPeriodLock(Document):
    def validate(self) -> None:
        import frappe

        if self.from_date > self.to_date:
            frappe.throw("From Date cannot be after To Date")
        fiscal_year = frappe.db.get_value(
            "Fiscal Year",
            self.fiscal_year,
            ["year_start_date", "year_end_date"],
            as_dict=True,
        )
        if not fiscal_year or not (
            fiscal_year.year_start_date
            <= self.from_date
            <= self.to_date
            <= fiscal_year.year_end_date
        ):
            frappe.throw("The lock range must be inside the selected fiscal year")
        overlap = frappe.db.exists(
            "ASOUD Period Lock",
            {
                "company": self.company,
                "docstatus": 1,
                "from_date": ["<=", self.to_date],
                "to_date": [">=", self.from_date],
                "name": ["!=", self.name or ""],
            },
        )
        if overlap:
            frappe.throw("A submitted lock already overlaps this period")
