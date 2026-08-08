from __future__ import annotations


def _company_mapping(detail, company: str):
    return next(
        (
            row
            for row in detail.company_codes
            if row.company == company and row.enabled
        ),
        None,
    )


def validate_journal_entry_details(doc, method: str | None = None) -> None:
    import frappe

    if not getattr(doc, "company", None):
        return
    account_names = {row.account for row in doc.accounts if row.account}
    if not account_names:
        return
    rule_rows = frappe.get_all(
        "ASOUD Account Detail Rule",
        filters={
            "company": doc.company,
            "account": ["in", sorted(account_names)],
            "enabled": 1,
        },
        fields=[
            "account",
            "detail_type",
            "required",
            "default_floating_detail",
            "valid_from",
            "valid_to",
        ],
    )
    posting_date = frappe.utils.getdate(doc.posting_date)
    rules: dict[str, list] = {}
    for rule in rule_rows:
        if rule.valid_from and posting_date < frappe.utils.getdate(rule.valid_from):
            continue
        if rule.valid_to and posting_date > frappe.utils.getdate(rule.valid_to):
            continue
        rules.setdefault(rule.account, []).append(rule)
    for row in doc.accounts:
        account_rules = rules.get(row.account, [])
        detail_name = row.get("asoud_floating_detail")
        if not detail_name:
            defaults = {
                rule.default_floating_detail
                for rule in account_rules
                if rule.default_floating_detail
            }
            if len(defaults) == 1:
                detail_name = defaults.pop()
                row.asoud_floating_detail = detail_name
        if (
            any(rule.required for rule in account_rules)
            and not detail_name
            and not doc.get("asoud_closing_run")
        ):
            frappe.throw(f"Floating detail is required for account {row.account}")
        if not detail_name:
            row.asoud_detail_code = None
            row.asoud_detail_type = None
            continue
        if not account_rules:
            frappe.throw(f"Floating detail is not configured for account {row.account}")
        detail = frappe.get_doc("ASOUD Floating Detail", detail_name)
        if not detail.enabled:
            frappe.throw(f"Floating detail is disabled: {detail_name}")
        mapping = _company_mapping(detail, doc.company)
        if not mapping:
            frappe.throw(f"Floating detail {detail_name} is not enabled for {doc.company}")
        allowed_types = {rule.detail_type for rule in account_rules}
        if detail.detail_type not in allowed_types:
            frappe.throw(
                f"Floating detail type {detail.detail_type} is not allowed for {row.account}"
            )
        row.asoud_detail_code = mapping.detail_code
        row.asoud_detail_type = detail.detail_type


def detail_ledger(
    *,
    company: str,
    from_date: str,
    to_date: str,
    floating_detail: str | None = None,
) -> list[dict]:
    import frappe

    filters: dict = {
        "company": company,
        "posting_date": ["between", [from_date, to_date]],
        "is_cancelled": 0,
    }
    if floating_detail:
        filters["asoud_floating_detail"] = floating_detail
    return frappe.get_all(
        "GL Entry",
        filters=filters,
        fields=[
            "posting_date",
            "voucher_type",
            "voucher_no",
            "account",
            "asoud_floating_detail",
            "asoud_detail_code",
            "asoud_detail_type",
            "debit",
            "credit",
        ],
        order_by="posting_date asc, creation asc",
    )


def trial_balance(company: str, from_date: str, to_date: str) -> list[dict]:
    import frappe

    return frappe.db.sql(
        """
        SELECT
            gle.account,
            acc.account_number,
            acc.account_name,
            acc.root_type,
            SUM(gle.debit) AS debit,
            SUM(gle.credit) AS credit,
            SUM(gle.debit - gle.credit) AS balance
        FROM `tabGL Entry` gle
        INNER JOIN `tabAccount` acc ON acc.name = gle.account
        WHERE gle.company = %(company)s
          AND gle.posting_date BETWEEN %(from_date)s AND %(to_date)s
          AND gle.is_cancelled = 0
        GROUP BY gle.account, acc.account_number, acc.account_name, acc.root_type
        ORDER BY acc.account_number, gle.account
        """,
        {"company": company, "from_date": from_date, "to_date": to_date},
        as_dict=True,
    )
