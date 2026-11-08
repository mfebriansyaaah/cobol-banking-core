# External Integrations (PR-080)

One env-driven switchboard (`middleware/services/integrations/`) for every
external provider. Call sites use the frozen interfaces; adding a channel
(PR-081+) means a new factory behind the same interface, never a call-site
change.

## Matrix

| Channel   | `local`/`log`/`mock`                    | `free`/`sandbox`                                               | `production`                      |
| --------- | --------------------------------------- | -------------------------------------------------------------- | --------------------------------- |
| Email     | `log` (default; event only, no network) | `mailpit` (local SMTP)                                         | `smtp` (needs `SMTP_HOST`)        |
| Phone OTP | `mock` (default; recorded)              | `telegram` (Bot API + linked chat) / `free_sms` (env endpoint) | same, needs `TELEGRAM_BOT_TOKEN`  |
| Identity  | `mock` (default; approves)              | `local` (structural NIK only)                                  | `local` (never Dukcapil-verified) |
| KTP OCR   | `mock` (default)                        | `local` (PR-084 decides Tesseract)                             | manual review required            |

## Rules

1. **Fail fast, not first-request:** unknown provider values and
   production-without-secrets throw in `assertIntegrationConfig()` at boot.
2. **Lazy heavies:** `nodemailer`/SDKs import inside send paths only.
   Importing the registry must never need network or secrets.
3. **Health is uniform:** `{ ok, provider, detail? }`, never throws.
4. **Unimplemented ≠ silent:** real-provider names that land in later PRs
   throw `not implemented yet (PR-0xx)` until they exist.
5. **PII:** mocks log event shapes with values redacted (`nik: redacted`,
   never the code). See the plan's hard rules (no Dukcapil claims, no
   unofficial gateways).

## Env

See `middleware/.env.example` (`INTEGRATION_MODE`, `EMAIL_PROVIDER`,
`PHONE_OTP_PROVIDER`, `IDENTITY_PROVIDER`, `KTP_OCR_PROVIDER`).

## Resilience (PR-086)

Every HTTP adapter goes through `resilientFetch`
(`middleware/services/integrations/resilience.js`; `http.js` holds the bare
timeout primitive):

- **Timeout** 4s default (3s Nusakit), via `AbortSignal` — no hanging socket.
- **Retry only** 429/5xx/network failures, max 2 retries. 4xx is terminal
  (exactly one call — an OTP already sent is never re-sent).
- **Circuit breaker** per provider: opens after 5 consecutive failures,
  half-opens after 30s cooldown. Open circuits fail fast with
  `circuit open for provider 'x'`.
- **Idempotency key** per OTP/NIK request, sent as the `idempotency-key`
  header on every attempt.
- **Fallbacks** (the user never hangs):
  - email fails → outbox/retry (`mailer.js` best-effort + outbox worker),
    never a signup rollback;
  - telegram fails → free SMS (`sendOtpWithFallback` in `phone.js`) →
    manual review;
  - Nusakit fails (any mode incl. circuit open) → local structural result
    with `remote: 'fallback (...)'`;
  - OCR confidence < 0.85 → manual review.

## Test harness (PR-088)

No test touches a real provider. Two layers:

- **JS chaos tests** (`middleware/test/integrations/`): injected `fetchImpl`
  for timeout/429/500/malformed/down, breaker, idempotency, fallback.
- **Shell harness** (`tests/integration/provider_fallback.sh`, auto-run by
  `run_all.sh full`): real adapters over real sockets against
  `tests/lib/fake_provider.mjs` (Telegram/free-SMS/Nusakit shapes with
  per-service chaos modes + a request journal). Scenarios: telegram ok,
  500→SMS fallback within retry budget, 400 single-call, NIK
  timeout/malformed/down→local. Self-cleaning (trap kills the fake; asserts
  no residue).
- **Email** goes through Mailpit (`email_otp_flow.sh`; CI provides the
  service, `REQUIRE_MAILPIT=1` enforces it).
- **Rule:** every endpoint in tests is `127.0.0.1` — the harness asserts this
  before running. `TELEGRAM_API_BASE` exists only as a test seam; production
  uses the real Bot API.

`INTEGRATION_MODE=test` was considered and skipped: the harness runs on the
existing `free` mode with localhost endpoints, so no config dimension was
added for tests alone.

## Metrics

- `integration_requests_total{provider,result}` (`ok`|`error`) + the
  `integration_request_duration_ms` latency histogram.
- `integration_fallback_total{provider,reason}` on every fallback hop.
- `integration_circuit_open{provider}` gauge (1 while the breaker is open).
