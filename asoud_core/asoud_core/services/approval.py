from __future__ import annotations

import hashlib
import json
from collections.abc import Iterable
from datetime import date, datetime, time, timedelta
from typing import Any


SUPPORTED_SOURCE_DOCTYPES = {
    "Journal Entry",
    "Payment Entry",
    "Sales Invoice",
    "Purchase Invoice",
    "Stock Entry",
    "Delivery Note",
    "Purchase Receipt",
    "Stock Reconciliation",
    "ASOUD Intercompany Transfer",
    "ASOUD Petty Cash Claim",
    "ASOUD Treasury Transaction",
    "ASOUD Daily Work Report",
    "ASOUD Internal Communication",
}

TERMINAL_STATUSES = {"Approved", "Rejected", "Returned", "Cancelled", "Invalidated"}
OPEN_STATUSES = {"Pending"}
ALLOWED_ACTIONS = {"Approve", "Reject", "Return"}

_DIGEST_EXCLUDED_FIELDS = {
    "docstatus",
    "modified",
    "modified_by",
    "creation",
    "owner",
    "_comments",
    "_assign",
    "_liked_by",
    "_seen",
    "asoud_approval_request",
    "asoud_approval_status",
}


def canonical_json(value: Any) -> str:
    return json.dumps(
        value,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
        default=str,
    )


def normalize_date(value: Any) -> date | None:
    if value in (None, ""):
        return None
    if isinstance(value, datetime):
        return value.date()
    if isinstance(value, date):
        return value
    return date.fromisoformat(str(value).strip()[:10])


