# Integration Hardening (PR-089)

Free-only integrations must not become production risks. Policy + mechanism:

## Secrets

- `.env` files are development-only. Production injects secrets via a secret
  manager (SOPS/age, Infisical, or self-hosted Vault — pick one per deploy).
- Boot fails fast: `assertIntegrationConfig()` (unknown providers, missing
  hosts) then `assertSecrets()` (missing secret values) in
  `middleware/src/server.js`. Both are production-only; dev/test boot bare.
- Rotation: rotate in the manager, restart the gateway (stateless; pool
  workers pick up env on spawn). Never commit rotated values.
- Diagnostics use `maskedSecrets()` (`[set]` markers, no values). Secret
  scanning: `.gitleaks.toml` + CI secret scan (see Supply chain).

## Quota guard

- `middleware/src/integrations/quota.js`: daily per-provider counters
  (`QUOTA_<PROVIDER>_DAILY`, defaults in code). Alert at 80% (logged once),
  refuse with `QUOTA_EXCEEDED` over budget, `0` = kill switch (hard-disabled,
  callers fall back to local/manual).
- Tripwire, not billing: counters are process-local, reset on restart and at
  UTC midnight. If you need exact accounting, export
  `integration_requests_total` and alert in Prometheus.

## Review queue

- `manual_reviews` (KYC/SCREENING, OPEN→APPROVED/REJECTED, reviewer + reason
  audited). Admin routes `GET /identity/reviews` (list OPEN) and
  `POST /identity/reviews/decide`, both `stepUp: true` (fresh re-auth).
- Approval never auto-fires from OCR: low confidence opens a review; a human
  decides; `IDV_APPLY` still gates the final transition.

## KYC enforcement

- Transfers and loan disbursals above **1,000,000** (major units) require
  `kyc_status=APPROVED`; otherwise `ERROR|KYC_REQUIRED` (HTTP 403). Enforced
  in COBOL (`wallet_core`, `loan_core`), fail-closed on lookup errors.
- Below the bar, email-verified users move freely (risk-based friction).

## Supply chain

- Dependencies: `npm audit` in CI; license posture documented per new dep
  (free-tier SDKs must be OSI-approved).
- Secret scan: gitleaks config at repo root, enforced pre-push and in CI.

## Free-tier limits & fallback (runbook)

| Provider | Guard | On failure |
| --- | --- | --- |
| Email | outbox retry, Mailpit in staging | stays queued, never rolls back signup |
| Telegram | quota + breaker | free SMS → manual review |
| free_sms | quota + breaker | manual review |
| Nusakit | quota + breaker + consent gate | local structural result |
| OCR | confidence ≥ 0.85 | manual review |

Incident: check `/metrics` (`integration_*`), the outbox dashboard, then the
review queue. Kill switch first (`QUOTA_*_DAILY=0` + restart), diagnose after.
