try:
    from frappe.model.document import Document
except ModuleNotFoundError:  # pragma: no cover
    Document = object


class ASOUDFloatingDetailGroup(Document):
    def validate(self) -> None:
        import frappe

        self.group_code = (self.group_code or "").strip()
        self.group_code = self.group_code.upper()
        self.group_title = (self.group_title or "").strip()
        if not self.group_code:
            frappe.throw("Floating detail group code is required")
        duplicate = frappe.db.exists(
            "ASOUD Floating Detail Group",
            {
                "holding": self.holding,
                "group_code": self.group_code,
                "name": ["!=", self.name or ""],
            },
        )
        if duplicate:
            frappe.throw("Floating detail group code already exists in this holding")
        if self.parent_group:
            if self.parent_group == self.name:
                frappe.throw("A floating detail group cannot be its own parent")
            parent = frappe.db.get_value(
                "ASOUD Floating Detail Group",
                self.parent_group,
                ["holding", "detail_type", "enabled"],
                as_dict=True,
            )
            if not parent or not parent.enabled:
                frappe.throw("Parent floating detail group is missing or disabled")
            if parent.holding != self.holding or parent.detail_type != self.detail_type:
                frappe.throw("Parent group must have the same holding and detail type")
            ancestor = self.parent_group
            visited = {self.name} if self.name else set()
            while ancestor:
                if ancestor in visited:
                    frappe.throw("Floating detail group hierarchy contains a cycle")
                visited.add(ancestor)
                ancestor = frappe.db.get_value(
                    "ASOUD Floating Detail Group",
                    ancestor,
                    "parent_group",
                )
