try:
    from frappe.model.document import Document
except ModuleNotFoundError:  # pragma: no cover
    Document = object


class ASOUDAccountDetailRule(Document):
    def validate(self) -> None:
        import frappe

        account = frappe.db.get_value(
            "Account",
            self.account,
            ["company", "is_group"],
            as_dict=True,
        )
        if not account or account.company != self.company:
            frappe.throw("Account does not belong to the selected company")
        if account.is_group:
            frappe.throw("Floating detail rules can only target postable accounts")
        if self.detail_group:
            group = frappe.db.get_value(
                "ASOUD Floating Detail Group",
                self.detail_group,
                ["holding", "detail_type", "enabled"],
                as_dict=True,
            )
            company_holding = frappe.db.get_value(
                "Company",
                self.company,
                "asoud_holding",
            )
            if (
                not group
                or group.holding != company_holding
                or (self.enabled and not group.enabled)
            ):
                frappe.throw(
                    "Floating detail group is not active in the selected holding"
                )
            self.detail_type = group.detail_type
        if self.valid_from and self.valid_to and self.valid_to < self.valid_from:
            frappe.throw("Valid To cannot be before Valid From")
        if self.default_floating_detail:
            detail = frappe.db.get_value(
                "ASOUD Floating Detail",
                self.default_floating_detail,
                ["detail_type", "detail_group", "enabled"],
                as_dict=True,
            )
            if not detail or not detail.enabled:
                frappe.throw("Default floating detail is missing or disabled")
            if detail.detail_type != self.detail_type:
                frappe.throw("Default floating detail type does not match the rule")
            if self.detail_group and detail.detail_group != self.detail_group:
                frappe.throw("Default floating detail group does not match the rule")
            if not frappe.db.exists(
                "ASOUD Floating Detail Company",
                {
                    "parent": self.default_floating_detail,
                    "company": self.company,
                    "enabled": 1,
                },
            ):
                frappe.throw("Default floating detail is not enabled for this company")
        if self.required and self.enabled and frappe.db.exists(
            "ASOUD Account Detail Rule",
            {
                "company": self.company,
                "account": self.account,
                "required": 1,
                "enabled": 1,
                "name": ["!=", self.name or ""],
            },
        ):
            frappe.throw("Only one enabled detail type can be required per account")
        duplicate_filters = {
            "company": self.company,
            "account": self.account,
            "name": ["!=", self.name or ""],
        }
        if self.detail_group:
            duplicate_filters["detail_group"] = self.detail_group
        else:
            duplicate_filters["detail_type"] = self.detail_type
        duplicate = frappe.db.exists(
            "ASOUD Account Detail Rule",
            duplicate_filters,
        )
        if duplicate:
            frappe.throw("This account/detail-group rule already exists")
