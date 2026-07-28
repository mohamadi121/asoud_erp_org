# ADR-0005 — ASOUD HR as an integrated domain app

Status: Accepted  
Date: 2026-07-26

## Context

The initial HR PRD described a standalone-first product, a Next.js PWA and a Flutter
mobile application. The implemented ASOUD ERP baseline already uses ERPNext/Frappe v15,
shared organization and approval services, and a Flutter Web PWA. Reimplementing those
capabilities would create conflicting masters, authorization paths and audit histories.

## Decision

- Create `asoud_hr` as the sixth Frappe Custom App and repository.
- Treat HR as an integrated ASOUD ERP module with independently owned domain logic.
- Reuse ERPNext Employee, Department and Designation.
- Reuse `asoud_core` Holding, Company/Branch scope, user context, access, approval,
  delegation, idempotency and append-only audit.
- Use only the existing Flutter Web PWA for the current gate.
- Defer native mobile, attendance, advanced leave and payroll.
- Require a separate compatibility decision before adding Frappe HRMS v15.

## Consequences

- There is one source of truth for identity, company/branch access and approval.
- HR documents can participate in the same work inbox and audit chain.
- The Docker image, installation flow, migration and release manifest now include
  `asoud_hr`.
- The previous PRD remains source material; version 2.0 is the execution baseline.
- Production acceptance still requires real organization data, privacy/retention
  approval and business UAT.

