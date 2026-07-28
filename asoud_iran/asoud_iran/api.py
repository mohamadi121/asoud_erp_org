from __future__ import annotations


def _whitelist(*args, **kwargs):
    import frappe

    return frappe.whitelist(*args, **kwargs)


@_whitelist(methods=["POST"])
def execute_closing(run_name: str) -> dict[str, str | None]:
    from asoud_iran.services.fiscal_closing import execute

    return execute(run_name)


@_whitelist(methods=["POST"])
def closing_preflight(run_name: str) -> dict:
    from asoud_iran.services.fiscal_closing import preflight

    return preflight(run_name)


@_whitelist(methods=["GET"])
def closing_runs(company: str) -> list[dict]:
    _assert_company_read(company)
    import frappe

    return frappe.get_all(
        "ASOUD Closing Run",
        filters={"company": company, "docstatus": ["!=", 2]},
        fields=[
            "name",
            "fiscal_year",
            "closing_date",
            "opening_date",
            "status",
            "preflight_status",
            "reconciliation_status",
            "attempt_count",
        ],
        order_by="closing_date desc",
        limit=10,
    )


@_whitelist(methods=["POST"])
def apply_iran_setup(
    company: str,
    template_name: str | None = None,
    amount_input_unit: str = "IRR",
    calendar_display: str = "Jalali",
) -> dict:
    from asoud_iran.services.iran_setup import apply_iran_setup as apply

    return apply(company, template_name, amount_input_unit, calendar_display)


@_whitelist(methods=["GET"])
def iran_setup_plan(company: str, template_name: str | None = None) -> dict:
    from asoud_iran.services.iran_setup import setup_plan

    _assert_company_read(company)
    return setup_plan(company, template_name)


@_whitelist(methods=["GET"])
def company_accounting_settings(company: str) -> dict:
    import frappe

    _assert_company_read(company)
    settings = frappe.db.get_value(
        "ASOUD Iran Company Settings",
        company,
        [
            "company",
            "coa_template",
            "base_currency",
            "amount_input_unit",
            "calendar_display",
            "timezone",
            "setup_version",
            "setup_status",
        ],
        as_dict=True,
    )
    if not settings:
        return {"company": company, "setup_status": "Pending"}
    preferences = frappe.db.get_value(
        "User",
        frappe.session.user,
        ["asoud_amount_display_unit", "asoud_calendar_display"],
        as_dict=True,
    )
    if preferences:
        if preferences.asoud_amount_display_unit not in {
            None,
            "",
            "Use Company Default",
        }:
            settings.amount_input_unit = preferences.asoud_amount_display_unit
        if preferences.asoud_calendar_display not in {
            None,
            "",
            "Use Company Default",
        }:
            settings.calendar_display = preferences.asoud_calendar_display
    return settings


@_whitelist(methods=["GET"])
def company_chart_of_accounts(company: str) -> list[dict]:
    import frappe

    _assert_company_read(company)
    template_name = frappe.db.get_value(
        "ASOUD Iran Company Settings",
        company,
        "coa_template",
    )
    if not template_name:
        return []
    codes = frappe.get_all(
        "ASOUD COA Template Account",
        filters={
            "parent": template_name,
            "parenttype": "ASOUD COA Template",
        },
        pluck="account_code",
        order_by="idx asc",
    )
    if not codes:
        return []
    return frappe.get_all(
        "Account",
        filters={"company": company, "account_number": ["in", codes]},
        fields=[
            "name",
            "account_number",
            "account_name",
            "parent_account",
            "root_type",
            "account_type",
            "is_group",
        ],
        order_by="account_number asc",
    )


@_whitelist(methods=["GET"])
def convert_amount(value: str, input_unit: str, output_unit: str = "IRR") -> dict[str, str]:
    import frappe

    from asoud_iran.accounting.currency import normalize_api_amount

    try:
        return normalize_api_amount(value, input_unit, output_unit)
    except ValueError as exc:
        frappe.throw(str(exc))


@_whitelist(methods=["GET"])
def to_jalali(gregorian_date: str) -> dict[str, str]:
    import frappe

    from asoud_iran.accounting.jalali import format_jalali

    try:
        return {"gregorian": gregorian_date, "jalali": format_jalali(gregorian_date)}
    except ValueError as exc:
        frappe.throw(str(exc))


