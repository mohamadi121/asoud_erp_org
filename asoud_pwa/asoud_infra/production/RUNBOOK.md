# ASOUD ERP production runbook

This runbook is a technical baseline, not authorization to process real data.

## Release controls

- Deploy only a reviewed immutable image tag and recorded digest.
- Keep `.env.production` outside Git and source all secrets from the deployment
  platform secret manager.
- Run migration on a backup-restorable staging clone before production.
- Take database, public/private files, encryption key and release manifest
  together before every release.
- Keep one previous immutable image and a tested database rollback plan.

## Availability and recovery

- Alert on HTTPS health, backend/worker/scheduler health, queue depth, database
  disk, backup age and certificate expiry.
- Store encrypted backups offsite under a separate credential boundary.
- Target RPO is 15 minutes and target RTO is 4 hours until a stricter business
  SLA is approved.
- Run an isolated restore drill at least monthly and after schema-critical
  changes.

## Security

- Enforce MFA for System Manager, Accounts Manager and Holding Manager.
- Prohibit shared accounts and rotate bootstrap Administrator credentials.
- Restrict Desk to administrative roles; operational users use the PWA.
- Review permission-denial and privileged audit events daily during cutover.
- Terminate support access automatically and record its ticket and reason.

## Incident rollback

1. Freeze writes and record the incident time.
2. Preserve logs and current release manifest.
3. Decide application rollback versus full data restore; never restore over the
   only copy of production.
4. Validate GL balance, document counts and site fingerprint on the isolated
   target.
5. Reopen access only after the incident owner and finance owner sign the
   reconciliation record.
