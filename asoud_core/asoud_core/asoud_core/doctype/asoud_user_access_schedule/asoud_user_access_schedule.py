from frappe.model.document import Document


class ASOUDUserAccessSchedule(Document):
    def validate(self) -> None:
        import frappe

        if self.ends_on and self.starts_on and self.ends_on < self.starts_on:
            frappe.throw("Access schedule end date cannot precede its start date")
        if self.to_time and self.from_time and self.to_time <= self.from_time:
            frappe.throw("Access schedule end time must be after its start time")
        values = {part.strip() for part in (self.weekdays or "").split(",") if part.strip()}
        if values - {str(value) for value in range(7)}:
            frappe.throw("Weekdays must be comma-separated values from 0 (Monday) to 6 (Sunday)")

