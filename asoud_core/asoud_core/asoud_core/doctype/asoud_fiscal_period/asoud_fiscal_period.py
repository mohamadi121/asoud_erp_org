try:
    from frappe.model.document import Document
except ModuleNotFoundError:  # pragma: no cover
    Document = object


class ASOUDFiscalPeriod(Document):
    def validate(self) -> None:
        import frappe

        self.period_name = (self.period_name or "").strip()
        if not self.period_name:
            frappe.throw("Fiscal period name is required")
        if self.from_date > self.to_date:
            frappe.throw("Fiscal period start date cannot be after end date")
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
            frappe.throw("Fiscal period must be inside the selected fiscal year")
        assigned = frappe.db.exists(
            "Fiscal Year Company",
            {"parent": self.fiscal_year, "company": self.company},
        )
        has_assignments = frappe.db.exists(
            "Fiscal Year Company",
            {"parent": self.fiscal_year},
        )
        if has_assignments and not assigned:
            frappe.throw("Fiscal year is not assigned to the selected company")
        duplicate = frappe.db.exists(
            "ASOUD Fiscal Period",
            {
                "company": self.company,
                "fiscal_year": self.fiscal_year,
                "period_name": self.period_name,
                "name": ["!=", self.name or ""],
            },
        )
        if duplicate:
            frappe.throw("Fiscal period name already exists in this company")
        overlap = frappe.db.exists(
            "ASOUD Fiscal Period",
            {
                "company": self.company,
                "fiscal_year": self.fiscal_year,
                "period_type": self.period_type,
                "enabled": 1,
                "from_date": ["<=", self.to_date],
                "to_date": [">=", self.from_date],
                "name": ["!=", self.name or ""],
            },
        )
        if overlap:
            frappe.throw("An active fiscal period already overlaps this range")