@_whitelist(methods=["GET"])
def from_jalali(jalali_date: str) -> dict[str, str]:
    import frappe

    from asoud_iran.accounting.jalali import format_jalali, parse_jalali

    try:
        gregorian = parse_jalali(jalali_date).isoformat()
    except ValueError as exc:
        frappe.throw(str(exc))
    return {"jalali": format_jalali(gregorian), "gregorian": gregorian}


def _assert_company_read(company: str) -> None:
    import frappe

    if not frappe.get_doc("Company", company).has_permission("read"):
        frappe.throw("Not permitted", frappe.PermissionError)


@_whitelist(methods=["GET"])
def accounting_trial_balance(company: str, from_date: str, to_date: str) -> list[dict]:
    from asoud_iran.services.floating_detail import trial_balance

    _assert_company_read(company)
    return trial_balance(company, from_date, to_date)


@_whitelist(methods=["GET"])
def floating_detail_ledger(
    company: str,
    from_date: str,
    to_date: str,
    floating_detail: str | None = None,
) -> list[dict]:
    from asoud_iran.services.floating_detail import detail_ledger

    _assert_company_read(company)
    return detail_ledger(
        company=company,
        from_date=from_date,
        to_date=to_date,
        floating_detail=floating_detail,
    )


@_whitelist(methods=["GET"])
def standard_accounting_report(
    company: str,
    report_type: str,
    from_date: str,
    to_date: str,
    branch: str | None = None,
    account: str | None = None,
    floating_detail: str | None = None,
) -> dict:
    from asoud_iran.services.standard_reports import build_standard_report

    return build_standard_report(
        company=company,
        report_type=report_type,
        from_date=from_date,
        to_date=to_date,
        branch=branch,
        account=account,
        floating_detail=floating_detail,
    )


@_whitelist(methods=["GET"])
def export_accounting_report(
    company: str,
    report_type: str,
    from_date: str,
    to_date: str,
    file_format: str,
    branch: str | None = None,
    account: str | None = None,
    floating_detail: str | None = None,
):
    import frappe

    from asoud_iran.services.standard_reports import (
        build_standard_report,
        render_export,
    )

    report = build_standard_report(
        company=company,
        report_type=report_type,
        from_date=from_date,
        to_date=to_date,
        branch=branch,
        account=account,
        floating_detail=floating_detail,
    )
    try:
        content, filename, content_type = render_export(report, file_format)
    except ValueError as exc:
        frappe.throw(str(exc))
    frappe.local.response.filename = filename
    frappe.local.response.filecontent = content
    frappe.local.response.type = "download"
    frappe.local.response.content_type = content_type


@_whitelist(methods=["POST"])
def queue_tax_invoice(
    invoice: str,
    invoice_kind: str = "Original",
    reference_tax_uid: str | None = None,
) -> dict[str, str]:
    import frappe

    frappe.only_for(("Accounts Manager", "System Manager"))
    from asoud_iran.services.tax_submission import queue_sales_invoice

    return queue_sales_invoice(invoice, invoice_kind, reference_tax_uid)


@_whitelist(methods=["POST"])
def dispatch_tax_submission(submission: str) -> dict[str, str]:
    import frappe

    frappe.only_for(("Accounts Manager", "System Manager"))
    from asoud_iran.services.tax_submission import dispatch

    return dispatch(submission)


@_whitelist(methods=["GET"])
def tax_submission_status(submission: str) -> dict:
    import frappe

    doc = frappe.get_doc("ASOUD Tax Submission", submission)
    if not doc.has_permission("read"):
        frappe.throw("Not permitted", frappe.PermissionError)
    return {
        "name": doc.name,
        "source_name": doc.source_name,
        "invoice_kind": doc.invoice_kind,
        "status": doc.status,
        "provider_reference": doc.provider_reference,
        "attempt_count": doc.attempt_count,
        "payload_checksum": doc.payload_checksum,
        "response_checksum": doc.response_checksum,
        "events": frappe.get_all(
            "ASOUD Tax Event",
            filters={"submission": doc.name},
            fields=["event_at", "from_status", "to_status", "provider_reference"],
            order_by="event_at asc",
        ),
    }
