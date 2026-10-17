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
| GET | `/health` | `PING` (deep: DB reachability) | public |
| POST | `/auth/refresh` | — (transport only; rotates the refresh token) | public |
| POST | `/auth/step-up` | `VERIFY_REAUTH` (re-authenticate; mints a short-lived step-up proof) | bearer |
| POST | `/auth/logout` | — (transport only; per-device: removes the refresh session and, when the bearer is sent, denies that access token) | public |

Every response carries `X-Cobol-Ms`, the COBOL call latency in milliseconds.
| POST | `/auth/signup` | `REQUEST_SIGNUP` | public |
| POST | `/auth/verify` | `VERIFY_EMAIL` | public |
| POST | `/auth/login` | `AUTH_LOGIN` (issues a JWT) | public |
| GET | `/users` | `LIST_USERS` (optional `limit`/`offset` query) | bearer |
| GET | `/users/:email` | `GET_USER` | bearer |
| GET | `/wallet/balance` | `CHECK_BALANCE` | bearer |
| GET | `/statements` | `STATEMENT` (`email`, `currency`, optional `range`=`from,to`, `limit`/`offset`) | bearer (owner or admin) |
| POST | `/wallet/transfer` | `TRANSFER` (optional `Idempotency-Key` header) | bearer |
| GET | `/profile` | `GET_DASHBOARD` | bearer |
| POST | `/profile/email/request` | `REQ_EMAIL_CHANGE` | bearer |
| POST | `/profile/email/confirm` | `CONFIRM_EMAIL_CHANGE` | bearer |
| GET | `/admin/role` | `CHECK_ROLE` | bearer |
| POST | `/admin/role` | `CHANGE_ROLE` | bearer |
| POST | `/admin/user-status` | `SET_USER_STATUS` | bearer |
| GET | `/admin/audit` | `LIST_AUDIT` (optional `action`/`email`/`limit`/`offset`) | bearer (SUPER_ADMIN) |
| POST | `/admin/audit/archive` | `ARCHIVE_AUDIT` (`days` ≥ 1) | bearer (SUPER_ADMIN) |
| POST | `/admin/unlock` | `UNLOCK_USER` (clear a lockout) | bearer (admin) |
| POST | `/admin/mfa-reset` | `ADMIN_RESET_MFA` (clear a user's MFA) | bearer (admin) |
| POST | `/admin/holds` | `PLACE_HOLD` (amount, optional `days`/`currency`/`reason`) | bearer (SUPER_ADMIN) + step-up |
| POST | `/admin/holds/release` | `RELEASE_HOLD` (`holdId`) | bearer (SUPER_ADMIN) + step-up |
| POST | `/mfa/backup-codes` | `MFA_BACKUP_CODES` (shown once; each works in place of TOTP) | bearer (owner) |
| POST | `/mfa/recover` | `REQUEST_MFA_RECOVERY` (neutral) | public |
| POST | `/mfa/recover/confirm` | `VERIFY_MFA_RECOVERY` | public |
| POST | `/admin/mfa-recovery/approve` | `APPROVE_MFA_RECOVERY` (`requestId`) | bearer (SUPER_ADMIN) + step-up |
| POST | `/admin/mfa-recovery/reject` | `REJECT_MFA_RECOVERY` (`requestId`) | bearer (SUPER_ADMIN) + step-up |
| GET | `/admin/mfa-recovery` | `LIST_MFA_RECOVERY` (optional `status`/`limit`/`offset`) | bearer (SUPER_ADMIN) |
| POST | `/admin/requests` | `REQUEST_OPERATION` (`operation`/`target`/`detail`) | bearer (SUPER_ADMIN) + step-up |
| POST | `/admin/requests/approve` | `APPROVE_REQUEST` (`requestId`) | bearer (SUPER_ADMIN) + step-up |
| POST | `/admin/requests/reject` | `REJECT_REQUEST` (`requestId`) | bearer (SUPER_ADMIN) + step-up |
| GET | `/admin/requests` | `LIST_REQUESTS` (optional `status`/`limit`/`offset`) | bearer (SUPER_ADMIN) |
| GET | `/admin/reconcile` | `RECONCILE` (read-only diagnostic) | bearer (SUPER_ADMIN) |
| POST | `/admin/reconcile/run` | `RUN_RECONCILIATION` (optional `trigger`) | bearer (SUPER_ADMIN) + step-up |
| GET | `/admin/reconcile/runs` | `LIST_RECONCILIATIONS` (optional `limit`/`offset`) | bearer (SUPER_ADMIN) |
| GET | `/admin/reconcile/exceptions` | `LIST_EXCEPTIONS` (optional `status`/`limit`/`offset`) | bearer (SUPER_ADMIN) |
| POST | `/admin/reconcile/acknowledge` | `ACK_EXCEPTION` (`findingId`) | bearer (SUPER_ADMIN) + step-up |
| POST | `/admin/reconcile/resolve` | `RESOLVE_EXCEPTION` (`findingId`, optional `note`) | bearer (SUPER_ADMIN) + step-up |
| GET | `/admin/outbox` | `LIST_OUTBOX` (optional `status`/`limit`/`offset`; never exposes codes) | bearer (SUPER_ADMIN) |
| GET | `/metrics` | — (Prometheus counters) | bearer (SUPER_ADMIN) |

### Result to HTTP mapping

- COBOL `SUCCESS|…` → `200 { "data": [...] }`.
- COBOL `ERROR|<code>|…` → status by code: `INVALID_CREDENTIALS` 401; `UNVERIFIED`/`FORBIDDEN`/`ROLE_DENIED` 403; `ACCOUNT_NOT_FOUND`/`TARGET_NOT_FOUND`/`NOT_FOUND` 404; `MISSING_ACTION`/`INVALID_ACTION`/`INVALID_CODE`/`WEAK_PASSWORD`/`EMAIL_EXISTS`/`INVALID_ROLE`/`INVALID_AMOUNT`/`CURRENCY_MISMATCH`/`INVALID_INPUT` 400; `INSUFFICIENT_FUNDS`/`TRANSFER_IN_PROGRESS` 409; DB/`*_FAILED`/`DB_ERROR` 500. Body `{ "error": code, "detail": [...] }`.
- `POST /wallet/transfer` forwards an `Idempotency-Key` header as the transfer's idempotency key, so a retried request is not applied twice.
- Validation failure → `400 { "error": "INVALID_PARAMETER" }`; an input line longer than the COBOL record is rejected before invocation; a hung binary → `504 { "error": "GATEWAY_TIMEOUT" }`; a client over the auth rate limit → `429 { "error": "RATE_LIMITED" }`.

### Auth and limits

- Login returns a short-lived **access token** (`JWT_SECRET`/`JWT_EXPIRES_IN`, default 15m) and a **refresh token** (`REFRESH_SECRET`/`REFRESH_EXPIRES_IN`, default 7d) carrying a `jti`. The `jti` is stored via the COBOL `STORE_SESSION` action along with the client **user-agent and IP**; `POST /auth/refresh` atomically consumes it (`CONSUME_SESSION`, which reports reuse), **rotates** it (new jti in the same family), and `POST /auth/logout` removes it per-device (`REVOKE_SESSION`) and denies the presented access token; `POST /sessions/revoke-all` logs out everywhere. The access token carries a `sid` (its refresh-session family), and `GET /sessions` marks the caller's own session (`current`) alongside each session's user-agent and IP. The login/refresh response also carries `mfaEnrollmentRequired: true` when the account is a SUPER_ADMIN/MANAGER without MFA, prompting enrolment.
- `/auth/*` endpoints are rate limited (fixed window per client: `RATE_LIMIT_WINDOW_MS`, `RATE_LIMIT_MAX`).
- The composed input line is capped at the COBOL record size (see `CODING_STANDARDS.md` rule 13).

### Tests

`middleware/test/gateway.test.js` (health, injection rejection, missing token, end-to-end signup→verify→login→authorized call, wrong-password 401) and `middleware/test/invoker.timeout.test.js` (hung process → timeout). Run by `ci.sh` step 12 via `npm --prefix middleware test`.

## Configuration

`middleware/.env` (see `middleware/.env.example`): `PORT`, `JWT_SECRET`, `JWT_EXPIRES_IN`, `COBOL_BIN`. In production the server refuses to start unless `JWT_SECRET` and `REFRESH_SECRET` are at least 32 characters and differ from each other and from the development defaults (see ADR 0011). Tokens are signed and verified with HMAC-SHA256 only.

## Not yet done

- The bridge supports prepared statements (`SQL_PREPARE_EXEC`, string parameters) and value escaping (`SQL_ESCAPE`); the migration of every query to prepared statements is incremental.