def normalize_time(value: Any) -> time | None:
    if value in (None, ""):
        return None
    if isinstance(value, datetime):
        return value.time().replace(tzinfo=None)
    if isinstance(value, time):
        return value.replace(tzinfo=None)
    if isinstance(value, timedelta):
        seconds = int(value.total_seconds()) % (24 * 60 * 60)
        return time(seconds // 3600, (seconds % 3600) // 60, seconds % 60)
    text = str(value).strip()
    return time.fromisoformat(text)


def document_digest(document: Any) -> str:
    values = document.as_dict() if hasattr(document, "as_dict") else dict(document)
    stable = {
        key: value
        for key, value in values.items()
        if key not in _DIGEST_EXCLUDED_FIELDS and not key.startswith("__")
    }
    return hashlib.sha256(canonical_json(stable).encode("utf-8")).hexdigest()


def normalize_stages(rows: Iterable[Any]) -> list[dict[str, Any]]:
    stages: list[dict[str, Any]] = []
    for index, row in enumerate(rows, start=1):
        get = row.get if hasattr(row, "get") else lambda key, default=None: getattr(row, key, default)
        sequence = int(get("sequence") or 0)
        approver_type = (get("approver_type") or "").strip()
        approver = (
            (get("user") or "").strip()
            if approver_type == "User"
            else (
                (get("role") or "").strip()
                if approver_type == "Role"
                else "Direct Manager"
            )
        )
        if sequence < 1:
            raise ValueError("Every approval stage must have a positive sequence")
        if approver_type not in {"User", "Role", "Manager"} or not approver:
            raise ValueError("Every approval stage must identify a user or role")
        stages.append(
            {
                "key": str(get("name") or f"stage-{index}"),
                "sequence": sequence,
                "title": (get("stage_title") or f"Stage {sequence}").strip(),
                "approver_type": approver_type,
                "approver": approver,
                "due_hours": max(0, int(get("due_hours") or 0)),
            }
        )
    if not stages:
        raise ValueError("Approval policy must contain at least one stage")
    sequences = sorted({row["sequence"] for row in stages})
    if sequences != list(range(1, max(sequences) + 1)):
        raise ValueError("Approval stage sequences must be contiguous and start at 1")
    return sorted(stages, key=lambda row: (row["sequence"], row["key"]))


def next_sequence(stages: list[dict[str, Any]], current: int) -> int | None:
    later = sorted({int(row["sequence"]) for row in stages if int(row["sequence"]) > current})
    return later[0] if later else None


def required_keys(
    stages: list[dict[str, Any]], sequence: int, parallel_mode: str
) -> set[str]:
    keys = {str(row["key"]) for row in stages if int(row["sequence"]) == sequence}
    if not keys:
        raise ValueError("The current approval sequence has no approvers")
    return {sorted(keys)[0]} if parallel_mode == "Any" else keys


def _source_company_branch(doc: Any) -> tuple[str, str | None]:
    get = doc.get if hasattr(doc, "get") else lambda key, default=None: getattr(doc, key, default)
    company = get("company") or get("source_company")
    branch = get("asoud_branch") or get("branch") or get("source_branch")
    return company, branch or None


def _source_amount(doc: Any) -> float:
    get = doc.get if hasattr(doc, "get") else lambda key, default=None: getattr(doc, key, default)
    for field in (
        "base_grand_total",
        "grand_total",
        "base_paid_amount",
        "paid_amount",
        "amount",
        "total_debit",
    ):
        value = get(field)
        if value not in (None, ""):
            return float(value or 0)
    return 0.0


def _find_policy(doc: Any):
    import frappe

    company, branch = _source_company_branch(doc)
    amount = _source_amount(doc)
    rows = frappe.get_all(
        "ASOUD Approval Policy",
        filters={"enabled": 1, "document_type": doc.doctype},
        fields=[
            "name",
            "company",
            "branch",
            "minimum_amount",
            "maximum_amount",
            "priority",
            "allow_self_approval",
            "parallel_mode",
        ],
        order_by="priority desc, modified desc",
        limit_page_length=0,
    )
    for row in rows:
        if row.company and row.company != company:
            continue
        if row.branch and row.branch != branch:
            continue
        if row.minimum_amount not in (None, "") and amount < float(row.minimum_amount):
            continue
        if row.maximum_amount not in (None, "") and float(row.maximum_amount) > 0:
            if amount > float(row.maximum_amount):
                continue
        return frappe.get_doc("ASOUD Approval Policy", row.name)
    return None


def validate_policy(doc, method: str | None = None) -> None:
    import frappe

    if doc.document_type not in SUPPORTED_SOURCE_DOCTYPES:
        frappe.throw("This document type is not supported by ASOUD approval")
    if doc.branch:
        branch_company = frappe.db.get_value("ASOUD Branch", doc.branch, "company")
        if not branch_company or branch_company != doc.company:
            frappe.throw("Approval policy branch must belong to its company")
    if float(doc.maximum_amount or 0) and float(doc.maximum_amount) < float(
        doc.minimum_amount or 0
    ):
        frappe.throw("Maximum amount cannot be less than minimum amount")
    try:
        normalize_stages(doc.stages)
    except ValueError as exc:
        frappe.throw(str(exc))


def _policy_snapshot(policy) -> dict[str, Any]:
    return {
        "policy": policy.name,
        "allow_self_approval": bool(policy.allow_self_approval),
        "parallel_mode": policy.parallel_mode or "All",
        "stages": normalize_stages(policy.stages),
    }


def _get_open_request(source_doctype: str, source_name: str) -> str | None:
    import frappe

    return frappe.db.get_value(
        "ASOUD Approval Request",
        {
            "source_doctype": source_doctype,
            "source_name": source_name,
            "status": ["in", list(OPEN_STATUSES)],
        },
        "name",
        order_by="creation desc",
    )


def start_request(source_doctype: str, source_name: str) -> dict[str, Any]:
    import frappe
    from frappe.utils import now_datetime

    if source_doctype not in SUPPORTED_SOURCE_DOCTYPES:
        frappe.throw("Unsupported approval source document")
    source = frappe.get_doc(source_doctype, source_name)
    if not source.has_permission("read"):
        frappe.throw("Not permitted", frappe.PermissionError)
    if int(source.docstatus or 0) != 0:
        frappe.throw("Only draft documents can enter approval")
    company, branch = _source_company_branch(source)
    if not company:
        frappe.throw("Approval source must belong to a company")
    from asoud_core.permissions import can_access_context

    if not can_access_context(frappe.session.user, company, branch):
        frappe.throw("Not permitted", frappe.PermissionError)
    existing = _get_open_request(source_doctype, source_name)
    if existing:
        return request_detail(existing)
    policy = _find_policy(source)
    if not policy:
        frappe.throw("No enabled approval policy matches this document")
    snapshot = _policy_snapshot(policy)
    request = frappe.get_doc(
        {
            "doctype": "ASOUD Approval Request",
            "source_doctype": source_doctype,
            "source_name": source_name,
            "company": company,
            "branch": branch,
            "policy": policy.name,
            "policy_snapshot": canonical_json(snapshot),
            "source_digest": document_digest(source),
            "amount": _source_amount(source),
            "requested_by": frappe.session.user,
            "requested_on": now_datetime(),
            "status": "Pending",
            "current_sequence": 1,
        }
    ).insert(ignore_permissions=True)
    _set_source_status(source, request.name, "Pending")
    _refresh_assignments(request)
    from asoud_core.services.audit import append_event

    append_event(
        "approval.requested",
        resource_doctype=source_doctype,
        resource_name=source_name,
        company=company,
        branch=branch,
        after={"request": request.name, "policy": policy.name},
    )
    return request_detail(request.name)


def _set_source_status(source, request_name: str, status: str) -> None:
    import frappe

    values = {}
    if frappe.db.has_column(source.doctype, "asoud_approval_request"):
        values["asoud_approval_request"] = request_name
    if frappe.db.has_column(source.doctype, "asoud_approval_status"):
        values["asoud_approval_status"] = status
    if values:
        frappe.db.set_value(source.doctype, source.name, values, update_modified=False)


def _snapshot(request) -> dict[str, Any]:
    try:
        value = json.loads(request.policy_snapshot)
    except (TypeError, ValueError, json.JSONDecodeError):
        value = {}
    if not isinstance(value, dict) or not isinstance(value.get("stages"), list):
        raise ValueError("Approval request policy snapshot is invalid")
    return value


def _active_stage_rows(request) -> list[dict[str, Any]]:
    snapshot = _snapshot(request)
    return [
        row
        for row in snapshot["stages"]
        if int(row["sequence"]) == int(request.current_sequence)
    ]


def _active_delegation(principal: str, delegate: str, company: str, branch: str | None) -> bool:
    import frappe
    from frappe.utils import now_datetime

    now = now_datetime()
    rows = frappe.get_all(
        "ASOUD Approval Delegation",
        filters={
            "principal_user": principal,
            "delegate_user": delegate,
            "enabled": 1,
            "starts_on": ["<=", now],
            "ends_on": [">=", now],
        },
        fields=["company", "branch"],
        limit_page_length=0,
    )
    return any(
        (not row.company or row.company == company)
        and (not row.branch or row.branch == branch)
        for row in rows
    )


def _match_approver(request, user: str) -> tuple[str, str | None] | None:
    import frappe

    roles = set(frappe.get_roles(user))
    for row in _active_stage_rows(request):
        if row["approver_type"] == "User":
            principal = row["approver"]
            if user == principal:
                return row["key"], None
            if _active_delegation(principal, user, request.company, request.branch):
                return row["key"], principal
        elif row["approver_type"] == "Role" and row["approver"] in roles:
            return row["key"], None
        elif row["approver_type"] == "Manager":
            manager_user = _source_manager_user(request)
            if user == manager_user:
                return row["key"], None
            if manager_user and _active_delegation(
                manager_user, user, request.company, request.branch
            ):
                return row["key"], manager_user
    return None


def _source_manager_user(request) -> str | None:
    import frappe

    employee = frappe.db.get_value(
        request.source_doctype, request.source_name, "employee"
    )
    if not employee:
        return None
    manager = frappe.db.get_value("Employee", employee, "reports_to")
    return frappe.db.get_value("Employee", manager, "user_id") if manager else None


def can_act(request, user: str) -> bool:
    if request.status != "Pending":
        return False
    return _match_approver(request, user) is not None


def _assert_access_schedule(user: str, company: str, branch: str | None) -> None:
    import frappe
    from frappe.utils import now_datetime

    rows = frappe.get_all(
        "ASOUD User Access Schedule",
        filters={"user": user, "enabled": 1},
        fields=[
            "company",
            "branch",
            "starts_on",
            "ends_on",
            "weekdays",
            "from_time",
            "to_time",
        ],
        limit_page_length=0,
    )
    scoped = [
        row
        for row in rows
        if (not row.company or row.company == company)
        and (not row.branch or row.branch == branch)
    ]
    if not scoped:
        return
    now = now_datetime()
    weekday = str(now.weekday())
    current_time = now.time()
    for row in scoped:
        starts_on = normalize_date(row.starts_on)
        ends_on = normalize_date(row.ends_on)
        from_time = normalize_time(row.from_time)
        to_time = normalize_time(row.to_time)
        if starts_on and now.date() < starts_on:
            continue
        if ends_on and now.date() > ends_on:
            continue
        allowed_days = {part.strip() for part in (row.weekdays or "").split(",") if part.strip()}
        if allowed_days and weekday not in allowed_days:
            continue
        if from_time and current_time < from_time:
            continue
        if to_time and current_time > to_time:
            continue
        return
    frappe.throw("The current time is outside your permitted access schedule")


def perform_action(
    request_name: str,
    action: str,
    comment: str,
    expected_version: str,
) -> dict[str, Any]:
    import frappe
    from frappe.utils import now_datetime

    action = (action or "").strip().title()
    comment = (comment or "").strip()
    if action not in ALLOWED_ACTIONS:
        frappe.throw("Unsupported approval action")
    if action in {"Reject", "Return"} and not comment:
        frappe.throw("A reason is required for reject or return")
    lock_name = f"asoud_approval_{hashlib.sha256(request_name.encode()).hexdigest()[:24]}"
    if not frappe.db.sql("select get_lock(%s, 10)", lock_name)[0][0]:
        frappe.throw("Could not acquire approval lock")
    try:
        request = frappe.get_doc("ASOUD Approval Request", request_name)
        if request.status != "Pending":
            frappe.throw("This approval request is no longer pending")
        if expected_version and str(request.modified) != str(expected_version):
            frappe.throw("Approval request changed; reload it before acting")
        from asoud_core.permissions import can_access_context

        if not can_access_context(frappe.session.user, request.company, request.branch):
            frappe.throw("Not permitted", frappe.PermissionError)
        _assert_access_schedule(frappe.session.user, request.company, request.branch)
        match = _match_approver(request, frappe.session.user)
        if not match:
            frappe.throw("You are not an approver for the current stage", frappe.PermissionError)
        approver_key, acting_for = match
        snapshot = _snapshot(request)
        if (
            action == "Approve"
            and not bool(snapshot.get("allow_self_approval"))
            and request.requested_by == frappe.session.user
        ):
            frappe.throw("Self approval is disabled for this policy")
        source = frappe.get_doc(request.source_doctype, request.source_name)
        if document_digest(source) != request.source_digest:
            frappe.throw(
                "The source document changed; save it normally to invalidate this request"
            )
        if frappe.db.exists(
            "ASOUD Approval Action",
            {
                "approval_request": request.name,
                "sequence": request.current_sequence,
                "approver_key": approver_key,
                "action": "Approve",
            },
        ):
            frappe.throw("This approval position has already been completed")

        previous_status = request.status
        action_doc = frappe.get_doc(
            {
                "doctype": "ASOUD Approval Action",
                "approval_request": request.name,
                "sequence": request.current_sequence,
                "approver_key": approver_key,
                "action": action,
                "actor": frappe.session.user,
                "acting_for": acting_for,
                "acted_on": now_datetime(),
                "comment": comment,
                "request_version": str(request.modified),
                "ip_address": getattr(frappe.local, "request_ip", None),
                "user_agent": (
                    frappe.get_request_header("User-Agent")
                    if getattr(frappe.local, "request", None)
                    else None
                ),
                "before_status": previous_status,
            }
        ).insert(ignore_permissions=True)

        if action == "Reject":
            request.db_set({"status": "Rejected", "completed_on": now_datetime()})
        elif action == "Return":
            request.db_set({"status": "Returned", "completed_on": now_datetime()})
        else:
            approved_keys = set(
                frappe.get_all(
                    "ASOUD Approval Action",
                    filters={
                        "approval_request": request.name,
                        "sequence": request.current_sequence,
                        "action": "Approve",
                    },
                    pluck="approver_key",
                )
            )
            required = required_keys(
                snapshot["stages"],
                int(request.current_sequence),
                snapshot.get("parallel_mode") or "All",
            )
            if required.issubset(approved_keys) or (
                snapshot.get("parallel_mode") == "Any" and approved_keys
            ):
                following = next_sequence(snapshot["stages"], int(request.current_sequence))
                if following is None:
                    request.db_set({"status": "Approved", "completed_on": now_datetime()})
                else:
                    request.db_set("current_sequence", following)

        request.reload()
        frappe.db.set_value(
            "ASOUD Approval Action",
            action_doc.name,
            "after_status",
            request.status,
            update_modified=False,
        )
        _set_source_status(source, request.name, request.status)
        _refresh_assignments(request)
        from asoud_core.services.audit import append_event

        append_event(
            f"approval.{action.lower()}",
            resource_doctype=request.source_doctype,
            resource_name=request.source_name,
            company=request.company,
            branch=request.branch,
            reason=comment,
            before={"request_status": previous_status},
            after={
                "request": request.name,
                "request_status": request.status,
                "sequence": request.current_sequence,
                "acting_for": acting_for,
            },
        )
        return request_detail(request.name)
    finally:
        frappe.db.sql("select release_lock(%s)", lock_name)


def _users_for_stage(request) -> set[str]:
    import frappe

    users: set[str] = set()
    for row in _active_stage_rows(request):
        if row["approver_type"] == "User":
            users.add(row["approver"])
        elif row["approver_type"] == "Manager":
            manager_user = _source_manager_user(request)
            if manager_user:
                users.add(manager_user)
        else:
            users.update(
                frappe.get_all(
                    "Has Role",
                    filters={"role": row["approver"], "parenttype": "User"},
                    pluck="parent",
                )
            )
    return {user for user in users if user and user not in {"Guest"}}


def _close_assignments(request_name: str) -> None:
    import frappe

    for name in frappe.get_all(
        "ToDo",
        filters={
            "reference_type": "ASOUD Approval Request",
            "reference_name": request_name,
            "status": "Open",
        },
        pluck="name",
    ):
        frappe.db.set_value("ToDo", name, "status", "Closed")


def _refresh_assignments(request) -> None:
    import frappe
    from frappe.utils import add_to_date, now_datetime

    _close_assignments(request.name)
    if request.status != "Pending":
        return
    due_hours = max((int(row.get("due_hours") or 0) for row in _active_stage_rows(request)), default=0)
    due_date = add_to_date(now_datetime(), hours=due_hours) if due_hours else None
    for user in sorted(_users_for_stage(request)):
        frappe.get_doc(
            {
                "doctype": "ToDo",
                "allocated_to": user,
                "description": f"ASOUD approval: {request.source_doctype} {request.source_name}",
                "reference_type": "ASOUD Approval Request",
                "reference_name": request.name,
                "status": "Open",
                "date": due_date,
                "priority": "Medium",
            }
        ).insert(ignore_permissions=True)


def request_detail(request_name: str) -> dict[str, Any]:
    import frappe

    request = frappe.get_doc("ASOUD Approval Request", request_name)
    user = frappe.session.user
    from asoud_core.permissions import can_access_context

    allowed = (
        can_access_context(user, request.company, request.branch)
        and (
            request.requested_by == user
            or can_act(request, user)
            or "System Manager" in frappe.get_roles(user)
            or "Accounts Manager" in frappe.get_roles(user)
        )
    )
    if not allowed:
        frappe.throw("Not permitted", frappe.PermissionError)
    actions = frappe.get_all(
        "ASOUD Approval Action",
        filters={"approval_request": request.name},
        fields=[
            "name",
            "sequence",
            "action",
            "actor",
            "acting_for",
            "acted_on",
            "comment",
            "before_status",
            "after_status",
        ],
        order_by="acted_on, creation",
        limit_page_length=0,
    )
    return {
        "name": request.name,
        "source_doctype": request.source_doctype,
        "source_name": request.source_name,
        "company": request.company,
        "branch": request.branch,
        "policy": request.policy,
        "amount": float(request.amount or 0),
        "requested_by": request.requested_by,
        "requested_on": str(request.requested_on),
        "status": request.status,
        "current_sequence": int(request.current_sequence or 0),
        "version": str(request.modified),
        "can_act": can_act(request, user),
        "stages": _snapshot(request)["stages"],
        "actions": actions,
    }


def normalize_inbox_request(
    view: str,
    status: str,
    limit: int,
) -> tuple[str, str, int]:
    view = (view or "incoming").strip().lower()
    if view not in {"incoming", "outgoing", "history"}:
        raise ValueError("Unsupported approval inbox view")
    allowed_statuses = {
        "Pending",
        "Approved",
        "Rejected",
        "Returned",
        "Invalidated",
    }
    status = (status or "").strip().title()
    if status and status not in allowed_statuses:
        raise ValueError("Unsupported approval status filter")
    return view, status, min(max(int(limit or 50), 1), 100)


def inbox(
    company: str,
    branch: str | None = None,
    view: str = "incoming",
    limit: int = 50,
    search: str = "",
    status: str = "",
) -> dict[str, Any]:
    import frappe

    from asoud_core.permissions import can_access_context

    branch = branch or None
    if not can_access_context(frappe.session.user, company, branch):
        frappe.throw("Not permitted", frappe.PermissionError)
    try:
        view, status, limit = normalize_inbox_request(view, status, limit)
    except ValueError as error:
        frappe.throw(str(error))
    filters: dict[str, Any] = {"company": company}
    if branch:
        filters["branch"] = branch
    if view == "outgoing":
        filters["requested_by"] = frappe.session.user
        if status:
            filters["status"] = status
    elif view == "history":
        filters["status"] = status or ["!=", "Pending"]
    else:
        filters["status"] = "Pending"
    rows = frappe.get_all(
        "ASOUD Approval Request",
        filters=filters,
        fields=[
            "name",
            "source_doctype",
            "source_name",
            "company",
            "branch",
            "policy",
            "amount",
            "requested_by",
            "requested_on",
            "status",
            "current_sequence",
            "modified",
        ],
        order_by="requested_on desc",
        limit_page_length=100,
    )
    if view == "incoming":
        rows = [
            row
            for row in rows
            if can_act(frappe.get_doc("ASOUD Approval Request", row.name), frappe.session.user)
        ]
    elif view == "history":
        privileged = bool(
            {"System Manager", "Accounts Manager"} & set(frappe.get_roles())
        )
        acted_requests = set(
            frappe.get_all(
                "ASOUD Approval Action",
                filters={"actor": frappe.session.user},
                pluck="approval_request",
                limit_page_length=0,
            )
        )
        rows = [
            row
            for row in rows
            if privileged
            or row.requested_by == frappe.session.user
            or row.name in acted_requests
        ]
    query = (search or "").strip().casefold()
    if query:
        rows = [
            row
            for row in rows
            if query
            in " ".join(
                str(value or "")
                for value in (
                    row.name,
                    row.source_doctype,
                    row.source_name,
                    row.policy,
                    row.requested_by,
                    row.status,
                )
            ).casefold()
        ]
    rows = rows[:limit]
    return {
        "view": view,
        "items": [
            {
                **dict(row),
                "amount": float(row.amount or 0),
                "current_sequence": int(row.current_sequence or 0),
                "version": str(row.modified),
            }
            for row in rows
        ],
        "counts": {
            "incoming": len(rows) if view == "incoming" else _incoming_count(company, branch),
            "outgoing": frappe.db.count(
                "ASOUD Approval Request",
                {
                    "company": company,
                    **({"branch": branch} if branch else {}),
                    "requested_by": frappe.session.user,
                    "status": "Pending",
                },
            ),
            "history": (
                len(rows)
                if view == "history"
                else frappe.db.count(
                    "ASOUD Approval Request",
                    {
                        "company": company,
                        **({"branch": branch} if branch else {}),
                        "requested_by": frappe.session.user,
                        "status": ["!=", "Pending"],
                    },
                )
            ),
        },
    }


def _incoming_count(company: str, branch: str | None) -> int:
    import frappe

    filters: dict[str, Any] = {"company": company, "status": "Pending"}
    if branch:
        filters["branch"] = branch
    count = 0
    for name in frappe.get_all(
        "ASOUD Approval Request", filters=filters, pluck="name", limit_page_length=0
    ):
        if can_act(frappe.get_doc("ASOUD Approval Request", name), frappe.session.user):
            count += 1
    return count


def policy_catalog(company: str, branch: str | None = None) -> list[dict[str, Any]]:
    import frappe

    from asoud_core.permissions import can_access_context

    branch = branch or None
    if not can_access_context(frappe.session.user, company, branch):
        frappe.throw("Not permitted", frappe.PermissionError)
    rows = frappe.get_all(
        "ASOUD Approval Policy",
        filters={"enabled": 1},
        fields=[
            "name",
            "policy_title",
            "document_type",
            "company",
            "branch",
            "minimum_amount",
            "maximum_amount",
            "parallel_mode",
            "priority",
        ],
        order_by="priority desc, policy_title",
        limit_page_length=0,
    )
    return [
        {
            **dict(row),
            "minimum_amount": float(row.minimum_amount or 0),
            "maximum_amount": float(row.maximum_amount or 0),
        }
        for row in rows
        if (not row.company or row.company == company)
        and (not row.branch or row.branch == branch)
    ]


def assert_document_approved(doc, method: str | None = None) -> None:
    import frappe

    policy = _find_policy(doc)
    if not policy:
        return
    request_name = frappe.db.get_value(
        "ASOUD Approval Request",
        {
            "source_doctype": doc.doctype,
            "source_name": doc.name,
            "status": "Approved",
        },
        "name",
        order_by="completed_on desc",
    )
    if not request_name:
        frappe.throw("This document requires completed ASOUD approval before submission")
    request = frappe.get_doc("ASOUD Approval Request", request_name)
    if request.policy != policy.name or document_digest(doc) != request.source_digest:
        frappe.throw("The approved document or its approval policy has changed; request approval again")


def invalidate_changed_requests(doc, method: str | None = None) -> None:
    import frappe

    names = frappe.get_all(
        "ASOUD Approval Request",
        filters={
            "source_doctype": doc.doctype,
            "source_name": doc.name,
            "status": ["in", ["Pending", "Approved"]],
        },
        pluck="name",
        limit_page_length=0,
    )
    current_digest = document_digest(doc)
    for name in names:
        request = frappe.get_doc("ASOUD Approval Request", name)
        if request.source_digest == current_digest:
            continue
        previous_status = request.status
        request.db_set("status", "Invalidated")
        _set_source_status(doc, request.name, "Invalidated")
        _close_assignments(request.name)
        from asoud_core.services.audit import append_event

        append_event(
            "approval.invalidated",
            resource_doctype=doc.doctype,
            resource_name=doc.name,
            company=request.company,
            branch=request.branch,
            reason="Source document changed after approval request",
            before={"request_status": previous_status},
            after={"request_status": "Invalidated", "request": request.name},
        )


def prevent_action_mutation(doc, method: str | None = None) -> None:
    import frappe

    if not doc.is_new():
        frappe.throw("Approval actions are immutable")
