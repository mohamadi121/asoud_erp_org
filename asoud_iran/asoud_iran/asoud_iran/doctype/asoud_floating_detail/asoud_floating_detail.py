try:
    from frappe.model.document import Document
except ModuleNotFoundError:  # pragma: no cover
    Document = object


class ASOUDFloatingDetail(Document):
    def validate(self) -> None:
        import frappe

        reference_by_type = {
            "Customer": "Customer",
            "Supplier": "Supplier",
            "Employee": "Employee",
            "Project": "Project",
            "Cost Center": "Cost Center",
            "Branch": "ASOUD Branch",
        }
        expected = reference_by_type.get(self.detail_type)
        if expected and self.reference_doctype and self.reference_doctype != expected:
            frappe.throw(f"{self.detail_type} detail must reference {expected}")
        seen_companies: set[str] = set()
        seen_codes: set[tuple[str, str]] = set()
        for row in self.company_codes:
            if row.company in seen_companies:
                frappe.throw(f"Company appears more than once: {row.company}")
            key = (row.company, (row.detail_code or "").strip())
            if not key[1]:
                frappe.throw("Floating detail company code is required")
            if key in seen_codes:
                frappe.throw(f"Duplicate company detail code: {key[1]}")
            duplicate = frappe.db.exists(
                "ASOUD Floating Detail Company",
                {
                    "company": row.company,
                    "detail_code": key[1],
                    "parent": ["!=", self.name or ""],
                    "parenttype": "ASOUD Floating Detail",
                },
            )
            if duplicate:
                frappe.throw(
                    f"Floating detail code {key[1]} already exists in {row.company}"
                )
            company_holding = frappe.db.get_value("Company", row.company, "asoud_holding")
            if company_holding != self.holding:
                frappe.throw(f"Company {row.company} does not belong to holding {self.holding}")
            row.detail_code = key[1]
            seen_companies.add(row.company)
            seen_codes.add(key)
