# Corporate Registry (PR-097, GLEIF)

Free global LEI lookups cached for corporate onboarding triage.

## Limits (read twice)

- GLEIF is **not** AHU/akta and **not** proof of Indonesian registration.
  Not every Indonesian company holds an LEI. Never claim either.
- Cache only: `CORP_RESOLVE` upserts (admin/cron), `CORP_STATUS` reads.
  LEI shape (20-char) validated in COBOL; unknown LEIs read `NOT_FOUND`.

## Flow

- Adapter (`gleif.js`): `lookupLei` (exact) + `searchLeis` (name, top 5).
  3s timeout, resilientFetch breaker, malformed/404 handled; failures
  reject so the caller falls back to manual input.
- No PII beyond the queried name; nothing raw in logs.
