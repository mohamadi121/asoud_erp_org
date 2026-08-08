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
        if not (self.lock_reason or "").strip():
            frappe.throw("Lock reason is required")
        if self.fiscal_period:
            period = frappe.db.get_value(
                "ASOUD Fiscal Period",
                self.fiscal_period,
                ["company", "fiscal_year", "from_date", "to_date", "enabled"],
                as_dict=True,
            )
            if (
                not period
                or not period.enabled
                or period.company != self.company
                or period.fiscal_year != self.fiscal_year
                or period.from_date != self.from_date
                or period.to_date != self.to_date
            ):
                frappe.throw("Fiscal period does not match the lock range")
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
