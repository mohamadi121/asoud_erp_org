from __future__ import annotations

import json
from typing import Any


ROLE_DEFINITIONS = {
    "Customer": {"start": 10000, "doctype": "Customer"},
    "Supplier": {"start": 15000, "doctype": "Supplier"},
    "Employee": {"start": 6000, "doctype": "Employee"},
    "Salesperson": {"start": 20000, "doctype": None},
    "Marketer": {"start": 25000, "doctype": None},
    "Cash Custodian": {"start": 30000, "doctype": None},
}

PERSIAN_DIGITS = str.maketrans("۰۱۲۳۴۵۶۷۸۹٠١٢٣٤٥٦٧٨٩", "01234567890123456789")


def ascii_digits(value: str) -> str:
    return str(value or "").translate(PERSIAN_DIGITS).strip()


def _boolean(value: Any, default: bool = False) -> bool:
    if value is None:
        return default
    if isinstance(value, str):
        return value.strip().lower() not in {"", "0", "false", "no", "off"}
    return bool(value)


def normalize_party_payload(payload: str | dict[str, Any]) -> dict[str, Any]:
    values = json.loads(payload) if isinstance(payload, str) else dict(payload)
    person_type = str(values.get("person_type") or "Natural").strip()
    if person_type not in {"Natural", "Legal"}:
        raise ValueError("Unsupported person type")
    first_name = str(values.get("first_name") or "").strip()
    last_name = str(values.get("last_name") or "").strip()
    company_name = str(values.get("company_name") or "").strip()
    if person_type == "Natural" and (not first_name or not last_name):
        raise ValueError("First name and last name are required")
    if person_type == "Legal" and not company_name:
        raise ValueError("Legal entity name is required")
    display_name = str(values.get("display_name") or "").strip()
    display_name = display_name or (
        f"{first_name} {last_name}".strip() if person_type == "Natural" else company_name
    )
    raw_roles = values.get("roles") or []
    roles: list[str] = []
    for item in raw_roles:
        role = str(item.get("role") if isinstance(item, dict) else item).strip()
        if role not in ROLE_DEFINITIONS:
            raise ValueError(f"Unsupported party role: {role}")
        if role not in roles:
            roles.append(role)
    if not roles:
        raise ValueError("At least one role is required")
    opening_balances: list[dict[str, Any]] = []
    for item in values.get("opening_balances") or []:
        row = dict(item)
        role = str(row.get("role") or "").strip()
        if role not in roles:
            raise ValueError("Opening balance role must be selected")
        state = str(row.get("balance_state") or "None").strip()
        if state not in {"None", "Debit", "Credit"}:
            raise ValueError("Unsupported opening balance state")
        amount = float(row.get("amount") or 0)
        if state != "None" and amount <= 0:
            raise ValueError("Opening balance amount must be positive")
        opening_balances.append(
            {
                "role": role,
                "balance_state": state,
                "amount": 0 if state == "None" else amount,
                "currency": str(row.get("currency") or "").strip() or None,
                "account": str(row.get("account") or "").strip() or None,
                "offset_account": str(row.get("offset_account") or "").strip() or None,
                "opening_date": str(row.get("opening_date") or "").strip() or None,
            }
        )
    policies: dict[str, dict[str, Any]] = {}
    for item in values.get("company_policies") or []:
        row = dict(item)
        role = str(row.get("role") or "").strip()
        if role not in {"Customer", "Supplier"} or role not in roles:
            raise ValueError("Company policy requires a selected customer or supplier role")
        credit_limit = float(row.get("credit_limit") or 0)
        if credit_limit < 0:
            raise ValueError("Credit limit cannot be negative")
        policies[role] = {
            "role": role,
            "enabled": _boolean(row.get("enabled"), True),
            "default_branch": str(row.get("default_branch") or "").strip() or None,
            "credit_limit": credit_limit if role == "Customer" else 0,
            "payment_terms_template": str(
                row.get("payment_terms_template") or ""
            ).strip()
            or None,
            "price_list": str(row.get("price_list") or "").strip() or None,
            "default_account": str(row.get("default_account") or "").strip()
            or None,
        }
    return {
        "name": str(values.get("name") or "").strip() or None,
        "person_type": person_type,
        "display_name": display_name,
        "first_name": first_name,
        "last_name": last_name,
        "father_name": str(values.get("father_name") or "").strip(),
        "birth_certificate_number": ascii_digits(
            values.get("birth_certificate_number") or ""
        ),
        "birth_place": str(values.get("birth_place") or "").strip(),
        "company_name": company_name,
        "gender": str(values.get("gender") or "").strip() or None,
        "birth_date": str(values.get("birth_date") or "").strip() or None,
        "national_id": ascii_digits(values.get("national_id") or ""),
        "registration_number": ascii_digits(values.get("registration_number") or ""),
        "economic_code": ascii_digits(values.get("economic_code") or ""),
        "phone": ascii_digits(values.get("phone") or ""),
        "mobile": ascii_digits(values.get("mobile") or ""),
        "email": str(values.get("email") or "").strip(),
        "website": str(values.get("website") or "").strip(),
        "province": str(values.get("province") or "").strip(),
        "city": str(values.get("city") or "").strip(),
        "address_line": str(values.get("address_line") or "").strip(),
        "postal_code": ascii_digits(values.get("postal_code") or ""),
        "latitude": values.get("latitude"),
        "longitude": values.get("longitude"),
        "description": str(values.get("description") or "").strip(),
        "enabled": _boolean(values.get("enabled"), True),
        "roles": roles,
        "opening_balances": opening_balances,
        "company_policies": policies,
    }


