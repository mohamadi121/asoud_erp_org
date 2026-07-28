# ADR-0004: Approval workflow and access control

## Status

Accepted — 2026-07-26

## Context

ASOUD ERP needs a role-based approval inbox, configurable sequential and parallel
routes, delegation, immutable actions, and company/branch-scoped user access. The
feature must remain part of the existing ERPNext/Frappe v15 and Flutter Web PWA
architecture. Mobile screenshots are product-flow references, not a native-mobile
target.

## Decision

- ERPNext documents remain the source of truth. Approval requests reference them
  through a Dynamic Link and never duplicate financial content.
- Policies are snapshotted when a request starts so later policy edits do not
  rewrite an in-flight route.
- Source-document digests invalidate stale approvals after effective edits.
- Mutations use dedicated whitelisted services, idempotency keys, optimistic
  versions, backend context authorization, immutable actions, and the existing
  hash-chained audit ledger.
- Frappe User, Role, User Permission and ToDo remain authoritative platform
  primitives. ASOUD adds company/branch access scopes, time schedules and
  temporary delegation.
- Flutter Web PWA uses the existing API client, session, CSRF and WorkContext.
  The desktop shell uses a primary module row plus a contextual ribbon.
- Generic workflow logic belongs to `asoud_core`. No Iran-specific workflow fork
  is created in `asoud_iran`.

## Consequences

- A matching enabled policy blocks ERPNext submission until a valid approved
  request exists for the unchanged draft.
- Configuration of real routes, users, segregation-of-duties rules and SLAs is a
  business deployment activity and is not silently inferred.
- Native mobile, SMS/messenger delivery and external identity providers remain
  outside this technical gate.

