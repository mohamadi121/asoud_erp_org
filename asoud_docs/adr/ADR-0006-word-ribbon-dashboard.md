# ADR-0006: Word-style RTL dashboard shell

- Status: Accepted
- Date: 2026-07-27

## Decision

ASOUD ERP uses a desktop-first Persian RTL shell with a primary horizontal
module bar and a context-sensitive Ribbon. Navigation drawers remain secondary
overlays. The dashboard consumes one permission-scoped aggregate endpoint
instead of coordinating multiple independent requests in the browser.

## Consequences

- Flutter Web PWA remains the only active UI platform.
- ERPNext/Frappe remains the authority for permission checks and business data.
- Dashboard cards, charts, inbox, notifications, recent documents and
  quick-create contracts share one consistent snapshot.
- Quick creation reuses the operational allowlist and idempotent draft API.
- The SVG reference and Flutter implementation use the same named regions and
  design tokens.

## Rejected alternatives

- A permanent sidebar as the primary module navigation.
- A separate dashboard backend or database.
- Browser-side aggregation from unrelated endpoints.
- Hard-coded quick-create forms disconnected from Frappe document contracts.
