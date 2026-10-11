# Spec: api-gateway

Status: **built** — a Node.js/Express middleware exposes the COBOL core over HTTP.
Last verified against code: 2026-10-10

## Objective (unchanged)

The "Robust Pipe": the only interface between the public internet and COBOL. It secures, transports, and translates — it implements no business rules.

## As-Built (what exists today)

- **Source:** `middleware/` (Node.js + Express). Transport in `middleware/src/invoker.js`, result/HTTP mapping in `middleware/src/result.js`, whitelist validation in `middleware/src/validation.js`, JWT in `middleware/src/auth.js`, routes in `middleware/src/app.js`, entry point `middleware/src/server.js`.
- **Invocation model:** each request runs the binary as its own process in a unique temp working directory containing that request's `input.txt`; the result is read from `output.txt` and the directory removed (ADR-0001). Binary path from `COBOL_BIN`, defaulting to `../../cobol/bin/main_logic`.
- **No business logic in JS**: the gateway only validates, invokes, and maps the COBOL result line.

### Endpoints

| Method | Path | COBOL action | Auth |
|---|---|---|---|
| GET | `/health` | — | public |
| POST | `/auth/refresh` | — (transport only) | public |
| POST | `/auth/signup` | `REQUEST_SIGNUP` | public |
| POST | `/auth/verify` | `VERIFY_EMAIL` | public |
| POST | `/auth/login` | `AUTH_LOGIN` (issues a JWT) | public |
| GET | `/users` | `LIST_USERS` (optional `limit`/`offset` query) | bearer |
| GET | `/users/:email` | `GET_USER` | bearer |
| GET | `/wallet/balance` | `CHECK_BALANCE` | bearer |
| POST | `/wallet/transfer` | `TRANSFER` (optional `Idempotency-Key` header) | bearer |
| GET | `/profile` | `GET_DASHBOARD` | bearer |
| POST | `/profile/email/request` | `REQ_EMAIL_CHANGE` | bearer |
| POST | `/profile/email/confirm` | `CONFIRM_EMAIL_CHANGE` | bearer |
| GET | `/admin/role` | `CHECK_ROLE` | bearer |
| POST | `/admin/role` | `CHANGE_ROLE` | bearer |

### Result to HTTP mapping

- COBOL `SUCCESS|…` → `200 { "data": [...] }`.
- COBOL `ERROR|<code>|…` → status by code: `INVALID_CREDENTIALS` 401; `UNVERIFIED`/`FORBIDDEN`/`ROLE_DENIED` 403; `ACCOUNT_NOT_FOUND`/`TARGET_NOT_FOUND`/`NOT_FOUND` 404; `MISSING_ACTION`/`INVALID_ACTION`/`INVALID_CODE`/`WEAK_PASSWORD`/`EMAIL_EXISTS`/`INVALID_ROLE`/`INVALID_AMOUNT`/`CURRENCY_MISMATCH` 400; `INSUFFICIENT_FUNDS`/`TRANSFER_IN_PROGRESS` 409; DB/`*_FAILED`/`DB_ERROR` 500. Body `{ "error": code, "detail": [...] }`.
- `POST /wallet/transfer` forwards an `Idempotency-Key` header as the transfer's idempotency key, so a retried request is not applied twice.
- Validation failure → `400 { "error": "INVALID_PARAMETER" }`; an input line longer than the COBOL record is rejected before invocation; a hung binary → `504 { "error": "GATEWAY_TIMEOUT" }`; a client over the auth rate limit → `429 { "error": "RATE_LIMITED" }`.

### Auth and limits

- Login returns a short-lived **access token** (`JWT_SECRET`/`JWT_EXPIRES_IN`, default 15m) and a **refresh token** (`REFRESH_SECRET`/`REFRESH_EXPIRES_IN`, default 7d); `POST /auth/refresh` exchanges a refresh token for a new access token.
- `/auth/*` endpoints are rate limited (fixed window per client: `RATE_LIMIT_WINDOW_MS`, `RATE_LIMIT_MAX`).
- The composed input line is capped at the COBOL record size (see `CODING_STANDARDS.md` rule 13).

### Tests

`middleware/test/gateway.test.js` (health, injection rejection, missing token, end-to-end signup→verify→login→authorized call, wrong-password 401) and `middleware/test/invoker.timeout.test.js` (hung process → timeout). Run by `ci.sh` step 12 via `npm --prefix middleware test`.

## Configuration

`middleware/.env` (see `middleware/.env.example`): `PORT`, `JWT_SECRET`, `JWT_EXPIRES_IN`, `COBOL_BIN`.

## Not yet done

- Refresh-token rotation/revocation (a refresh token is accepted until it expires; there is no server-side denylist).
- Parameter binding in COBOL is string interpolation, not prepared statements.