def _assert_manage(company: str, branch: str | None = None) -> None:
    import frappe

    allowed = {
        "System Manager",
        "Accounts Manager",
        "Sales Manager",
        "Purchase Manager",
        "ASOUD HR Manager",
    }
    if not allowed.intersection(frappe.get_roles(frappe.session.user)):
        frappe.throw("Not permitted", frappe.PermissionError)
    from asoud_core.permissions import can_access_context

    if not can_access_context(frappe.session.user, company, branch or None):
        frappe.throw("Not permitted", frappe.PermissionError)


def _series_key(company: str, role: str) -> str:
    return f"{company}|{role}"


def _ensure_series(company: str, role: str) -> str:
    import frappe

    key = _series_key(company, role)
    if not frappe.db.exists("ASOUD Party Code Series", key):
        start = ROLE_DEFINITIONS[role]["start"]
        try:
            frappe.get_doc(
                {
                    "doctype": "ASOUD Party Code Series",
                    "series_key": key,
                    "company": company,
                    "role": role,
                    "start_number": start,
                    "current_number": start,
                    "enabled": 1,
                }
            ).insert(ignore_permissions=True)
        except frappe.DuplicateEntryError:
            pass
    return key


def _allocate_code(company: str, role: str) -> str:
    import frappe

    key = _ensure_series(company, role)
    frappe.db.sql(
        "select name from `tabASOUD Party Code Series` where name=%s for update",
        key,
    )
    row = frappe.db.get_value(
        "ASOUD Party Code Series",
        key,
        ["current_number", "start_number", "enabled"],
        as_dict=True,
    )
    if not row or not row.enabled:
        frappe.throw("Party code series is disabled")
    next_number = max(int(row.current_number or 0), int(row.start_number or 0)) + 1
    frappe.db.set_value(
        "ASOUD Party Code Series",
        key,
        "current_number",
        next_number,
        update_modified=False,
    )
    return str(next_number)


def preview_codes(company: str, roles: str | list[str]) -> dict[str, str]:
    import frappe

    from asoud_core.permissions import can_access_company

    if not can_access_company(frappe.session.user, company):
        frappe.throw("Not permitted", frappe.PermissionError)
    selected = json.loads(roles) if isinstance(roles, str) else list(roles)
    result: dict[str, str] = {}
    for role in selected:
        if role not in ROLE_DEFINITIONS:
            frappe.throw(f"Unsupported party role: {role}")
        key = _series_key(company, role)
        current = frappe.db.get_value(
            "ASOUD Party Code Series", key, "current_number"
        )
        start = ROLE_DEFINITIONS[role]["start"]
        result[role] = str(max(int(current or 0), start) + 1)
    return result


def _default_master(doctype: str, setting_doctype: str, setting_field: str) -> str:
    import frappe

    value = frappe.db.get_single_value(setting_doctype, setting_field)
    if value:
        return value
    rows = frappe.get_all(
        doctype,
        filters={"is_group": 0},
        pluck="name",
        limit=1,
    )
    if not rows:
        frappe.throw(f"Configure at least one {doctype} before creating a party")
    return rows[0]


