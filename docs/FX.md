# FX Reference Rates (PR-091)

Daily USD-base mid-rates. Reference only — never a settlement basis, never
posted to the ledger.

## Flow

- Cron (`scripts/cron/fetch_fx_rates.mjs`, `FX_BASE`/`FX_QUOTES`/`FX_CRON_ACTOR`)
  fetches via the configured provider (`FX_PROVIDER`) and stores every pair
  via `FX_RATE_STORE` (admin/cron-only), recording the provider name per row.
- `FX_RATE_GET` serves the latest row per pair with `FRESH`/`STALE` marking
  (stale past 24h). Transactions must refuse `STALE` (enforced by callers;
  the next money slice wires the refusal into transfer pricing).
- API down / malformed / empty → the sync fails loudly (cron exits 1) and
  the last snapshot stands, self-marking stale. No partial writes.

## Providers

- `frankfurter` (default, free ECB-sourced): demo/staging grade only.
- `official`: contracted BI/bank feed speaking the same strict v1 JSON
  shape (`{base, date, rates:{IDR: n}}`), via `FX_ENDPOINT` + Bearer
  `FX_API_KEY`. Swapping feeds is config-only — no code change, and the
  stored provider name tells auditors which feed set each row.
- Production refuses anything but `official` at cron boot
  (`assertFxConfig`); `mock` never leaves unit tests.

## Limits

- No settlement use without an official BI/bank rate. Unsupported pairs read
  `NOT_FOUND`; same-pair and non-positive rates are refused at store time.
