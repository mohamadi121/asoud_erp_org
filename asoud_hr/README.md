# ASOUD HR

Custom Frappe/ERPNext v15 application for the human-resources domain of ASOUD ERP.

The app owns organization positions, effective-dated employee assignments, protected
employee documents, daily work reports, formal internal communications, organizational
actions, notification preferences and HR dashboards.

It deliberately reuses `asoud_core` for Holding/Company/Branch, active user context,
authorization scope, approvals, delegation, idempotency and append-only audit events.
It does not modify Frappe or ERPNext core.

Mobile clients, attendance, leave, payroll and operational HRMS installation are outside
the current implementation gate and remain explicit future integrations.