def _sync_customer(identity, role_row) -> str:
    import frappe

    if role_row.reference_name and frappe.db.exists(
        "Customer", role_row.reference_name
    ):
        doc = frappe.get_doc("Customer", role_row.reference_name)
    elif frappe.db.exists("Customer", {"asoud_party_identity": identity.name}):
        doc = frappe.get_doc(
            "Customer",
            frappe.db.get_value(
                "Customer", {"asoud_party_identity": identity.name}, "name"
            ),
        )
    else:
        doc = frappe.new_doc("Customer")
        doc.customer_group = _default_master(
            "Customer Group", "Selling Settings", "customer_group"
        )
        doc.territory = _default_master(
            "Territory", "Selling Settings", "territory"
        )
    doc.customer_name = identity.display_name
    doc.customer_type = "Individual" if identity.person_type == "Natural" else "Company"
    doc.asoud_holding = identity.holding
    doc.asoud_party_identity = identity.name
    if not doc.asoud_role_code:
        doc.asoud_role_code = role_row.role_code
    # Customer is shared by the holding. Company-level availability belongs to
    # ASOUD Party Company Profile and must never disable it for other companies.
    doc.disabled = 0 if identity.enabled else 1
    doc.save(ignore_permissions=True)
    return doc.name


def _sync_supplier(identity, role_row) -> str:
    import frappe

    if role_row.reference_name and frappe.db.exists(
        "Supplier", role_row.reference_name
    ):
        doc = frappe.get_doc("Supplier", role_row.reference_name)
    elif frappe.db.exists("Supplier", {"asoud_party_identity": identity.name}):
        doc = frappe.get_doc(
            "Supplier",
            frappe.db.get_value(
                "Supplier", {"asoud_party_identity": identity.name}, "name"
            ),
        )
    else:
        doc = frappe.new_doc("Supplier")
        doc.supplier_group = _default_master(
            "Supplier Group", "Buying Settings", "supplier_group"
        )
    doc.supplier_name = identity.display_name
    doc.supplier_type = "Individual" if identity.person_type == "Natural" else "Company"
    doc.asoud_holding = identity.holding
    doc.asoud_party_identity = identity.name
    if not doc.asoud_role_code:
        doc.asoud_role_code = role_row.role_code
    doc.disabled = 0 if identity.enabled else 1
    doc.save(ignore_permissions=True)
    return doc.name


def _sync_employee(identity, role_row) -> str:
    import frappe
    from frappe.utils import nowdate

    if identity.person_type != "Natural":
        frappe.throw("Employee role can only be assigned to a natural person")
    if not identity.gender or not identity.birth_date:
        frappe.throw("Gender and birth date are required for an employee")
    if role_row.reference_name and frappe.db.exists(
        "Employee", role_row.reference_name
    ):
        doc = frappe.get_doc("Employee", role_row.reference_name)
    else:
        doc = frappe.new_doc("Employee")
        doc.status = "Active"
        doc.date_of_joining = nowdate()
    doc.first_name = identity.first_name
    doc.last_name = identity.last_name
    doc.employee_name = identity.display_name
    doc.company = role_row.company
    doc.gender = identity.gender
    doc.date_of_birth = identity.birth_date
    doc.asoud_branch = identity.branch
    doc.asoud_national_id = identity.national_id
    doc.asoud_party_identity = identity.name
    doc.asoud_role_code = role_row.role_code
    doc.asoud_father_name = identity.father_name
    doc.asoud_birth_certificate_number = identity.birth_certificate_number
    doc.asoud_birth_place = identity.birth_place
    doc.cell_number = identity.mobile
    doc.personal_email = identity.email
    doc.save(ignore_permissions=True)
    return doc.name


def _sync_company_profile(identity, role_row, policy: dict[str, Any] | None = None) -> None:
    import frappe

    if role_row.role not in {"Customer", "Supplier"}:
        return
    key = f"{role_row.role}|{role_row.reference_name}|{role_row.company}"
    if frappe.db.exists("ASOUD Party Company Profile", key):
        profile = frappe.get_doc("ASOUD Party Company Profile", key)
    else:
        profile = frappe.new_doc("ASOUD Party Company Profile")
        profile.profile_key = key
    profile.party_type = role_row.role
    profile.party = role_row.reference_name
    profile.company = role_row.company
    policy = policy or {}
    profile.default_branch = policy.get("default_branch") or (
        identity.branch if identity.company == role_row.company else None
    )
    profile.enabled = int(policy.get("enabled", role_row.enabled))
    profile.credit_limit = policy.get("credit_limit", profile.credit_limit or 0)
    profile.payment_terms_template = policy.get(
        "payment_terms_template", profile.payment_terms_template
    )
    profile.price_list = policy.get("price_list", profile.price_list)
    profile.default_account = policy.get("default_account", profile.default_account)
    profile.save(ignore_permissions=True)


