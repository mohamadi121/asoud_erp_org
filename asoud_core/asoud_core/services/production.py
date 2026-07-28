from __future__ import annotations

from urllib.parse import urlparse


def validate_production_origin(origin: str) -> str:
    candidate = origin.strip().rstrip("/")
    parsed = urlparse(candidate)
    if parsed.scheme != "https" or not parsed.hostname:
        raise ValueError("Production origin must be an absolute HTTPS URL")
    if parsed.hostname in {"localhost", "127.0.0.1", "::1"}:
        raise ValueError("Production origin cannot use localhost")
    if parsed.username or parsed.password or parsed.query or parsed.fragment:
        raise ValueError("Production origin must not contain credentials, query or fragment")
    return candidate


def apply_security_baseline(origin: str) -> dict:
    import frappe

    origin = validate_production_origin(origin)
    settings = {
        "enable_two_factor_auth": 1,
        "allow_login_using_mobile_number": 0,
        "allow_login_using_user_name": 0,
        "login_with_email_link": 0,
        "session_expiry": "06:00",
        "document_share_key_expiry": 7,
    }
    meta = frappe.get_meta("System Settings")
    applied = {}
    for field, value in settings.items():
        if meta.has_field(field):
            frappe.db.set_single_value("System Settings", field, value)
            applied[field] = value
    frappe.db.set_single_value("Website Settings", "home_page", "login")
    frappe.db.set_default("desktop:home_page", "Workspaces")
    frappe.db.commit()
    return {
        "status": "applied",
        "origin": origin,
        "settings": applied,
        "developer_mode_required": 0,
    }
