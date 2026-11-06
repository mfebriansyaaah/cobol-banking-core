# FX Reference Rates (PR-091)

Daily USD-base mid-rates from Frankfurter (free, ECB-sourced). Reference
only — never a settlement basis, never posted to the ledger.

## Flow

- Cron (`scripts/cron/fetch_fx_rates.mjs`, `FX_BASE`/`FX_QUOTES`/`FX_CRON_ACTOR`)
  fetches and stores every pair via `FX_RATE_STORE` (admin/cron-only).
- `FX_RATE_GET` serves the latest row per pair with `FRESH`/`STALE` marking
  (stale past 24h). Transactions must refuse `STALE` (enforced by callers;
  the next money slice wires the refusal into transfer pricing).
- API down / malformed / empty → the sync fails loudly (cron exits 1) and
  the last snapshot stands, self-marking stale. No partial writes.

## Limits

- No settlement use without an official BI/bank rate. Unsupported pairs read
  `NOT_FOUND`; same-pair and non-positive rates are refused at store time.