def _sync_role_masters(
    identity, company: str, policies: dict[str, dict[str, Any]]
) -> None:
    syncers = {
        "Customer": ("Customer", _sync_customer),
        "Supplier": ("Supplier", _sync_supplier),
        "Employee": ("Employee", _sync_employee),
    }
    for row in identity.roles:
        if row.company != company:
            continue
        target = syncers.get(row.role)
        if target:
            row.reference_doctype = target[0]
            row.reference_name = target[1](identity, row)
            _sync_company_profile(identity, row, policies.get(row.role))


def _role_values(row: Any) -> dict[str, Any]:
    """Return only business fields accepted by the child table."""
    getter = row.get if isinstance(row, dict) else lambda key: getattr(row, key, None)
    return {
        "company": getter("company"),
        "role": getter("role"),
        "role_code": getter("role_code"),
        "code_key": getter("code_key"),
        "reference_doctype": getter("reference_doctype"),
        "reference_name": getter("reference_name"),
        "enabled": getter("enabled"),
    }


def _opening_values(row: Any) -> dict[str, Any]:
    getter = row.get if isinstance(row, dict) else lambda key: getattr(row, key, None)
    return {
        "company": getter("company"),
        "role": getter("role"),
        "balance_state": getter("balance_state"),
        "amount": getter("amount"),
        "currency": getter("currency"),
        "account": getter("account"),
        "offset_account": getter("offset_account"),
        "opening_date": getter("opening_date"),
        "status": getter("status"),
        "journal_entry": getter("journal_entry"),
    }


def save_party(
    company: str,
    payload: str | dict[str, Any],
    branch: str | None = None,
) -> dict:
    import frappe

    branch = branch or None
    _assert_manage(company, branch)
    try:
        values = normalize_party_payload(payload)
    except (TypeError, ValueError, json.JSONDecodeError) as exc:
        frappe.throw(str(exc))
    if "Employee" in values["roles"] and (
        values["person_type"] != "Natural"
        or not values["gender"]
        or not values["birth_date"]
    ):
        frappe.throw("A personnel record requires a natural person, gender and birth date")
    is_new = not values["name"]
    if not is_new:
        identity = frappe.get_doc("ASOUD Party Identity", values["name"])
        target_holding = frappe.db.get_value("Company", company, "asoud_holding")
        if identity.holding != target_holding:
            frappe.throw("Party does not belong to the selected holding")
        before = identity.as_dict()
        existing = {
            (row.company, row.role): row.as_dict() for row in identity.roles
        }
    else:
        identity = frappe.new_doc("ASOUD Party Identity")
        before = None
        existing = {}
    identity.update(
        {
            key: value
            for key, value in values.items()
            if key not in {"name", "roles", "opening_balances", "company_policies"}
        }
    )
    if is_new:
        identity.company = company
        identity.branch = branch
        identity.holding = frappe.db.get_value("Company", company, "asoud_holding")
    identity.set("roles", [])
    for (row_company, _), previous in existing.items():
        if row_company != company:
            identity.append("roles", _role_values(previous))
    for role in values["roles"]:
        previous = existing.get((company, role), {})
        code = previous.get("role_code") or _allocate_code(company, role)
        identity.append(
            "roles",
            {
                "company": company,
                "role": role,
                "role_code": code,
                "code_key": f"{company}|{role}|{code}",
                "reference_doctype": previous.get("reference_doctype"),
                "reference_name": previous.get("reference_name"),
                "enabled": 1,
            },
        )
    identity.set("opening_balances", [])
    if not is_new:
        for previous in before.get("opening_balances") or []:
            if previous.get("company") != company:
                identity.append("opening_balances", _opening_values(previous))
    for row in values["opening_balances"]:
        identity.append(
            "opening_balances",
            {
                "company": company,
                **row,
                "status": "Draft",
            },
        )
    identity.save(ignore_permissions=True)
    _sync_role_masters(identity, company, values["company_policies"])
    identity.save(ignore_permissions=True)
    from asoud_core.services.audit import append_event

    append_event(
        "party.saved",
        resource_doctype=identity.doctype,
        resource_name=identity.name,
        company=company,
        branch=branch,
        before=before,
        after=identity.as_dict(),
    )
    return party_detail(identity.name, company)


