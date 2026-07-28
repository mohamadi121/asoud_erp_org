from frappe.model.document import Document


class ASOUDClosingRun(Document):
    def validate(self) -> None:
        import frappe
        from frappe.utils import add_days, getdate

        closing_date = getdate(self.closing_date)
        opening_date = getdate(self.opening_date)
        if opening_date <= closing_date:
            frappe.throw("Opening Date must be after Closing Date")
        fiscal_year = frappe.db.get_value(
            "Fiscal Year",
            self.fiscal_year,
            ["year_start_date", "year_end_date"],
            as_dict=True,
        )
        if not fiscal_year:
            frappe.throw("The selected Fiscal Year does not exist")
        if closing_date != getdate(fiscal_year.year_end_date):
            frappe.throw("Closing Date must equal the Fiscal Year end date")
        if opening_date != add_days(fiscal_year.year_end_date, 1):
            frappe.throw("Opening Date must be the day after the Fiscal Year end date")
        accounts = {
            self.retained_earnings_account,
            self.closing_control_account,
            self.opening_control_account,
        }
        if len(accounts) != 3:
            frappe.throw(
                "Retained earnings, closing control and opening control accounts must differ"
            )
        for account in accounts:
            account_company = frappe.db.get_value("Account", account, "company")
            if account_company != self.company:
                frappe.throw(f"Account {account} does not belong to company {self.company}")
        duplicate = frappe.db.exists(
            "ASOUD Closing Run",
            {
                "company": self.company,
                "fiscal_year": self.fiscal_year,
                "docstatus": ["!=", 2],
                "name": ["!=", self.name or ""],
            },
        )
        if duplicate:
            frappe.throw("A closing run already exists for this company and fiscal year")
