# ASOUD infrastructure

Development/staging baseline for ERPNext/Frappe v15.117.0. It builds a derived image containing `asoud_core` and `asoud_iran`, with MariaDB 10.6, separate Redis cache/queue services, web, websocket, scheduler and workers. Production secrets must never be committed.

## Start locally

1. Copy `.env.example` to `.env` and replace every `change-me` value.
2. Run `./scripts/bootstrap.ps1`. It builds the image, creates the Site when absent, installs ERPNext and both ASOUD apps, migrates and starts all services.
3. Open `http://localhost:8080`.
4. Run `./scripts/smoke-test.ps1` after infrastructure changes.

## Phase-one acceptance gate

After the stack is running, execute:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\phase-one-gate.ps1
```

The gate runs Core/Iran unit tests, Flutter format/analyze/test/release build,
creates idempotent reference organization and users, executes real Frappe
permission/numbering/period-lock/closing-opening checks, verifies the HTTP login
and active-context round trip, and finishes with the container health endpoint.
The generated demo password exists only in process memory and is never committed.

## Phase-two acceptance gate

After migration, execute:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\phase-two-gate.ps1
```

This first runs the complete phase-one regression gate, then validates the
96-account versioned COA, repeatable setup across two Companies, IRR/Toman,
Jalali conversion, floating-detail permission and GL snapshot, trial-balance
reconciliation, PWA release build and positive/negative HTTP permission paths.
`-ReuseFlutterPackages` may be used locally only after dependencies have already
been resolved; CI always resolves them from the lockfile.

The `Phase One Integration` and `Phase Two Integration` GitHub workflows are ready for the later private-repository
publication step. Because it checks out sibling private repositories, the
`ASOUD_REPOS_TOKEN` Actions secret must be configured after those repositories
are created.

## Phase-three and phase-four acceptance gate

Run `./scripts/phase-three-four-gate.ps1` after migration. It preserves the
complete phase-one/two regression chain, then validates the shared accounting
document registry, immutable temporary numbers, selected same-day
consolidation, idempotent Batch numbering and history. It also executes real
party-aware closing/opening vouchers, dimensional two-year reconciliation,
final numbering and safe retry.

The base image is pinned to the locally reviewed ERPNext version. For a release, also pin the image digest and record it in the release manifest. Both custom apps are installed into the derived image and are installed automatically when the site is created; do not install code manually into running production containers.

## Phase-five acceptance gate

Run `./scripts/phase-five-gate.ps1` after migration. It executes the complete
phase-one through phase-four regression chain and then validates shared
Holding-level Customer/Supplier/Item masters with independent Company profiles,
branch warehouses, company credit limits, goods and service sales, delivery,
sales invoicing and receipt, purchase ordering, receipt, purchase invoicing and
payment, stock reconciliation, cross-branch transfer, the accounting registry
and balanced GL output. The matching GitHub workflow is prepared but publication
remains intentionally deferred.

## Safety and operations

## Phase-six treasury acceptance gate

Run `./scripts/phase-six-gate.ps1` after migration. It first executes the full
phase-one through phase-five regression chain, then validates company/branch
Bank, Cash and Petty Cash accounts, real receipt/transfer/funding entries,
petty-cash expense settlement, incoming/outgoing/returned cheque lifecycles,
cash count adjustment, exact bank reconciliation, balanced GL and accounting
registry integration. The phase-six scenario is executed twice to detect
duplicate documents or non-idempotent transitions. The matching GitHub workflow
is prepared; repository publication remains deferred.

## Phase-eight reporting and pilot-readiness gate

Run `./scripts/phase-eight-gate.ps1` after migration. It preserves the complete
phase-one through phase-six regression chain and validates six canonical
accounting reports, JSON checksums, CSV/XLSX/RTL PDF exports, controlled opening
balance migration, branch/company permission denial and the five-second pilot
performance budget. It then takes a database/files backup, restores it into an
isolated randomly named Site, compares the accounting fingerprint and removes
only that verified temporary Site. Use `-SkipRestoreDrill` only for a quick local
diagnostic run; CI executes the complete restore drill. The matching workflow is
prepared but GitHub publication remains deferred.

## Phase-seven intercompany and consolidation gate

Run `./scripts/phase-seven-gate.ps1`. It preserves the earlier regression chain,
executes source/destination approval twice, verifies paired legal Journal
Entries, registry links, compensation, direct-cancellation denial, complete
account mapping, balanced eliminations and positive/negative HTTP holding
permissions. A restore drill is included unless `-SkipRestoreDrill` is selected.

## Phase-nine controlled pilot

Run `./scripts/phase-nine-pilot.ps1`. It creates the persistent isolated
`asoud-pilot.localhost` Site and database when absent, installs and migrates the
four applications, executes eight technical UAT scenarios twice, checks the
site endpoint, writes ignored evidence to `artifacts/phase-nine-uat.json`, and
performs an isolated backup/restore fingerprint drill. The recorded outcome is
`Technical Go Only` for synthetic data; it cannot substitute for real business
sign-off. Use `-SkipRegressionGate` only when the complete preceding chain has
already passed in the same source state.

- This file is a development baseline, not a complete production deployment.
- Use TLS and a reverse proxy in production.
- Store secrets in the deployment platform secret manager.
- Back up the database, site files, encryption key and release manifest together.
- Test restore before go-live.

## Phases ten through thirteen readiness gate

Run `./scripts/phase-ten-thirteen-gate.ps1`. The gate validates the production
Compose overlay without deploying it, migrates the isolated pilot, executes the
operational workbench/idempotency/audit/migration/cutover acceptance twice,
writes `artifacts/phase-ten-thirteen-technical-readiness.json`, and performs an
isolated restore drill.

Production assets are intentionally separate from the development baseline:

- `compose.production.yaml`: TLS proxy, authenticated Redis, binary logging,
  no-new-privileges and host/container monitoring
- `production/Caddyfile`: HTTPS and response security headers
- `production/prometheus.yml` and `production/alerts.yml`: host/container
  metrics and baseline alerts
- `scripts/production-preflight.ps1`: fail-closed configuration validation
- `scripts/apply-production-security.ps1`: HTTPS origin, disabled developer mode
  and Frappe MFA/session baseline
- `production/RUNBOOK.md`: release, recovery, security and incident controls

These assets provide technical readiness only. A Production deployment requires
real domain/DNS, secret manager, offsite backup target, alert receiver, real-data
reconciliation and signed business approval.

## Phases fourteen through sixteen gate

Run `./scripts/phase-fourteen-sixteen-gate.ps1`. It preserves the phases 1-13
regression, rebuilds the ERPNext v15 image, migrates the isolated pilot, verifies
the tax, banking/Sayad and multi-currency consolidation contracts twice, writes
`artifacts/phase-fourteen-sixteen-readiness.json`, and performs an isolated
backup/restore drill.

Production tax and bank/Sayad calls are fail-closed. They require an audited
provider adapter, contracted endpoint, external secret references and official
acceptance credentials. The built-in deterministic adapters are sandbox-only
and the readiness artifact explicitly records that production connectivity is
not claimed.