def party_snapshot(
    company: str,
    branch: str | None = None,
    search: str | None = None,
) -> dict:
    import frappe

    branch = branch or None
    from asoud_core.permissions import can_access_context

    if not can_access_context(frappe.session.user, company, branch):
        frappe.throw("Not permitted", frappe.PermissionError)
    parent_names = frappe.get_all(
        "ASOUD Party Role",
        filters={"company": company, "enabled": 1},
        pluck="parent",
    )
    if not parent_names:
        return {
            "company": company,
            "branch": branch,
            "items": [],
            "series": preview_codes(company, list(ROLE_DEFINITIONS)),
            "policy_options": _party_policy_options(company),
            "opening_balance_mode": "Draft until posted through opening balance workflow",
        }
    filters: dict[str, Any] = {"name": ["in", list(set(parent_names))]}
    or_filters = (
        {
            "display_name": ["like", f"%{search.strip()}%"],
            "national_id": ["like", f"%{ascii_digits(search)}%"],
            "mobile": ["like", f"%{ascii_digits(search)}%"],
        }
        if search and search.strip()
        else None
    )
    identities = frappe.get_list(
        "ASOUD Party Identity",
        filters=filters,
        or_filters=or_filters,
        fields=[
            "name",
            "display_name",
            "person_type",
            "national_id",
            "mobile",
            "email",
            "enabled",
            "modified",
        ],
        order_by="modified desc",
        page_length=100,
    )
    names = [row.name for row in identities]
    roles = (
        frappe.get_all(
            "ASOUD Party Role",
            filters={"parent": ["in", names], "company": company},
            fields=[
                "parent",
                "role",
                "role_code",
                "reference_doctype",
                "reference_name",
                "enabled",
            ],
            order_by="idx",
        )
        if names
        else []
    )
    by_identity: dict[str, list[dict]] = {name: [] for name in names}
    for row in roles:
        by_identity[row.parent].append(row)
    return {
        "company": company,
        "branch": branch,
        "items": [
            {**row, "roles": by_identity.get(row.name, [])} for row in identities
        ],
        "series": preview_codes(company, list(ROLE_DEFINITIONS)),
        "policy_options": _party_policy_options(company),
        "opening_balance_mode": "Draft until posted through opening balance workflow",
    }


def _party_policy_options(company: str) -> dict[str, list[str]]:
    import frappe

    return {
        "branches": frappe.get_all(
            "ASOUD Branch",
            filters={"company": company, "enabled": 1},
            pluck="name",
            order_by="branch_name",
        ),
        "payment_terms": frappe.get_all(
            "Payment Terms Template", pluck="name", order_by="name"
        ),
        "selling_price_lists": frappe.get_all(
            "Price List",
            filters={"selling": 1, "enabled": 1},
            pluck="name",
            order_by="name",
        ),
        "buying_price_lists": frappe.get_all(
            "Price List",
            filters={"buying": 1, "enabled": 1},
            pluck="name",
            order_by="name",
        ),
        "receivable_accounts": frappe.get_all(
            "Account",
            filters={"company": company, "is_group": 0, "account_type": "Receivable"},
            pluck="name",
            order_by="name",
        ),
        "payable_accounts": frappe.get_all(
            "Account",
            filters={"company": company, "is_group": 0, "account_type": "Payable"},
            pluck="name",
            order_by="name",
        ),
    }


def party_detail(name: str, company: str) -> dict:
    import frappe

    from asoud_core.permissions import can_access_company

    if not can_access_company(frappe.session.user, company):
        frappe.throw("Not permitted", frappe.PermissionError)
    doc = frappe.get_doc("ASOUD Party Identity", name)
    current_roles = [row for row in doc.roles if row.company == company]
    if not current_roles:
        frappe.throw("Party is not enabled for the selected company")
    references = {
        row.role: {"doctype": row.reference_doctype, "name": row.reference_name}
        for row in current_roles
        if row.reference_name
    }
    policies = []
    for row in current_roles:
        if row.role not in {"Customer", "Supplier"} or not row.reference_name:
            continue
        profile = frappe.db.get_value(
            "ASOUD Party Company Profile",
            {"party_type": row.role, "party": row.reference_name, "company": company},
            [
                "enabled",
                "default_branch",
                "credit_limit",
                "payment_terms_template",
                "price_list",
                "default_account",
            ],
            as_dict=True,
        )
        if profile:
            policies.append({"role": row.role, **profile})
    party = doc.as_dict()
    party["roles"] = [row.as_dict() for row in current_roles]
    party["opening_balances"] = [
        row.as_dict() for row in doc.opening_balances if row.company == company
    ]
    return {
        "party": party,
        "codes": {row.role: row.role_code for row in current_roles},
        "references": references,
        "company_policies": policies,
    }
