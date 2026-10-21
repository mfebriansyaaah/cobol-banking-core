# STATUS.md - Current state of the project

Snapshot of the running system as of 2026-10-21. Every factual claim here is
verifiable: suite counts by running `./ci.sh`, action names by grepping
`cobol/src/`, and the cross-references by `tests/status_check.sh` (wired into
`ci.sh`).

## 1. What this is

A banking core where **all business logic lives in COBOL**:
- `cobol/bin/main_logic` - one binary that reads a single pipe-delimited
  request line from `input.txt` and writes one result line to `output.txt`
  (`ACTION|param1|param2|param3|param4`), relative to its working directory.
- `middleware/` - a Node.js/Express **API gateway** that is the only HTTP
  interface; it validates input shapes, invokes the binary per request in a
  unique working directory, and maps the result line to HTTP (ADR-0001). The
  binary also has a long-running `--serve` mode (stdin/stdout protocol) that a
  **worker pool** uses when COBOL_POOL_SIZE is set (ADR-0010, phase 3); file
  mode stays the default.
- MySQL database `cobol_db`; the binary talks to it through the C bridge
  `cobol/src/sql_bridge.c` (libmysqlclient - the ODBC stack was retired, ADR-0002).
- `./ci.sh` - one-shot verification: docs integrity, static COBOL checks
  (period-in-IF, GOBACK placement, router prefix collisions, router/owner
  agreement, `users(email)` FK cascade, gateway action coverage), build, the
  shell suites (functional, transactional, security, prepared-statement,
  migration), the API-gateway node suite, the C/COBOL buffer contract
  (`docs/BUFFER_CONTRACT.md`, enforced by `tests/buffer_contract_check.sh`),
  and an end-to-end HTTP smoke against a
  live gateway. Must exit 0 with `ALL GREEN`.

## 2. Modules and actions (current behavior)

| Module | Action | Params | Behavior | Outputs |
|---|---|---|---|---|
| `cobol/src/wallet_core.cob` | `CHECK_BALANCE` | email, actor (self-or-admin) | every account as `iso:balance:available:status` rows (multi-account; available = `accounts.balance` minus live `account_holds`) | `SUCCESS\|BALANCES\|<iso>:<balance>:<available>:<status>[;...]` * `ERROR\|ACCOUNT_NOT_FOUND` * `ERROR\|FORBIDDEN` |
| `cobol/src/wallet_core.cob` | `TRANSFER` | from (token identity), target, amount, **idempotency key** (required by the gateway; scoped per sender), fromCurrency/toCurrency (opt) | one transaction: sender **and** target accounts must be `ACTIVE` and both currencies enabled, else rejected; a multi-currency sender/recipient must pin `fromCurrency`/`toCurrency` (else `ERROR\|AMBIGUOUS_ACCOUNT`); optional per-transaction and rolling 24h debit caps (env); replay only when sender/target/amount match the committed key (unique per sender); `FOR UPDATE` lock; debit sender, credit target (`amount * rate` when currencies differ); opens one `journal_entries` row (source `TRANSFER`, actor = sender); 2 `ledger` rows (tagged with the sender, linked to the journal); pre-commit balanced-leg verification (exact agreement through the rate, either direction); `audit_trail` (row records `to:amount:currency` in `detail`, linked to the journal); intent `COMMITTED` | `SUCCESS\|TRANSFER_OK` * `ERROR\|ACCOUNT_NOT_FOUND` * `ERROR\|TARGET_NOT_FOUND` * `ERROR\|ACCOUNT_FROZEN` * `ERROR\|ACCOUNT_CLOSED` * `ERROR\|CURRENCY_INACTIVE` * `ERROR\|AMBIGUOUS_ACCOUNT` * `ERROR\|INSUFFICIENT_FUNDS` * `ERROR\|LIMIT_EXCEEDED` * `ERROR\|DAILY_LIMIT_EXCEEDED` * `ERROR\|TRANSFER_IN_PROGRESS` * `ERROR\|IDEMPOTENCY_CONFLICT` * `ERROR\|INVALID_AMOUNT` * `ERROR\|RATE_NOT_FOUND` * `ERROR\|RATE_STALE` * `ERROR\|SELF_TRANSFER` * `ERROR\|DB_ERROR` * `ERROR\|DB_BUSY` |
| `cobol/src/wallet_core.cob` | `RECONCILE` | actor (SUPER_ADMIN) | lists accounts where `accounts.balance <> SUM(ledger)` | `SUCCESS\|RECONCILED` * `ERROR\|MISMATCH\|...` * `ERROR\|FORBIDDEN` |
| `cobol/src/wallet_core.cob` | `RUN_RECONCILIATION` | actor (SUPER_ADMIN), trigger (MANUAL/SCHEDULED) | computes the balance-vs-ledger outcome, inserts one immutable run row plus one OPEN finding per mismatch, reports the run id | `SUCCESS\|RUN_RECORDED\|<id>\|<n>` * `ERROR\|FORBIDDEN` * `ERROR\|INVALID_INPUT` * `ERROR\|DB_ERROR` |
| `cobol/src/wallet_core.cob` | `LIST_RECONCILIATIONS` | actor (SUPER_ADMIN), limit, offset | paged recorded runs, newest first | `SUCCESS\|RUNS\|<total>[\|<rows>]` * `ERROR\|FORBIDDEN` * `ERROR\|INVALID_INPUT` |
| `cobol/src/wallet_core.cob` | `LIST_EXCEPTIONS` | actor (SUPER_ADMIN), status filter, limit, offset | paged findings with owner, note, and run link | `SUCCESS\|EXCEPTIONS\|<total>[\|<rows>]` * `ERROR\|FORBIDDEN` * `ERROR\|INVALID_INPUT` |
| `cobol/src/wallet_core.cob` | `ACK_EXCEPTION` | finding_id, actor (SUPER_ADMIN) | OPEN becomes ACKNOWLEDGED with the actor as owner | `SUCCESS\|EXCEPTION_ACKNOWLEDGED` * `ERROR\|FORBIDDEN` * `ERROR\|INVALID_INPUT` * `ERROR\|UNKNOWN_TRANSACTION` * `ERROR\|DB_ERROR` |
| `cobol/src/wallet_core.cob` | `RESOLVE_EXCEPTION` | finding_id, actor (SUPER_ADMIN), note (opt) | closes an ACKNOWLEDGED finding, keeping its run link | `SUCCESS\|EXCEPTION_RESOLVED` * `ERROR\|FORBIDDEN` * `ERROR\|INVALID_INPUT` * `ERROR\|UNKNOWN_TRANSACTION` * `ERROR\|DB_ERROR` |
| `cobol/src/wallet_core.cob` | `REVERSE_TRANSFER` | ref, actor (SUPER_ADMIN), sender (opt) | one-time compensating reversal: credit the original sender, debit the target (must still hold the credited funds); the `sender` scopes the transfer when the ref is shared (else `AMBIGUOUS_TRANSACTION`); writes 2 opposite `ledger` rows (3 with an FX residual mirror leg, rate snapshotted, linked to the new journal), a `transfer_reversals` marker (keyed per ref+sender), its own `journal_entries` row (source `REVERSAL`), a linked audit row, and the same pre-commit balanced-leg verification | `SUCCESS\|TRANSFER_REVERSED` * `ERROR\|FORBIDDEN` * `ERROR\|UNKNOWN_TRANSACTION` * `ERROR\|AMBIGUOUS_TRANSACTION` * `ERROR\|ALREADY_REVERSED` * `ERROR\|INSUFFICIENT_FUNDS` * `ERROR\|REVERSAL_FAILED` |
| `cobol/src/wallet_core.cob` | `PLACE_HOLD` | email, amount, actor (SUPER_ADMIN), days (opt), currency pin (opt), reason (opt) | locks part of an account's balance (`PLACED`, lazy expiry + explicit release, audited with actor) | `SUCCESS\|HOLD_PLACED\|<id>` * `ERROR\|FORBIDDEN` * `ERROR\|ACCOUNT_NOT_FOUND` * `ERROR\|AMBIGUOUS_ACCOUNT` * `ERROR\|ACCOUNT_CLOSED` * `ERROR\|CURRENCY_INACTIVE` * `ERROR\|INVALID_AMOUNT` * `ERROR\|INVALID_INPUT` * `ERROR\|INSUFFICIENT_FUNDS` * `ERROR\|DB_ERROR` |
| `cobol/src/wallet_core.cob` | `RELEASE_HOLD` | hold_id, actor (SUPER_ADMIN) | releases a `PLACED` hold (audited with actor) | `SUCCESS\|HOLD_RELEASED` * `ERROR\|FORBIDDEN` * `ERROR\|INVALID_INPUT` * `ERROR\|UNKNOWN_TRANSACTION` * `ERROR\|DB_ERROR` |
| `cobol/src/wallet_core.cob` | `TX_STATUS` | ref, actor (owner or admin), sender (optional, admin) | reports a transfer's status (`COMMITTED`/`PENDING`/`REVERSED`) and parties, with the amount formatted at the sender currency's own precision (ledger DEBIT leg, or the sender's single account currency while pending); an admin may target a sender and the unfiltered result is the newest by id | `SUCCESS\|TRANSFER\|<status>\|<from>\|<to>\|<amount>` * `ERROR\|UNKNOWN_TRANSACTION` |
| `cobol/src/wallet_core.cob` | `STATEMENT` | email, actor (owner or admin), currency, `from,to` range, limit, offset | read-only per-account statement: opening/closing balances plus one row per posting, oldest first (posting/value dates, ref, source, side, amount, balance after the row, reversal flag, description); journal-less legacy rows render as `TRANSFER` with value date = posting date | `SUCCESS\\|STATEMENT\\|<open>\\|<close>\\|<iso>\\|<total>[\\|<rows>]` * `ERROR\\|FORBIDDEN` * `ERROR\\|INVALID_INPUT` * `ERROR\\|ACCOUNT_NOT_FOUND` * `ERROR\\|DB_ERROR` |
| `cobol/src/wallet_core.cob` | `OPEN_DISPUTE` | email, actor (must be the owner), subject, detail, txn_ref (optional, must be owner's own) | opens a ticket; unknown users, foreign refs rejected | `SUCCESS\\|DISPUTE_OPENED\\|<id>` * `ERROR\\|FORBIDDEN` * `ERROR\\|INVALID_INPUT` * `ERROR\\|ACCOUNT_NOT_FOUND` * `ERROR\\|UNKNOWN_TRANSACTION` * `ERROR\\|DB_ERROR` |
| `cobol/src/wallet_core.cob` | `ADD_DISPUTE_NOTE` | case_id, actor (owner or SUPER_ADMIN), note | appends to immutable history; terminal cases refuse notes | `SUCCESS\\|DISPUTE_NOTED` * `ERROR\\|FORBIDDEN` * `ERROR\\|INVALID_INPUT` * `ERROR\\|UNKNOWN_TRANSACTION` * `ERROR\\|INVALID_STATUS` * `ERROR\\|DB_ERROR` |
| `cobol/src/wallet_core.cob` | `ACK_DISPUTE` | case_id, actor (SUPER_ADMIN), due date (optional) | claims ownership: OPEN only; sets assignee + due date | `SUCCESS\\|DISPUTE_ACKNOWLEDGED` * `ERROR\\|FORBIDDEN` * `ERROR\\|INVALID_INPUT` * `ERROR\\|UNKNOWN_TRANSACTION` * `ERROR\\|INVALID_STATUS` * `ERROR\\|DB_ERROR` |
| `cobol/src/wallet_core.cob` | `RESOLVE_DISPUTE` | case_id, actor (SUPER_ADMIN), resolution | resolves an ACKNOWLEDGED case with reason | `SUCCESS\\|DISPUTE_RESOLVED` * same errors as ack |
| `cobol/src/wallet_core.cob` | `REJECT_DISPUTE` | case_id, actor (SUPER_ADMIN), reason | refuses an OPEN/ACKNOWLEDGED case | `SUCCESS\\|DISPUTE_REJECTED` * same errors as ack |
| `cobol/src/wallet_core.cob` | `LIST_DISPUTES` | actor, email filter (admin), status filter, limit, offset | paged queue, non-admins pinned to own; overdue flag from due date | `SUCCESS\\|DISPUTES\\|<total>[\\|<rows>]` * `ERROR\\|FORBIDDEN` * `ERROR\\|INVALID_INPUT` * `ERROR\\|DB_ERROR` |
| `cobol/src/wallet_core.cob` | `GET_DISPUTE` | case_id, actor (owner or SUPER_ADMIN) | case plus append-only notes, oldest first | `SUCCESS\\|DISPUTE\\|<case>\\|<count>[\\|<notes>]` * `ERROR\\|FORBIDDEN` * `ERROR\\|INVALID_INPUT` * `ERROR\\|UNKNOWN_TRANSACTION` * `ERROR\\|DB_ERROR` |
| `cobol/src/user_core.cob` | `GET_USER` | email, actor (self-or-admin) | full record: id, email, name, status, role, created | `SUCCESS\|USER\|<id>\|<email>\|<name>\|<status>\|<role>\|<created>` * `ERROR\|NOT_FOUND` * `ERROR\|FORBIDDEN` |
| `cobol/src/user_core.cob` | `LIST_USERS` | limit(20, gateway caps 1..100), offset(0), actor (admin), role filter (opt) | paged with a total; rows `id:email:name:role:status`; optional role filter | `SUCCESS\|LIST_DONE\|<total>\|<rows>` * `ERROR\|FORBIDDEN` |
| `cobol/src/user_core.cob` | `GET_DASHBOARD` | email, actor (self-or-admin) | full profile (email, name, status, role, dob, created) + **all** accounts as `iso:balance:available:status` at the currency's own precision (same projection as `CHECK_BALANCE`); `LEFT JOIN` so users without accounts still get a profile | `SUCCESS\|DASHBOARD\|<email>\|<name>\|<status>\|<role>\|<dob>\|<created>\|<accounts>` * `ERROR\|ACCOUNT_NOT_FOUND` * `ERROR\|FORBIDDEN` |
| `cobol/src/user_core.cob` | `REQ_EMAIL_CHANGE` | current, new, actor (owner), password | validates both emails, then **re-auth** (password) and **neutral** about the new address: a 6-digit code is stored only when it is free; a taken address returns the same success with no code | `SUCCESS\|CODE_SENT\|<code>` (free) * `SUCCESS\|CODE_SENT` (taken) * `ERROR\|ACCOUNT_NOT_FOUND` * `ERROR\|INVALID_CREDENTIALS` * `ERROR\|INVALID_INPUT` * `ERROR\|EMAIL_CHANGE_FAILED` * `ERROR\|FORBIDDEN` |
| `cobol/src/user_core.cob` | `CONFIRM_EMAIL_CHANGE` | current, new, code, actor (owner) | validates emails; consume code, move email, **bump `token_version` + revoke all refresh sessions** (clean re-login), audit; **attempt-capped** (burned after 5 wrong guesses); a new address taken in the meantime is `EMAIL_EXISTS` | `SUCCESS\|EMAIL_CHANGED` * `ERROR\|INVALID_CODE` * `ERROR\|EMAIL_EXISTS` * `ERROR\|INVALID_INPUT` * `ERROR\|EMAIL_CHANGE_FAILED` * `ERROR\|FORBIDDEN` |
| `cobol/src/user_core.cob` | `UPDATE_PROFILE` | email, name, actor (owner), dob (opt) | owner-only self-service; validates the email and (when given) the date of birth, then updates `full_name`/`dob` in a transaction with an audit row; blank name is `INVALID_INPUT` | `SUCCESS\|PROFILE_UPDATED` * `ERROR\|FORBIDDEN` * `ERROR\|ACCOUNT_NOT_FOUND` * `ERROR\|INVALID_INPUT` * `ERROR\|PROFILE_UPDATE_FAILED` |
| `cobol/src/user_core.cob` | `DEACTIVATE_ACCOUNT` | email, actor (owner) | owner-only soft-close: sets `status='CLOSED'`, bumps `token_version` and revokes refresh sessions, audited; **refuses when it is the last active SUPER_ADMIN** (`ERROR\|LAST_ADMIN`) | `SUCCESS\|ACCOUNT_DEACTIVATED` * `ERROR\|FORBIDDEN` * `ERROR\|ACCOUNT_NOT_FOUND` * `ERROR\|LAST_ADMIN` * `ERROR\|DEACTIVATE_FAILED` |
| `cobol/src/user_core.cob` | `SET_USER_STATUS` | email, status, actor (admin) | admin sets `UNVERIFIED`/`VERIFIED`/`SUSPENDED`/`CLOSED`; **role hierarchy**: the actor may not be lower-ranked than the target (a MANAGER cannot touch a SUPER_ADMIN; equal ranks are allowed); **refuses to disable the last active SUPER_ADMIN** (`ERROR\|LAST_ADMIN`); bumps `token_version` and revokes refresh sessions, audited (subject + actor) | `SUCCESS\|STATUS_CHANGED` * `ERROR\|FORBIDDEN` * `ERROR\|ACCOUNT_NOT_FOUND` * `ERROR\|INVALID_STATUS` * `ERROR\|LAST_ADMIN` * `ERROR\|STATUS_CHANGE_FAILED` |
| `cobol/src/user_core.cob` | `UNLOCK_USER` | email, actor (admin not lower-ranked) | clears a lockout (`failed_logins`/`locked_until`) so a locked user can log in again; audited (subject + actor) | `SUCCESS\|ACCOUNT_UNLOCKED` * `ERROR\|FORBIDDEN` * `ERROR\|ACCOUNT_NOT_FOUND` * `ERROR\|INVALID_INPUT` * `ERROR\|UNLOCK_FAILED` |
| `cobol/src/user_core.cob` | `ADMIN_RESET_MFA` | email, actor (admin not lower-ranked) | clears a user's MFA (`mfa_enabled`/`mfa_secret`) so they can re-enroll after losing a device; audited (subject + actor) | `SUCCESS\|MFA_RESET` * `ERROR\|FORBIDDEN` * `ERROR\|ACCOUNT_NOT_FOUND` * `ERROR\|INVALID_INPUT` * `ERROR\|MFA_RESET_FAILED` |
| `cobol/src/auth_core.cob` | `REQUEST_SIGNUP` | email, password, name, dob | 8-char min password, PBKDF2 hash, 6-digit code in `verification_logs`; audit row; **neutral** when the email is already registered (no account-existence leak) | `SUCCESS\|USER_CREATED\|<code>` (or `SUCCESS\|USER_CREATED` if already registered) * `ERROR\|WEAK_PASSWORD` * `ERROR\|PASSWORD_BLOCKED` * `ERROR\|SIGNUP_FAILED` |
| `cobol/src/auth_core.cob` | `VERIFY_EMAIL` | email, code | consume code, set `VERIFIED`, transactional; **attempt-capped** (code burned after 5 wrong guesses); audit success or (attributable) failure | `SUCCESS\|EMAIL_VERIFIED` * `ERROR\|INVALID_CODE` * `ERROR\|VERIFY_FAILED` |
| `cobol/src/auth_core.cob` | `RESEND_VERIFICATION` | email | reissues a fresh `SIGNUP` code only for an existing `UNVERIFIED` account (neutral otherwise) | `SUCCESS\|CODE_SENT\|<code>` (or `SUCCESS\|CODE_SENT` unknown/verified) * `ERROR\|RESEND_FAILED` |
| `cobol/src/auth_core.cob` | `MFA_ENROLL_REQUIRED` | email | decides whether the account must enrol MFA: `1` for SUPER_ADMIN/MANAGER without MFA, else `0` — the gateway forwards the flag and must not reimplement the admin-role rule | `SUCCESS|1` * `SUCCESS|0` * `ERROR|ACCOUNT_NOT_FOUND` |
| `cobol/src/auth_core.cob` | `VERIFY_REAUTH` | email, password, mfaCode (opt) | re-verify the caller's own credentials for a step-up: password check (PBKDF2/legacy) and, when MFA is on, a valid TOTP; **admin accounts (SUPER_ADMIN/MANAGER) must have MFA enabled** or step-up is refused; no tokens issued, no lockout change | `SUCCESS\|REAUTH_OK` * `ERROR\|INVALID_CREDENTIALS` * `ERROR\|MFA_REQUIRED` * `ERROR\|MFA_SETUP_REQUIRED` * `ERROR\|INVALID_MFA` |
| `cobol/src/auth_core.cob` | `AUTH_LOGIN` | email, password, mfaCode (opt) | 3-fail/15-min lockout tracked on the user row (failed_logins/locked_until) and **masked**: a wrong password stays `INVALID_CREDENTIALS` whether or not the account exists or is locked, only a correct password reveals `ACCOUNT_LOCKED`; PBKDF2 verify w/ legacy SHA256 fallback; **rehash on login** when the stored hash is legacy or below the current cost; when **MFA** is on a valid `mfaCode` (p3) is also required and a bad code is throttled like a bad password; must be `VERIFIED` (a `SUSPENDED`/`CLOSED` account is refused with `USER_SUSPENDED`/`USER_CLOSED`); unknown account returns the same `INVALID_CREDENTIALS` (anti-enumeration, dummy KDF for timing) | `SUCCESS\|LOGIN_OK` * `ERROR\|INVALID_CREDENTIALS` * `ERROR\|UNVERIFIED` * `ERROR\|USER_SUSPENDED` * `ERROR\|USER_CLOSED` * `ERROR\|ACCOUNT_LOCKED` * `ERROR\|MFA_REQUIRED` * `ERROR\|INVALID_MFA` |
| `cobol/src/auth_core.cob` | `MFA_ENROLL_BEGIN` | email, actor (owner) | issues a pending base32 TOTP secret (shown once); rejected if MFA is already on | `SUCCESS\|MFA_SECRET\|<secret>` * `ERROR\|FORBIDDEN` * `ERROR\|ACCOUNT_NOT_FOUND` * `ERROR\|MFA_ALREADY_ENABLED` * `ERROR\|MFA_ENROLL_FAILED` |
| `cobol/src/auth_core.cob` | `MFA_ENROLL_CONFIRM` | email, code, actor (owner) | verifies a TOTP code against the pending secret, then turns MFA on | `SUCCESS\|MFA_ENABLED` * `ERROR\|INVALID_MFA` * `ERROR\|FORBIDDEN` * `ERROR\|ACCOUNT_NOT_FOUND` * `ERROR\|MFA_ENROLL_FAILED` |
| `cobol/src/auth_core.cob` | `MFA_DISABLE` | email, code, actor (owner) | verifies a TOTP code, then clears the secret and turns MFA off | `SUCCESS\|MFA_DISABLED` * `ERROR\|INVALID_MFA` * `ERROR\|MFA_NOT_ENABLED` * `ERROR\|FORBIDDEN` * `ERROR\|ACCOUNT_NOT_FOUND` * `ERROR\|MFA_DISABLE_FAILED` |
| `cobol/src/auth_core.cob` | `MFA_BACKUP_CODES` | email, actor (owner); MFA must be on | issues 8 single-use 10-digit backup codes, hashed at rest, shown once; replaces any previous set | `SUCCESS\|BACKUP_CODES\|<c1,...>` * `ERROR\|FORBIDDEN` * `ERROR\|ACCOUNT_NOT_FOUND` * `ERROR\|MFA_NOT_ENABLED` * `ERROR\|DB_ERROR` |
| `cobol/src/auth_core.cob` | `REQUEST_MFA_RECOVERY` | email, password (unauthenticated, neutral) | re-proofing part one; queues a recovery code when the account exists and the password matches | `SUCCESS\|CODE_SENT` * `ERROR\|DB_ERROR` |
| `cobol/src/auth_core.cob` | `VERIFY_MFA_RECOVERY` | email, code (unauthenticated) | re-proofing part two; marks the newest PENDING request VERIFIED | `SUCCESS\|RECOVERY_VERIFIED` * `ERROR\|INVALID_CODE` * `ERROR\|DB_ERROR` |
| `cobol/src/auth_core.cob` | `APPROVE_MFA_RECOVERY` | request_id, actor (SUPER_ADMIN, never the requester) | clears MFA and backup codes, burns the code, notifies, audits | `SUCCESS\|RECOVERY_APPROVED` * `ERROR\|FORBIDDEN` * `ERROR\|INVALID_INPUT` * `ERROR\|UNKNOWN_TRANSACTION` * `ERROR\|DB_ERROR` |
| `cobol/src/auth_core.cob` | `REJECT_MFA_RECOVERY` | request_id, actor (SUPER_ADMIN) | marks a PENDING/VERIFIED request REJECTED | `SUCCESS\|RECOVERY_REJECTED` * `ERROR\|FORBIDDEN` * `ERROR\|INVALID_INPUT` * `ERROR\|UNKNOWN_TRANSACTION` * `ERROR\|DB_ERROR` |
| `cobol/src/auth_core.cob` | `LIST_MFA_RECOVERY` | actor (SUPER_ADMIN), status filter, limit, offset | paged recovery requests, newest first | `SUCCESS\|RECOVERY_REQUESTS\|<total>[\|<rows>]` * `ERROR\|FORBIDDEN` * `ERROR\|INVALID_INPUT` |
| `cobol/src/auth_core.cob` | `FORGOT_PASSWORD` | email | issues a `PASSWORD_RESET` code only when the account exists (neutral otherwise) | `SUCCESS\|CODE_SENT\|<code>` (or `SUCCESS\|CODE_SENT` unknown) * `ERROR\|RESET_FAILED` |
| `cobol/src/auth_core.cob` | `RESET_PASSWORD` | email, code, new password | consume code, set PBKDF2 hash, bump `token_version` (revoke sessions), audit; **attempt-capped** (burned after 5 wrong guesses) | `SUCCESS\|PASSWORD_RESET` * `ERROR\|INVALID_CODE` * `ERROR\|WEAK_PASSWORD` * `ERROR\|PASSWORD_BLOCKED` * `ERROR\|PASSWORD_REUSED` * `ERROR\|RESET_FAILED` |
| `cobol/src/auth_core.cob` | `CHANGE_PASSWORD` | email, current, new, actor (self) | verify current password, set new hash, bump `token_version`, audit | `SUCCESS\|PASSWORD_CHANGED` * `ERROR\|INVALID_CREDENTIALS` * `ERROR\|WEAK_PASSWORD` * `ERROR\|PASSWORD_BLOCKED` * `ERROR\|PASSWORD_REUSED` * `ERROR\|FORBIDDEN` * `ERROR\|PASSWORD_CHANGE_FAILED` |
| `cobol/src/auth_core.cob` | `CHECK_ROLE` | email, role, actor (self-or-admin) | does the user hold the role | `SUCCESS\|ROLE_OK` * `ERROR\|ROLE_DENIED` * `ERROR\|ACCOUNT_NOT_FOUND` * `ERROR\|FORBIDDEN` |
| `cobol/src/auth_core.cob` | `CHANGE_ROLE` | target, role, actor(actor must be SUPER_ADMIN) | transactional update; **refuses to demote the last active SUPER_ADMIN** (`ERROR\|LAST_ADMIN`); audit row **attributed to the actor** (entity_id = target) | `SUCCESS\|ROLE_CHANGED` * `ERROR\|FORBIDDEN` * `ERROR\|INVALID_ROLE` * `ERROR\|ACCOUNT_NOT_FOUND` * `ERROR\|LAST_ADMIN` * `ERROR\|ROLE_CHANGE_FAILED` |
| `cobol/src/auth_core.cob` | `REQUEST_OPERATION` | operation, target, detail, maker (maker must be SUPER_ADMIN; operation must be designated and executable) | opens a PENDING maker request | `SUCCESS\|REQUEST_PLACED\|<id>` * `ERROR\|INVALID_INPUT` * `ERROR\|FORBIDDEN` * `ERROR\|ACCOUNT_NOT_FOUND` * `ERROR\|INVALID_ROLE` * `ERROR\|DB_ERROR` |
| `cobol/src/auth_core.cob` | `APPROVE_REQUEST` | request_id, checker (SUPER_ADMIN, never the maker) | re-validates everything and executes the effect in the same transaction; self-approval is forbidden | `SUCCESS\|REQUEST_APPROVED` * `ERROR\|FORBIDDEN` * `ERROR\|INVALID_INPUT` * `ERROR\|UNKNOWN_TRANSACTION` * `ERROR\|ACCOUNT_NOT_FOUND` * `ERROR\|INVALID_ROLE` * `ERROR\|LAST_ADMIN` * `ERROR\|DB_ERROR` |
| `cobol/src/auth_core.cob` | `REJECT_REQUEST` | request_id, checker (SUPER_ADMIN, never the maker) | PENDING becomes REJECTED | `SUCCESS\|REQUEST_REJECTED` * `ERROR\|FORBIDDEN` * `ERROR\|INVALID_INPUT` * `ERROR\|UNKNOWN_TRANSACTION` * `ERROR\|DB_ERROR` |
| `cobol/src/auth_core.cob` | `LIST_REQUESTS` | actor (SUPER_ADMIN), status filter, limit, offset | paged maker requests, newest first | `SUCCESS\|REQUESTS\|<total>[\|<rows>]` * `ERROR\|FORBIDDEN` * `ERROR\|INVALID_INPUT` |
| `cobol/src/auth_core.cob` | `ARCHIVE_AUDIT` | retention days, actor (SUPER_ADMIN) | move audit rows older than the window to `audit_trail_archive`; retention must be **≥ 1 day** (0 is refused); **audited** (actor) | `SUCCESS\|ARCHIVED` * `ERROR\|FORBIDDEN` * `ERROR\|INVALID_INPUT` * `ERROR\|AUDIT_ARCHIVE_FAILED` |
| `cobol/src/auth_core.cob` | `LIST_AUDIT` | actor (SUPER_ADMIN), action (opt), email (opt), limit (50), offset (0) | read the audit trail as `id:created:action:subject:actor:entity_type:entity_id:status:detail;...` with a total; action/email filters and paging | `SUCCESS\|AUDIT\|<total>\|<rows>` * `ERROR\|FORBIDDEN` |
| `cobol/src/auth_core.cob` | `OUTBOX_CLAIM` | max rows, worker id | reaps stale claims and hands due rows to one worker | `SUCCESS\|CLAIMED` * `ERROR\|INVALID_INPUT` * `ERROR\|DB_ERROR` |
| `cobol/src/auth_core.cob` | `OUTBOX_MARK` | id, SENT|FAILED, error, worker id | records the delivery outcome; past the attempt budget the row goes dead-letter | `SUCCESS\|MARKED\|<SENT\|FAILED\|DEAD>` * `ERROR\|INVALID_INPUT` * `ERROR\|UNKNOWN_TRANSACTION` * `ERROR\|DB_ERROR` |
| `cobol/src/auth_core.cob` | `LIST_OUTBOX` | actor (SUPER_ADMIN), status filter, limit, offset | paged outbox rows without codes or message bodies | `SUCCESS\|OUTBOX\|<total>[\|<rows>]` * `ERROR\|FORBIDDEN` * `ERROR\|INVALID_INPUT` |
| `cobol/src/auth_core.cob` | `STORE_SESSION` | jti, email, days | record a refresh-token session | `SUCCESS\|SESSION_STORED` * `ERROR\|SESSION_STORE_FAILED` |
| `cobol/src/auth_core.cob` | `REVOKE_SESSION` | jti | remove one refresh session (per-device logout) | `SUCCESS\|SESSION_REVOKED` * `ERROR\|SESSION_REVOKE_FAILED` |
| `cobol/src/auth_core.cob` | `LIST_SESSIONS` | email, actor (self-or-admin), sid | active (unrevoked, unexpired) refresh sessions as `jti:created:expires:user-agent:ip:current;...` (`current` marks the caller's own family) | `SUCCESS\|SESSIONS\|...` * `ERROR\|FORBIDDEN` * `ERROR\|SESSION_LIST_FAILED` |
| `cobol/src/auth_core.cob` | `REVOKE_USER_SESSION` | email, actor, session id | revoke one session that belongs to the account (self, or an admin not lower-ranked); **audited** (subject + actor) | `SUCCESS\|SESSION_REVOKED` * `ERROR\|SESSION_NOT_FOUND` * `ERROR\|FORBIDDEN` * `ERROR\|SESSION_REVOKE_FAILED` |
| `cobol/src/auth_core.cob` | `REVOKE_ALL_SESSIONS` | email, actor (self, or an admin not lower-ranked) | bump `token_version` **and** revoke every refresh session (logout everywhere); **audited** (subject + actor) | `SUCCESS\|SESSIONS_REVOKED` * `ERROR\|FORBIDDEN` * `ERROR\|SESSIONS_REVOKE_FAILED` |
| `cobol/src/auth_core.cob` | `CONSUME_SESSION` | jti | **atomic** rotate: consume (revoke) the session in one conditional update and enforce the family's absolute lifetime / rotation cap; a replay is reuse — kills the family, bumps `token_version` and audits | `SUCCESS\|SESSION_CONSUMED` * `ERROR\|SESSION_REUSED` * `ERROR\|SESSION_NOT_FOUND` * `ERROR\|SESSION_EXPIRED` * `ERROR\|SESSION_FAMILY_EXPIRED` |
| `cobol/src/auth_core.cob` | `GET_TOKEN_VERSION` | email | current access-token version for a user | `SUCCESS\|<ver>` * `ERROR\|ACCOUNT_NOT_FOUND` |
| `cobol/src/auth_core.cob` | `CHECK_TOKEN` | email, version, jti | access token is current and not denylisted | `SUCCESS\|TOKEN_VALID` * `ERROR\|TOKEN_REVOKED` * `ERROR\|ACCOUNT_NOT_FOUND` |
| `cobol/src/auth_core.cob` | `REVOKE_ACCESS_TOKEN` | jti, email, ttl seconds | deny one access token until it would expire | `SUCCESS\|TOKEN_REVOKED` * `ERROR\|TOKEN_REVOKE_FAILED` |
| `cobol/src/auth_core.cob` | `OPEN_ACCESS_REVIEW` | actor (SUPER_ADMIN), period start, period end | opens an access review: snapshots every `MANAGER`/`SUPER_ADMIN` account with its role, status, MFA state, and last sign-in; only one review may be open at a time; audited | `SUCCESS\|REVIEW_OPENED\|<id>\|<items>` * `ERROR\|FORBIDDEN` * `ERROR\|INVALID_INPUT` * `ERROR\|REVIEW_ALREADY_OPEN` * `ERROR\|DB_ERROR` |
| `cobol/src/auth_core.cob` | `LIST_ACCESS_REVIEWS` | actor (SUPER_ADMIN), state filter, limit, offset | paged reviews, newest first | `SUCCESS\|REVIEWS\|<total>[\|<rows>]` * `ERROR\|FORBIDDEN` * `ERROR\|INVALID_INPUT` |
| `cobol/src/auth_core.cob` | `GET_ACCESS_REVIEW` | actor (SUPER_ADMIN), review id | the review and its items as they stand now (item rows separated by `;`, their fields by `:`) | `SUCCESS\|REVIEW\|<id>\|<start>\|<end>\|<state>\|<opened_by>\|<closed_by>\|<closed_at>\|<items>` * `ERROR\|FORBIDDEN` * `ERROR\|INVALID_INPUT` * `ERROR\|UNKNOWN_TRANSACTION` |
| `cobol/src/auth_core.cob` | `DECIDE_ACCESS_ITEM` | actor (SUPER_ADMIN), item id, decision (`ATTESTED`/`REVOKED`), note (opt) | records a decision on one privileged account; **the reviewer is never the subject** (self-attestation is refused and audited); a closed review and an already-decided item are refused; audited | `SUCCESS\|ITEM_DECIDED\|<item>\|<decision>` * `ERROR\|FORBIDDEN` * `ERROR\|INVALID_INPUT` * `ERROR\|INVALID_STATUS` * `ERROR\|UNKNOWN_TRANSACTION` * `ERROR\|DB_ERROR` |
| `cobol/src/auth_core.cob` | `CLOSE_ACCESS_REVIEW` | actor (SUPER_ADMIN), review id | closes the review: refused while any item is undecided (`REVIEW_INCOMPLETE`) and while a revoked subject still holds a privileged role in a verified state (`REVOCATION_PENDING`); the removal itself goes through the ordinary privileged actions, so it keeps the rank check, the last-admin guard, and the maker-checker designation; audited | `SUCCESS\|REVIEW_CLOSED\|<id>` * `ERROR\|FORBIDDEN` * `ERROR\|INVALID_INPUT` * `ERROR\|INVALID_STATUS` * `ERROR\|REVIEW_INCOMPLETE` * `ERROR\|REVOCATION_PENDING` * `ERROR\|UNKNOWN_TRANSACTION` * `ERROR\|DB_ERROR` |
| `cobol/src/auth_core.cob` | `REVOKE_OTHER_DEVICES` | email, actor (self or an admin not lower-ranked), presented family | revokes every refresh session of the account except the caller's own family; other devices fail on their next refresh or request; audited (`SESSIONS_REVOKED_OTHERS`) | `SUCCESS\|OTHER_SESSIONS_REVOKED` * `ERROR\|FORBIDDEN` * `ERROR\|INVALID_INPUT` * `ERROR\|SESSIONS_REVOKE_FAILED` |
| `cobol/src/auth_core.cob` | `LOGIN_NOTICE` | email, user agent, ip | records the sign-in fingerprint in `known_devices`; the first sighting enqueues a `NEW_DEVICE` notice in the outbox (no code, IP only); repeats do not | `SUCCESS\|NOTICE_RECORDED` * `ERROR\|ACCOUNT_NOT_FOUND` * `ERROR\|DB_ERROR` |
| `cobol/src/user_core.cob` | `MARK_DORMANT` | actor (SUPER_ADMIN) | flags accounts whose last sign-in is older than `DORMANT_AFTER_DAYS` and queues a `DORMANT_NOTICE`; never changes the status; SUPER_ADMINs excluded | `SUCCESS\|DORMANT_NOTIFIED\|<count>` * `ERROR\|FORBIDDEN` * `ERROR\|POLICY_DISABLED` * `ERROR\|DB_ERROR` |
| `cobol/src/user_core.cob` | `SUSPEND_DORMANT` | actor (SUPER_ADMIN) | suspends accounts flagged at least `DORMANT_GRACE_DAYS` ago that still have no newer sign-in; revokes sessions; audited | `SUCCESS\|DORMANT_SUSPENDED\|<count>` * `ERROR\|FORBIDDEN` * `ERROR\|POLICY_DISABLED` * `ERROR\|DB_ERROR` |
| `cobol/src/user_core.cob` | `REACTIVATE_DORMANT` | email, actor (SUPER_ADMIN) | clears a dormant suspension and the flag; refuses a non-suspended account | `SUCCESS\|DORMANT_REACTIVATED` * `ERROR\|FORBIDDEN` * `ERROR\|INVALID_INPUT` * `ERROR\|ACCOUNT_NOT_FOUND` * `ERROR\|INVALID_STATUS` * `ERROR\|DB_ERROR` |
| `cobol/src/auth_core.cob` | `STEP_UP_REQUIRED` | email, action, amount (opt) | answers whether the owner-controlled `step_up_policy` requires a fresh step-up proof for this action at this amount | `SUCCESS\|STEP_UP_REQUIRED` * `SUCCESS\|STEP_UP_NOT_REQUIRED` * `ERROR\|ACCOUNT_NOT_FOUND` * `ERROR\|DB_ERROR` |
| `cobol/src/auth_core.cob` | `CHECK_PERMISSION` | email, permission | answers whether the account holds the permission; the gateway renders the answer and the `ALLOW-PERMISSION` helper enforces it | `SUCCESS\|PERMISSION_OK` * `ERROR\|PERMISSION_DENIED` * `ERROR\|INVALID_INPUT` * `ERROR\|ACCOUNT_NOT_FOUND` * `ERROR\|DB_ERROR` |
| `cobol/src/auth_core.cob` | `LIST_PERMISSIONS` | email | lists every permission the account holds, for the login and profile responses | `SUCCESS\|PERMISSIONS\|[<perm>[;...]]` * `ERROR\|ACCOUNT_NOT_FOUND` * `ERROR\|DB_ERROR` |
| `cobol/src/auth_core.cob` | `PING` | - | deep health: DB reachability | `SUCCESS\|PONG` * `ERROR\|DB_DOWN` * `ERROR\|DB_CONFIG_INSECURE` |

The routing contract is that every action dispatched by `cobol/src/main_logic.cob`
is handled by its owning module; `ci.sh` verifies every routed
action has a handler in its owning module.

## 2a. Generated reference-data module (frozen volume artifact)

The October 2026 volume sprint added 211 generated reference entities; after
the cutovers, 206 entities and 1,030 actions remain in
`cobol/src/generated/ref_core.cob`, with a uniform
`code/label/num_val/is_active` contract. They are produced by
`scripts/gen_entity.mjs` and exercised by 206 smoke suites (2,266 assertions)
run through `scripts/ci-7d.sh`. The measured split is 17.224 curated
net COBOL and 52.134 generated net COBOL (24,8% curated).

This module is a **frozen generated artifact**. It is not a PRD requirement,
not a curated production data model, and not part of the merge gate. The production-grade
transition replaces it with a generic reference-data model; see
`docs/PRODUCTION_GRADE_PLAN.md` and
`docs/adr/0081-production-grade-transition.md`. Do not add another generated
`ref_*` table or copy the generator into production scope.

## 2b. Reference-data engine (Phase 1)

The generic engine replaces per-entity generated CRUD with a type/value/version
model: effective dating, approval, translations, hierarchy, and audit. The
generated reference module stays in place until each domain is cut over.

Country, holiday, fee_code, limit_type, and product_type are cut over: their
data lives in the engine and is served by
`/reference-engine/values?type=<domain>`. The legacy tables remain as a
read-only safety copy for one release.

| Module | Action | Behavior |
|---|---|---|
| `cobol/src/ref_engine.cob` | `RFE_TYPE_LIST` | paged reference types |
| `cobol/src/ref_engine.cob` | `RFE_TYPE_CREATE` | create a type (admin) |
| `cobol/src/ref_engine.cob` | `RFE_VALUE_LIST` | paged values for a type, latest version |
| `cobol/src/ref_engine.cob` | `RFE_VALUE_CREATE` | create a value and DRAFT version 1 |
| `cobol/src/ref_engine.cob` | `RFE_VALUE_GET` | latest version for a type/code |
| `cobol/src/ref_engine.cob` | `RFE_VALUE_APPROVE` | DRAFT -> ACTIVE; retire the previous active version |
| `cobol/src/ref_engine.cob` | `RFE_VALUE_RETIRE` | ACTIVE -> RETIRED with effective end date |
| `cobol/src/ref_engine.cob` | `RFE_VALUE_HIST` | version history for a type/code |

## 2c. General ledger (Phase 1)

| Module | Action | Behavior |
|---|---|---|
| `cobol/src/gl_core.cob` | `GL_ACCOUNT_LIST` | paged chart of accounts |
| `cobol/src/gl_core.cob` | `GL_ACCOUNT_CREATE` | create a GL account with type and normal side |
| `cobol/src/gl_core.cob` | `GL_JOURNAL_POST` | one balanced debit/credit journal in a currency |
| `cobol/src/gl_core.cob` | `GL_JOURNAL_POST_ML` | balanced multi-line journal (2-10 lines) in an open period |
| `cobol/src/gl_core.cob` | `GL_PERIOD_OPEN` | open a YYYY-MM accounting period |
| `cobol/src/gl_core.cob` | `GL_PERIOD_CLOSE` | close an open period and record the closer |
| `cobol/src/gl_core.cob` | `GL_PERIOD_LIST` | paged period status list |
| `cobol/src/gl_core.cob` | `GL_TRIAL_BALANCE` | debit/credit totals and per-account rows for a date range |

## 2d. Batch/EOD foundation (Phase 1)

| Module | Action | Behavior |
|---|---|---|
| `cobol/src/batch_core.cob` | `BATCH_JOB_CREATE` | create a scheduled job with type, frequency, retries, and timeout |
| `cobol/src/batch_core.cob` | `BATCH_JOB_LIST` | paged job list with optional type/enabled filters |
| `cobol/src/batch_core.cob` | `BATCH_JOB_UPDATE` | update enablement, frequency, schedule, and retry count |
| `cobol/src/batch_core.cob` | `BATCH_STEP_CREATE` | add an ordered, required/optional step to a job |
| `cobol/src/batch_core.cob` | `BATCH_STEP_LIST` | paged step list for a job |
| `cobol/src/batch_core.cob` | `BATCH_RUN_START` | start a run; one active run per job/business date; copies steps |
| `cobol/src/batch_core.cob` | `BATCH_RUN_STATUS` | run summary with optional step and control-total detail |
| `cobol/src/batch_core.cob` | `BATCH_RUN_LIST` | paged run list with status/job/date filters |
| `cobol/src/batch_core.cob` | `BATCH_RUN_CHECKPOINT` | save checkpoint, processed count, and balanced control totals |
| `cobol/src/batch_core.cob` | `BATCH_RUN_COMPLETE` | complete a run only when required steps and control totals pass |
| `cobol/src/batch_core.cob` | `BATCH_RUN_FAIL` | fail a running run with a coded reason |
| `cobol/src/batch_core.cob` | `BATCH_RUN_RETRY` | create the next attempt from the failed run's checkpoint |
| `cobol/src/batch_core.cob` | `BATCH_RUN_STEP` | enforce step state transitions and record step totals |
| `cobol/src/batch_core.cob` | `BATCH_CONTROL_TOTAL` | upsert expected/actual totals and record MATCH/VARIANCE |
| `cobol/src/batch_core.cob` | `BATCH_EOD_START` | start an EOD-type job for a non-future business date |

## 2e. Report engine (Phase 1)

| Module | Action | Behavior |
|---|---|---|
| `cobol/src/report_core.cob` | `RPT_TEMPLATE_CREATE` | create a report template with type, output format, and title |
| `cobol/src/report_core.cob` | `RPT_TEMPLATE_LIST` | paged template list with type/enabled filters |
| `cobol/src/report_core.cob` | `RPT_TEMPLATE_GET` | template summary with optional ordered columns |
| `cobol/src/report_core.cob` | `RPT_COLUMN_CREATE` | add an ordered column with width, align, and data format |
| `cobol/src/report_core.cob` | `RPT_COLUMN_LIST` | paged columns for a template |
| `cobol/src/report_core.cob` | `RPT_RUN_START` | start a run for an enabled template with at least one column |
| `cobol/src/report_core.cob` | `RPT_RUN_ROW` | append an ordinal row with debit/credit and formatted data |
| `cobol/src/report_core.cob` | `RPT_RUN_STATUS` | run summary with optional rows |
| `cobol/src/report_core.cob` | `RPT_RUN_COMPLETE` | complete only when stored row count and debit/credit totals match |
| `cobol/src/report_core.cob` | `RPT_RUN_FAIL` | fail a running report with a coded reason |
| `cobol/src/report_core.cob` | `RPT_RUN_LIST` | paged runs with status/template filters |
| `cobol/src/report_core.cob` | `RPT_RUN_EXPORT` | export a completed run as CSV/FIXED header and row data |
| `cobol/src/report_core.cob` | `RPT_TEMPLATE_UPDATE` | update template enablement, format, and title |
| `cobol/src/report_core.cob` | `RPT_TEMPLATE_CLONE` | clone a template and all ordered columns |
| `cobol/src/report_core.cob` | `RPT_TEMPLATE_DELETE` | delete a template only when it has no runs |
| `cobol/src/report_core.cob` | `RPT_COLUMN_UPDATE` | update a column header, source, width, align, and format |
| `cobol/src/report_core.cob` | `RPT_COLUMN_DELETE` | delete an ordered column |
| `cobol/src/report_core.cob` | `RPT_RUN_RETRY` | start a new run from a failed run's template/parameters |
| `cobol/src/report_core.cob` | `RPT_RUN_GENERATE` | populate a trial-balance run from posted GL journals |
| `cobol/src/report_core.cob` | `RPT_RUN_DELETE` | delete a failed run and its rows |

## 2f. Import/export foundation (Phase 1)

| Module | Action | Behavior |
|---|---|---|
| `cobol/src/import_core.cob` | `IMP_BATCH_CREATE` | create a staged import batch with a source and type |
| `cobol/src/import_core.cob` | `IMP_BATCH_LIST` | paged batches with status/type filters |
| `cobol/src/import_core.cob` | `IMP_BATCH_GET` | batch summary with optional rows |
| `cobol/src/import_core.cob` | `IMP_ROW_STAGE` | stage one raw row under a batch |
| `cobol/src/import_core.cob` | `IMP_BATCH_VALIDATE` | validate every row and record VALID/INVALID with error detail |
| `cobol/src/import_core.cob` | `IMP_ROW_CORRECT` | replace an invalid row and reset the batch to STAGED |
| `cobol/src/import_core.cob` | `IMP_ERROR_LIST` | paged invalid rows with error code/detail |
| `cobol/src/import_core.cob` | `IMP_BATCH_POST` | post a fully valid batch and mark rows POSTED |
| `cobol/src/import_core.cob` | `IMP_BATCH_FAIL` | fail a batch with a coded reason |
| `cobol/src/import_core.cob` | `IMP_BATCH_EXPORT` | export batch rows as CSV/FIXED data |
| `cobol/src/import_core.cob` | `IMP_BATCH_STAGE_BULK` | stage up to four semicolon-separated chunks in one call |
| `cobol/src/import_core.cob` | `IMP_BATCH_CLONE` | clone a batch definition and its rows into a new code |
| `cobol/src/import_core.cob` | `IMP_BATCH_RETRY` | reset a failed batch to STAGED |
| `cobol/src/import_core.cob` | `IMP_ROW_SKIP` | skip a validated row and recompute counts |
| `cobol/src/import_core.cob` | `IMP_ROW_UNSKIP` | reset a skipped row to STAGED |
| `cobol/src/import_core.cob` | `IMP_BATCH_DELETE` | delete a STAGED/FAILED batch and its rows |
| `cobol/src/import_core.cob` | `IMP_BATCH_SUMMARY` | row-status counts for a batch |

## 3. Database (`cobol_db`)

Tables in `database/schema.sql` (evolves via `database/migrations/`):
`users` (with `token_version` and `last_login_at`) * `currencies` * `accounts` * `ledger` (with `from_email`) * `ledger_archive` *
`verification_logs` (incl. `MFA_RECOVERY` purpose) * `journal_entries` * `audit_trail` (subject `user_id` + `actor_id`, posting `journal_id`) * `audit_trail_archive` * `pending_transactions` * `pending_transactions_archive` * `transfer_reversals` (ref + sender) * `account_holds` (state machine) * `fee_schedule` (per-currency flat fee) * `reconciliation_runs` (immutable) * `reconciliation_findings` (ownership lifecycle) * `dual_control_operations` (designation) * `maker_requests` (PENDING/APPROVED/REJECTED) * `notification_outbox` (PENDING/SENDING/SENT/FAILED/DEAD) * `refresh_sessions` (jti + `family` + user-agent/ip + `last_seen_at`) * `refresh_families` (absolute lifetime + `rotations`) * `access_reviews` (OPEN/CLOSED, period, opener/closer) * `access_review_items` (snapshot of a privileged account: role, status, MFA state, last sign-in, decision, reviewer) * `permissions` (capability catalog) * `role_permissions` (role to permission grants, seeded to the current behavior) * `password_history` (last N hashes, bounded) * `password_blocklist` (owner-controlled common-password deny list, SHA-256 keyed) * `step_up_policy` (action, minimum amount, enabled) * `users.dormant_notified_at` (pending dormant warning) * `known_devices` (durable sign-in fingerprint; no credential) * `exchange_rates` * `revoked_access_tokens` * `schema_migrations` * `mfa_backup_codes` (hashed, single-use) * `mfa_recovery_requests` (PENDING/VERIFIED/APPROVED/REJECTED) * `dispute_cases` (OPEN/ACKNOWLEDGED/RESOLVED/REJECTED) * `dispute_messages` (append-only) * `batch_job`/`batch_job_step` (definitions) * `batch_run`/`batch_run_step` (checkpointed runs) * `batch_control_total` (expected/actual/variance) * `batch_audit` * `report_template`/`report_template_column` * `report_run`/`report_run_row` * `report_audit` * `import_batch`/`import_row` * `import_audit`
(transfer intents, `PENDING`->`COMMITTED`, cascaded on user delete -
`database/migrations/0001_*.sql`).

The bridge reads its connection from the environment
(`DB_HOST`/`DB_PORT`/`DB_USER`/`DB_PASS`/`DB_NAME`, with development
defaults); no credentials are compiled into the source. The gateway passes its
own environment (see `middleware/.env.example`) to the binary it spawns.
In production the runtime account is **DML-only** (SELECT/INSERT/UPDATE/DELETE)
so a bug cannot DROP/ALTER tables; `database/grants.sh` provisions that account
plus a separate privileged migration account (`database/migrate.sh` runs under
DB_MIGRATE_USER/DB_MIGRATE_PASS, defaulting to the app credentials).

Migrations applied by `database/migrate.sh` (a failure aborts naming the file and records nothing, so a retry resumes there) and tracked in `schema_migrations`; `database/migrate.sh --check` verifies none are pending. `database/schema.sql` is the fresh-install baseline: it folds every migration to date and pre-records them, so a new database only ever runs newer migrations (adding a migration means folding its objects into `schema.sql` and extending the baseline list — enforced by `tests/test_migrate.sh`). Seed data: `database/seed_test_data.sql` (re-runnable: fixture rows are kept when present, ledger seed rows reset by key). Full policy: `docs/SCHEMA_POLICY.md` (source of truth, fold-then-extend rule, never re-run `schema.sql` live, dev-only seeds, benign column-order drift).

## 4. Test suites (all green under `./ci.sh`)

| Suite | Count | Covers |
|---|---:|---|
| `tests/test_suite.sh` | 16 | functional surface (actions, defaults, idempotent replay error mapping) |
| `tests/test_atomic_txn.sh` | 5 | atomic transfer contract (file-based I/O) |
| `tests/test_ledger_atomic.sh` | 17 | atomicity: ledger rows, rollback on every failure path, audit row |
| `tests/test_reconciliation.sh` | 10 | `RECONCILE` on healthy/drifted states; SUPER_ADMIN actor gate |
| `tests/test_auth_login.sh` | 6 | login, legacy rehash on login |
| `tests/test_signup_verify.sh` | 27 | signup + verify flow, PBKDF2 hash, neutral duplicate email, audit, expired-log pruning, resend verification |
| `tests/test_roles.sh` | 17 | `CHECK_ROLE` self-or-admin, `CHANGE_ROLE` SUPER_ADMIN gate, `ARCHIVE_AUDIT` |
| `tests/test_user_profile.sh` | 42 | full profile (incl. account-less), rich user record + paged listing with role filter, update profile, email-change (validation + race) |
| `tests/test_account_lifecycle.sh` | 15 | self deactivation, admin status changes, login honours SUSPENDED/CLOSED, side-effect revocation |
| `tests/test_login_lockout.sh` | 14 | 3-fail/15-min lockout on the user row, masked probe (wrong stays uniform, owner told), reset/good-login unlock |
| `tests/test_idempotent_transfer.sh` | 27 | replay-no-op, key reuse conflict, per-sender scoping, unique auto refs, failure retry, archived key runs fresh |
| `tests/test_transfer_validity.sh` | 59 | positive-amount, malformed-amount rejection (core-level), self-transfer, cross-currency (direct + inverse rate + missing + stale rate `RATE_STALE` + D1 residual to `FX_PNL`), target precision, rate snapshot, multi-account selection by currency + ambiguity (`AMBIGUOUS_ACCOUNT`) |
| `tests/test_wallet_observability.sh` | 7 | TRANSFER audit context (target:amount:currency, actor), idempotency-intent retention (stale archived, fresh kept) |
| `tests/test_transfer_limits.sh` | 27 | per-transaction cap (boundary + over) and rolling 24h cap, rejected transfers move nothing; integer/1dp amounts in major units, dotted cap fails closed, IDR (prec 0) and 3-decimal boundaries |
| `tests/test_transfer_reversal.sh` | 77 | admin-only one-time reversal (compensating entries, balances restored, audit names the sender), required reason (`INVALID_INPUT` when missing/unknown), status owner/admin-only, admin sender filter/determinism, shared-ref reversal requires the sender (`AMBIGUOUS_TRANSACTION`), ALREADY_REVERSED, insufficient claw-back, fee refund by reason (BANK_ERROR refunds via its own verified `FEE` journal, CUSTOMER_ERROR retains, reason recorded), FX residual unwound atomically (mirrored gain/loss legs, balanced-leg verified, underfunded clawback refused) |
| `tests/test_ledger_integrity.sh` | 4 | ledger is append-only (UPDATE refused), a negative amount is refused, and deleting an account preserves its ledger rows in `ledger_archive` |
| `tests/test_account_status.sh` | 13 | transfer needs ACTIVE sender/target and enabled currencies; failures move nothing; frozen balance still readable |
| `tests/test_injection.sh` | 11 | auth values escaped (accepted literally); user/wallet still whitelist-only; bridge diagnostics carry no email addresses |
| `tests/test_session.sh` | 18 | STORE/CHECK/REVOKE_SESSION, reuse detection, pruning, token-version + per-token revocation |
| `tests/test_sessions_manage.sh` | 19 | list active sessions (user-agent + IP, current session marked), revoke one (owner/admin, own only), revoke-all (version bump + all refresh revoked, audited) |
| `tests/test_token_rotation.sh` | 20 | atomic consume (first wins), replay reuse kills family + bumps version + audits, unknown/expired, family absolute lifetime + rotation cap (`SESSION_FAMILY_EXPIRED` + audit), denylist pruning on store |
| `tests/test_admin_hierarchy.sh` | 12 | role hierarchy: a MANAGER cannot suspend/close/verify a SUPER_ADMIN nor revoke its sessions; equal/higher ranks allowed; self-service unaffected |
| `tests/test_last_admin.sh` | 13 | last-admin protection: cannot demote/suspend/close/unverify or self-deactivate the final active SUPER_ADMIN; allowed once a second super exists |
| `tests/test_audit_actor.sh` | 10 | audit attribution: admin-on-other actions record subject + `actor_id`; `REVOKE_USER_SESSION` is audited; `ARCHIVE_AUDIT` self-audited; archive preserves `actor_id`; self-service leaves it NULL |
| `tests/test_audit_read.sh` | 9 | `LIST_AUDIT` SUPER_ADMIN-only, action/email filters, limit/offset paging with a stable total, zero-day retention refused |
| `tests/test_audit_integrity.sh` | 12 | refused attempts audited (`AUTHZ_DENIED` in auth/user/**wallet**, unknown actor unattributed), `action`/`actor_id` indexes, audit rows are append-only (UPDATE refused), user-delete preserves evidence in the archive |
| `tests/test_admin_recovery.sh` | 11 | `UNLOCK_USER` clears a lockout and `ADMIN_RESET_MFA` clears MFA, admin + rank gated, audited (subject + actor) |
| `tests/test_stepup.sh` | 10 | `VERIFY_REAUTH` (step-up): correct/wrong password, unknown/suspended account, **admin without MFA refused (`MFA_SETUP_REQUIRED`)**, MFA required/bad/good code |
| `tests/test_mfa_state.sh` | 5 | `MFA_ENROLL_REQUIRED` decision table (admin without MFA must enrol, others exempt) |
| `tests/test_prepared.sh` | 15 | signup/login/transfer/reconcile (`SQL_PREPARE_EXEC`), locking read (`SQL_PREPARE_EXEC_LOCK`) and list (`SQL_PREPARE_EXEC_ROWS`) through prepared statements |
| `tests/test_ping.sh` | 7 | deep-health PING reaches the DB; connection settings come from the environment; production refuses development DB credentials and a missing password with `DB_CONFIG_INSECURE`; explicit credentials reach the DB; development keeps the local defaults |
| `tests/test_migrate.sh` | 28 | migration runner idempotent; the replay loop uses `migrate.sh --only <version>` (one file per iteration instead of a full scan); --check detects pending; dead columns/table gone; baseline lists every file; FX index present; no orphan records; failures abort naming the file and record nothing; every statement statically guarded for re-run; a half-applied scratch migration converges; every recorded migration re-applies cleanly; the documented non-replayable ones (ENUM narrowing, AUTO_INCREMENT PK rewrites) fail loudly without corrupting |
| `tests/test_concurrent_transfer.sh` | 4 | opposing concurrent transfers all succeed, money conserved |
| `tests/test_e2e_gateway.sh` | 22 | live-gateway HTTP flow: signup→verify→login→transfer→refresh→metrics→logout; `/wallet/balance` envelope + currency |
| `tests/test_serve_mode.sh` | 12 | long-running `--serve`, file mode unchanged, connection lifecycle (reconnect + transaction) |
| `tests/test_password.sh` | 14 | forgot/reset/change password (code single-use, sessions revoked, owner-only) |
| `tests/test_verify_cap.sh` | 10 | verification attempt cap for SIGNUP, PASSWORD_RESET and EMAIL_CHANGE (below cap, burn at cap, fresh code, single active code) |
| `tests/test_journal.sh` | 30 | journal header per posting (source/actor/value date), legs and audit linked, balanced DEBIT/CREDIT per journal incl. cross-currency rate agreement, kill -9 mid-posting rolls back and the key retries |
| `tests/test_holds.sh` | 32 | hold lifecycle (place/release/expire/ambiguity/closed/precision), available-balance enforcement, lazy expiry, per-currency scheduled fees as separate journals, scoped reconciliation |
| `tests/test_reconciliation_runs.sh` | 32 | recorded runs (clean/mismatch, scheduled trigger, immutability), exception ownership and strict resolution, lists, scripts (scheduler with divergence alert + CSV export) |
| `tests/test_dual_control.sh` | 29 | maker-checker: designation-gated CHANGE_ROLE, no self-approval, re-validation and last-admin at approve time, reject flow, bypass refusal, undesignate restores direct use |
| `tests/test_mfa_recovery.sh` | 38 | single-use hashed backup codes (generate/login/consume/regen/clear), assisted recovery with re-proofing, verified-only approval, reject flow, no self-approval, scoped list |
| `tests/test_outbox.sh` | 23 | transactional enqueue on signup/resend/forgot/email-change, worker dispatch with retries, dead-letter after budget, stale-claim reaping, redaction, list view without codes |
| `tests/test_statements.sh` | 29 | read-only statements: opening/closing from immutable ledger, per-posting rows with balance-after and reversal flags, fee legs, date ranges, paging, owner-or-admin visibility |
| `tests/test_disputes.sh` | 39 | ticket lifecycle: owner-only open with owned-ref check, owner/admin notes, admin ack with due date, verified-only resolve, reject paths, owner-pinned and filtered queues, overdue flags, append-only history |
| `tests/test_backup_restore.sh` | 15 | backup round-trip: manifest (git rev, counts, checksums), restore verification, canary rewind, migration check, bridge smoke |
| `tests/test_resend_cooldown.sh` | 7 | per-account resend cooldown for SIGNUP and PASSWORD_RESET (immediate re-request reuses the pending code neutrally, zero disables and reissues) |
| `tests/test_seed.sh` | 6 | seed fixtures are re-runnable (users/accounts kept, ledger seed rows reset, balances unchanged) |
| `tests/test_password_kdf.sh` | 8 | PBKDF2 cost configurable + modern default, legacy SHA256 upgrade, rehash-on-login for under-cost PBKDF2, no needless rehash |
| `tests/test_mfa.sh` | 20 | TOTP enrol/confirm/login/disable, MFA required and enforced, owner-only, bad codes rejected and counted toward the per-account lockout |
| `tests/test_rng.sh` | 5 | fail-closed OS CSPRNG helper builds clean and returns fresh, non-zero bytes; MFA secrets and password salts are fresh per call |
| `tests/test_grants.sh` | 5 | least-privilege guardrail (no DB): app grant is DML-only with no DDL, migration grant is full DDL, the two accounts differ, migrations use a separate credential |
| `tests/test_control_accounts.sh` | 13 | bank-owned FX_PNL/FEE_INCOME uniqueness: generated slot maps exactly the ACTIVE lookup predicate, duplicate ACTIVE rows refused per type, INACTIVE/FROZEN map to NULL, exactly one ACTIVE row per pair |
| `tests/test_dormancy.sh` | 19 | dormant lifecycle: the policy ships disabled, MARK_DORMANT flags and notifies only dormant non-admin accounts, SUSPEND_DORMANT waits for the grace window and revokes sessions, SUPER_ADMINs are never auto-flagged, and REACTIVATE_DORMANT clears the suspension |
| `tests/test_step_up_policy.sh` | 14 | customer step-up policy: STEP_UP_REQUIRED answers from the owner-controlled table, email change/MFA disable are required by default, transfer stays disabled until a threshold is set, the threshold comparison is exact, and a disabled row drops the requirement |
| `tests/test_password_policy.sh` | 18 | password policy: the deny list refuses common passwords case-insensitively at signup/change/reset, the bounded history refuses the current and last N passwords, 0 disables the history, and the trim keeps the configured bound |
| `tests/test_session_security.sh` | 26 | session security: revoke every other device while keeping the caller's family, the administrator idle bound (refused refresh, revoked family, token bump, audit; 0 disables), first-sighting device notices in the outbox, and the login/step-up/reset audit taxonomy |
| `tests/coverage_check.sh` | nightly | coverage floor and ratchet: COBOL statement coverage mapped from the generated C over a representative subset plus the gateway line/branch report; 30% floor, 1pp ratchet; run by `scripts/nightly.sh`, not on every merge (ADR 0078) |
| `tests/test_permissions.sh` | 23 | scoped permissions: CHECK_PERMISSION answers and LIST_PERMISSIONS projects the grant, the read-mostly audit/reconcile gates enforce the permission instead of the rank, a grant inserted as data takes effect and its removal revokes it |
| `tests/test_access_reviews.sh` | 42 | access review: only a SUPER_ADMIN opens a review, the snapshot covers every privileged account, the reviewer is never the subject, a review closes only when every item is decided and every revoked access is actually gone, and opening/deciding/closing are audited |
| `tests/test_hooks.sh` | 4 | installed git hooks match tracked (`--check`), tampering detected, reinstall restores |
| `tests/test_c_memory.sh` | 12 | C/COBOL boundary contract under ASan+UBSan (1-byte result fields, 6-digit codes, 32-char secrets, fast refusal of absurd KDF costs) |
| `tests/test_bridge_txn.sh` | 5 | re-entered `SQL_BEGIN` rolls back leaked work (harness fails pre-fix with the row committed), normal commit persists, empty close reports `NO_TRANSACTION` |
| `tests/test_ref_engine.sh` | 24 | reference engine: type/value creation, DRAFT -> ACTIVE -> RETIRED lifecycle, history, authorization, duplicate rejection, audit, country/holiday/fee/limit/product cutover |
| `tests/test_gl.sh` | 22 | general ledger: chart of accounts, balanced manual and multi-line journals, period open/close control, trial balance, validation, authorization, audit |
| `tests/test_batch.sh` | 34 | batch/EOD foundation: job and step definitions, run lifecycle, active-run guard, checkpoints, balanced control totals, step transitions, retry, EOD future-date guard, audit |
| `tests/test_report.sh` | 45 | report engine: templates, ordered columns, run/row lifecycle, total verification, completion guard, CSV export, authorization, audit |
| `tests/test_import.sh` | 48 | import/export: batch staging, row validation (ledger/accounts/reference/payments), error listing, correction/revalidation, posting guard, export, audit |
| `middleware/` (node --test) | 126 | gateway: contract, injection, rate limit (auth + api, shared store, counted fail-open, loopback trust), refresh rotation/reuse, access-token revocation (version + per-token), per-device logout, **JWT algorithm pinning**, **bounded signing-secret rotation overlap**, **step-up on admin writes**, **admin MFA-enrol prompt**, **error metrics (`gateway_errors_total`)**, **latency histograms + pool restart counter**, **liveness/readiness probes, rate-limited + cached probes, 503 when down**, timeout, line cap, paging cap, uniform envelope, multi-record output, every-endpoint smoke, actor-token guard, anti-enumeration, attempt cap, lockout masking, MFA, session listing/revoke-all, JWT issuer/audience, wallet account status, required idempotency key, transfer limits, transfer status/reversal, inverse FX, account selection, structured profile, rich user listing, neutral email change, profile update, account lifecycle, email-change race, observability (pull + push, admin-only, pool gauges), idempotency conflict **+ in-progress/replay**, every error code's HTTP status (contract table), self-sufficient smoke fixtures, boundary-safe TOTP, self-transfer, audit archive, **audit read**, **admin recovery**, password reset/change, resend verification, security headers/config, **validated request id**, **JSON body cap (413)**, **trust-proxy warning**, **mailer robustness, per-purpose subject, sender name, transactional outbox flow (signup to verified via worker delivery)**, worker pool (pipelined), error mapping |

Shell suites total **1334**; with the gateway suite **126** the full run is
**1460 assertions**, all green as of this snapshot (plus a second end-to-end HTTP
smoke run in pool mode, counted above). The three headline numbers are
machine-checked: `tests/status_check.sh` recomputes them from
`tests/baseline_counts.txt`, and `ci.sh` fails its final step when any suite
reports a different pass count.

## 5. Gateway surface (`middleware/`)

Held by a bearer JWT (public but rate-limited: `/health`, `/live`, `/ready`; public:
`/auth/signup`, `/auth/verify`,
`/auth/login`, `/auth/forgot`, `/auth/reset-password`, `/auth/resend`, `/auth/refresh):
`/users`, `/users/:email`, `/wallet/balance`, `/wallet/transfer`
(`Idempotency-Key`), `/statements`, `/disputes` (GET/POST), `/disputes/:id` (GET),
`/disputes/:id/notes`, `/disputes/:id/acknowledge`, `/disputes/:id/resolve`,
`/disputes/:id/reject`, `/profile` (GET/PATCH), `/profile/deactivate`,
`/profile/email/request`,
`/profile/email/confirm`, `/profile/password`, `/admin/user-status`, `/admin/unlock`, `/admin/mfa-reset`, `/admin/holds`, `/admin/holds/release`, `/admin/reconcile/run`, `/admin/reconcile/runs`, `/admin/reconcile/exceptions`, `/admin/reconcile/acknowledge`, `/admin/reconcile/resolve`, `/admin/requests`, `/admin/requests/approve`, `/admin/requests/reject`, `/admin/outbox`, `/admin/dormancy/mark`, `/admin/dormancy/suspend`, `/admin/dormancy/reactivate`, `/mfa/backup-codes`, `/mfa/recover`, `/mfa/recover/confirm`, `/admin/mfa-recovery/approve`, `/admin/mfa-recovery/reject`, `/admin/mfa-recovery`, `/mfa/enroll`, `/mfa/confirm`,
`/mfa/disable`, `/sessions` (GET), `/sessions/revoke`, `/sessions/revoke-all`, `/sessions/revoke-others`,
`/admin/role` (GET/POST),
`/admin/reconcile`
(read-only balance/ledger check), `/metrics` (Prometheus counters, gated on the `AUDIT_READ` permission),
`/auth/logout` (per-device: removes the presented refresh session and denies the
bearer if sent), `/auth/revoke` (revokes the presented
access token), `/admin/audit/archive` (moves old audit rows to the archive), and
`/admin/audit` (GET, SUPER_ADMIN read of the audit trail with action/email
filters and paging), and `/auth/step-up` (POST, bearer: re-verify your own
password/MFA and mint a short-lived step-up proof), and the access-review
routes `POST /admin/access-reviews` (open), `GET /admin/access-reviews`
(list), `GET /admin/access-reviews/:id` (read), `POST
/admin/access-review-items/:itemId/decide` (record a decision), and `POST
/admin/access-reviews/:id/close` (close) - all SUPER_ADMIN, and the three
writes need a step-up proof.
Customer high-risk actions — `POST /profile/email/request`, `/mfa/disable`
and, once the owner enables the row, `/wallet/transfer` above its threshold —
require the same `X-Step-Up` proof, decided by `STEP_UP_REQUIRED` from the
`step_up_policy` table. Privileged admin writes — `POST /admin/role`, `/admin/user-status`,
`/admin/unlock`, `/admin/mfa-reset`, `/admin/holds`, `/admin/holds/release`, `/admin/requests`, `/admin/requests/approve`, `/admin/requests/reject`, `/admin/audit/archive`, the access-review writes (`/admin/access-reviews`, `/admin/access-review-items/:itemId/decide`, `/admin/access-reviews/:id/close`) and a transfer
reversal — additionally require a fresh step-up proof in the `X-Step-Up` header
(short-lived, STEP_UP_TTL_SECONDS default 300s, bound to the caller and its
token version); a missing/invalid proof is 401 STEP_UP_REQUIRED.
Both admin routes (`/admin/role` POST, `/admin/reconcile`) take the actor from
the verified token, never the request body. The per-user reads (`/users/:email`,
`/wallet/balance`, `/profile`) and the role check `GET /admin/role` allow the
owner or an admin; `/users` (list) is
admin-only. Writes are owner-scoped too: a transfer is always sent from the
token's account, and the email-change flow only acts on the token's own email.
Actor/sender identity always comes from the token.
Status mapping: 200 on `SUCCESS`; 400/401/403/404/409/423/429/500/504 by error
code (see `middleware/src/result.js`; session/token failures map to 401 and
internal/bridge failures to 500). Input-line cap 500 bytes; fixed-window
rate limiting per client (`RATE_LIMIT_*` on `/auth/*`, more generous
`API_RATE_LIMIT_*` on the rest, including the public probes (`/health`, `/ready`;
`/live` stays exempt as pure liveness), whose DB round-trip is cached for
PROBE_CACHE_MS; counters are shared via Redis
when REDIS_URL is set (a dead store fails open but increments
`gateway_ratelimit_failopen_total`, so lost protection is visible in `/metrics`
and the push exporter instead of silent), and the client IP follows TRUST_PROXY — loopback-only by
default (a same-host proxy is trusted, a remote `X-Forwarded-For` is ignored, a directly
exposed socket keeps its peer IP), a hop count/subnet when the proxy lives on another host,
never "true" (production startup warns on the over-permissive value, since the limiter key
depends on it; session IPs stored on refresh sessions follow the same key). JSON bodies are
capped at JSON_BODY_LIMIT (default 20kb, 413 beyond it); every request carries
the 500-byte input-line cap before COBOL runs. Every knob the code reads is
documented with its default in `middleware/.env.example` (gateway and core
alike; enforced by `tests/env_check.sh`). Access token
15m + refresh 7d. Every response carries `X-Request-Id`, and the
server logs one JSON line per request (`event: http_request` with method, route,
status, `error` code, `durationMs`, `cobolMs`); a thrown/transport failure also
logs an `event: gateway_error` line (code, message, stack). Counters are served
at `/metrics` — including `gateway_errors_total{code=...}`, latency histograms
(`gateway_request_duration_ms`, `gateway_cobol_duration_ms`) and a
`gateway_cobol_pool_restarts_total` counter, and mailer delivery
(`gateway_mailer_sent_total`/`gateway_mailer_failed_total`) — and, when
METRICS_PUSH_URL is set, pushed periodically to a collector (with a timeout and
an overlap guard, so a slow collector cannot pile up requests). Unexpected
process-level failures are logged as `event: process_error`.
`helmet` sets standard security headers, and in production the server refuses to
start while JWT_SECRET/REFRESH_SECRET are unset, still the development
defaults, shorter than 32 characters, or **not distinct from each other** (no
two values in the rotation family — current and staged previous, access and
refresh — may share a value, so a token signed for one purpose cannot verify
as another). A staged previous secret is honored **only until its deadline**
(`*_PREVIOUS_UNTIL`, unix epoch seconds): past it the value stops being
accepted even if left configured, and production refuses to start when a
previous secret is set without a valid deadline. The same
startup guard refuses to run with database settings left at their development
defaults: DB_HOST, DB_USER, DB_PASS and DB_NAME must all be set explicitly, and
the credentials may not be the bridge's `cobol_user`/`cobol_pass`/`cobol_db`
defaults. The C bridge enforces the same rule at connect time (fail-closed
backstop for a directly-invoked binary), reporting `ERROR|DB_CONFIG_INSECURE`
distinctly from an unreachable database. Access and
refresh tokens are bound to an issuer and audience
(JWT_ISSUER / JWT_AUDIENCE, defaulting to `cobol-banking-core` /
`cobol-banking-api`) and verification rejects tokens that do not match them.
Tokens are signed and verified with **HMAC-SHA256 only** (`algorithms: ['HS256']`
on verify), so a token claiming `alg: none` or another algorithm family is
rejected. Verification codes (`/auth/signup`, `/profile/email/request`) are
queued in the transactional outbox by COBOL and delivered out of band by
`scripts/outbox_worker.sh` (SMTP when configured, otherwise logged without
the code in development); they are never returned in the HTTP response, and
the list view (`GET /admin/outbox`) never exposes codes. A successful money
movement never waits on the worker: notifications that cannot be delivered
stay observable (`PENDING`/`FAILED`) and age into dead-letter rows instead
of rolling anything back. Access tokens carry
the user's token version, checked on every protected request (`CHECK_TOKEN`);
an admin/status change or a password/email change bumps it, so already-issued
access tokens can be revoked before they expire. A single token can be revoked
per `jti` (`POST /auth/revoke` -> `REVOKE_ACCESS_TOKEN`), and `POST /auth/logout`
is per-device: it removes the presented refresh session and, when the bearer is
also sent, denies that access token — other devices keep working. The denylist
lives in the shared database behind
a `tokenStore` seam (a distributed store can replace it). A user (or an admin)
can list their active refresh sessions (`GET /sessions`), revoke one, or revoke
them all (`POST /sessions/revoke-all` -> `REVOKE_ALL_SESSIONS`, which bumps the
version *and* revokes every refresh session). Responses share one
envelope - success `{ data: [...] }`, failure `{ error, detail? }` - and the
list page size is capped at 100 (`limit` 1..100).

## 6. Governance documents

- `docs/DELIVERY_RULES.md` - mandatory two-module slice workflow, volume target, and definition of done.
- `docs/TRACEABILITY.md` - requirement → control → test/evidence → owner matrix (Gate 0; checked by `tests/traceability_check.sh`), plus `docs/adr/0058-requirement-traceability.md`.
- `docs/adr/0001-invocation-model.md`, `docs/adr/0002-auth-db-stack.md`, `docs/adr/0003-idempotent-transfers.md`, `docs/adr/0004-schema-migrations.md`, `docs/adr/0005-cross-currency-transfers.md`, `docs/adr/0006-token-revocation.md`, `docs/adr/0007-distributed-rate-limiting.md`, `docs/adr/0008-metrics-export.md`, `docs/adr/0009-audit-retention.md`, `docs/adr/0010-worker-pool-invocation.md` - decisions.
- `CODING_STANDARDS.md` - review rules.
- `docs/BUILD_WARNINGS.md` - build-warning triage and the CI warning ratchet (`tests/warning_check.sh`, `tests/warning_baseline.txt`).
- `docs/COVERAGE.md` - coverage definition, floors, and the ratchet (`scripts/coverage_cobol.sh`, `tests/coverage_check.sh`, `tests/coverage_baseline.txt`).
- `scripts/install-hooks.sh` - installs a pre-commit hook that blocks commits on `main`.

## 7. Known gaps (deliberate, by scale)

Requirement-by-requirement status (including what is `missing` and blocked)
lives in `docs/TRACEABILITY.md`, machine-checked by
`tests/traceability_check.sh`. The notes below are the operator-relevant
details behind those rows.

- Password KDF is PBKDF2-SHA256 at 600000 iterations (modern guidance), overridable with the PBKDF2_ITERATIONS env var (the test suite runs at 100000). Login rehashes any legacy `SHA256_` hash or PBKDF2 hash below the current cost on a successful password check, and the derived-key comparison is constant-time.
- Login lockout lives on the user row (`failed_logins` / `locked_until`; 3 failures sets a 15-minute block) and is **masked**: a wrong password returns the same `INVALID_CREDENTIALS` whether the account is unknown, unlocked, or locked, so it cannot enumerate or probe lock state; only a correct password reveals `ACCOUNT_LOCKED`. A good login or a password reset clears the counter. **Lockout-as-DoS model**: anyone who knows an email can keep that account login-blocked with 3 failures per 15-minute window (the block is time-based, and per-IP limits only slow a distributed attacker) — accepted because the alternative (no lockout) enables password guessing, and the errors stay masked so the attacker cannot confirm the account even exists. Lockout never kills live sessions or touches step-up (which deliberately does not count failures, so an admin under pressure cannot be wedged out of privileged writes). Recovery, in order: wait out the 15-minute window, self-service password reset (clears the counter and rotates credentials), or admin `POST /admin/unlock` (rank-gated, audited). The emailed reset itself is cooldown-throttled per account, not a flood vector.
- MFA is TOTP (RFC 6238, SHA-1 / 6 digits / 30s) against a base32 secret on the user row, enforced at login; the autoprovisioning URI uses the issuer from the MFA_ISSUER env var (default `CobolBank`). Eight single-use 10-digit backup codes (PBKDF2-hashed, shown once) work in place of TOTP at login and step-up, burn on use, and are cleared by disable, admin reset, approval, and regeneration; a wrong backup code counts like a wrong TOTP code. Lost-device recovery runs request (neutral, password-checked) then emailed-code verify (capped like resets), then admin approve/reject with notification and audit; only VERIFIED requests can be approved, never by the requester. TOTP verification allows +/- one 30s step of clock drift. A wrong code at **login**, **enrol-confirm** and **disable** counts as a failed login (per-account lockout, 3 tries — `MFA_ENROLL_CONFIRM`/`MFA_DISABLE` are owner-only, so only a session holder can trip them, and the response stays the uniform `INVALID_MFA`). Signup and password-reset re-requests have a per-account cooldown (RESEND_COOLDOWN_SECONDS, default 60, 0 disables): inside the window the pending code is reused neutrally instead of issuing and emailing a new one.
- Transfers require both accounts to be `ACTIVE` and both currencies enabled (`ACCOUNT_FROZEN`/`ACCOUNT_CLOSED`/`CURRENCY_INACTIVE` otherwise); the amount must be positive; cross-currency credits at the stored `exchange_rates` base->target rate, falling back to the reciprocal of the inverse pair when only that exists, computed at 18-decimal scale so the credit is exact at the target currency's precision even at scale (neither direction is `RATE_NOT_FOUND`); the 4dp-exact converted value minus the posted credit (zero for exact postings) books to the target currency's bank-owned `FX_PNL` account inside the same journal (`FX gain`/`FX loss` legs, balanced-leg verified, audited as `FX`), failing the transfer closed when that account is missing or cannot cover a loss; a rate older than `RATE_MAX_AGE_SECONDS` (default 24h) is rejected with `ERROR|RATE_STALE` (HTTP 409), fail closed; debit/credit are rounded to each currency's `prec_val` and the applied rate is **snapshotted** on the CREDIT `ledger` row. `/wallet/balance` returns every account as `iso:balance:available:status` (available = balance minus live holds). The gateway **requires** an `Idempotency-Key` on a transfer; keys are unique per sender (`pending_transactions` UNIQUE `from_email, txn_ref`, plus an auto-increment `id` for deterministic ordering), so two senders may reuse one. Every `ledger` row records the transfer's `from_email`, so its DEBIT/CREDIT pair unambiguously; reversing a **shared** ref therefore requires the `sender` (else `AMBIGUOUS_TRANSACTION`), and reversals are keyed per `(orig_ref, from_email)`. A concurrent same-key attempt returns `TRANSFER_IN_PROGRESS` and resolves to a replay on retry. Reconciliation runs on demand (`RUN_RECONCILIATION` via `POST /admin/reconcile/run` or `scripts/scheduled_reconcile.sh` with a provisioned RECON_ACTOR service identity); each run is immutable with per-account findings, owned and resolved through the exception workflow, and exportable as CSV (`scripts/export_reconciliation.sh`). A recorded divergence raises an alert: `scripts/scheduled_reconcile.sh` exits 2 with an `ALERT|DIVERGENCE` line on any recorded mismatch (see `docs/runbooks/alert-response.md`); journal↔ledger cross-checks are not part of the scan. A SUPER_ADMIN can reverse a transfer once (`REVERSE_TRANSFER` posts compensating `ledger` entries and a `transfer_reversals` marker carrying the required reason); it only succeeds while the target still holds the credited funds. A reversal that originally carried a fee refunds it only for policy-listed reasons (`reversal_fee_policy`: BANK_ERROR refunds via its own verified `FEE` journal, bank `FEE_INCOME` debited and sender credited; CUSTOMER_ERROR retains it; a missing or unlisted reason fails closed with `INVALID_INPUT`). A SUPER_ADMIN can also lock funds with `POST /admin/holds` (`PLACE_HOLD`: amount, optional expiry in days and currency pin, audited) and release with `POST /admin/holds/release` — both step-up-gated; transfers check the available balance, never the raw ledger balance. A per-currency flat fee from the bank-owned `fee_schedule` (no row = no fee) posts as its own `FEE` journal inside the same transfer transaction; a missing fee-income account or an unrepresentable fee fails the transfer closed. Fee amounts and hold policy are unapproved owner decisions (Gate 0); the core only applies configured data. Transient DB failures (lock wait / deadlock / lost connection) return `DB_BUSY` (503) instead of `DB_ERROR`; idempotency intents are **archived** past a retention window (env PENDING_RETENTION_DAYS, default 30 days, 0 disables), so replay is a bounded guarantee while the history is kept. The core validates the amount format itself (a plain positive decimal; fraction digits must fit the sender currency's precision, at most the four the `DECIMAL(18,4)` schema stores), independently of the gateway pattern; numeric working fields are `S9(16)V9999` and every money parse normalizes the dot before `NUMVAL` (the program compiles with `DECIMAL-POINT IS COMMA`), so limits, sufficiency, replay, and reversal compare exact major units per currency. A multi-account sender or recipient can be pinned by currency (`fromCurrency`/`toCurrency`, transfer p5/p6).
- **Ledger integrity**: `ledger` is **append-only** (a trigger refuses `UPDATE`) and `amount >= 0` (a `CHECK`); when an account (or a user, via the cascade to accounts) is deleted, its ledger rows are copied into the immutable `ledger_archive` (no FK) before the cascade removes them, so ledger history survives instead of being destroyed. A reversal's audit row records the sender in `detail`.
- **Ledger known gaps (deliberate)**: `prec_val` above 4 has no exact `DECIMAL(18,4)` representation, so transfers in such currencies fail closed (`CURRENCY_INACTIVE`) instead of rounding silently. Rate source is the stored `exchange_rates` table with a validity window (`RATE_MAX_AGE_SECONDS`, default 24h; stale rejected closed); debit/credit round to each currency's precision and the 4dp residual books to the target currency's bank-owned `FX_PNL` account in the same journal (D1 implemented; sub-0.00005 remainders below ledger scale stay unbooked). Stale `pending_transactions` housekeeping runs before the transfer transaction (bounded but not atomic with it). `TX_STATUS` formats the intent amount at the sender currency's own precision (from the posted ledger DEBIT leg, or the sender's single account currency while still pending), not a fixed two decimals.
- Email-change requests are **neutral**: requesting a change to an already-registered address returns the same `CODE_SENT` success with no code (nothing delivered and no `EMAIL_CHANGE` code stored), so the action cannot enumerate emails. Email change is owner-only, requires the **current password**, and on confirm **bumps `token_version` and revokes every refresh session** (clean re-login); the old address is notified.
- Account lifecycle: `users.status` is `UNVERIFIED`/`VERIFIED`/`SUSPENDED`/`CLOSED`. The owner can soft-close their account (`DEACTIVATE_ACCOUNT` -> `CLOSED`) and an admin can set any status (`SET_USER_STATUS`). Login refuses `SUSPENDED`/`CLOSED` with `USER_SUSPENDED`/`USER_CLOSED`; deactivation and every status change bump `token_version` and revoke refresh sessions, so existing tokens die immediately.
- **Admin role hierarchy** (USER < MANAGER < SUPER_ADMIN): an actor may not administer an account ranked **above** it. `SET_USER_STATUS`, `REVOKE_USER_SESSION` and `REVOKE_ALL_SESSIONS` refuse when the actor is lower-ranked than the target — so a MANAGER can never suspend/close a SUPER_ADMIN or force-logout its sessions. Equal ranks are allowed (a SUPER_ADMIN may act on a peer for incident response), and self-service is always allowed. FASE B (last-admin protection) builds on this.
- **Access review and attestation** (ADR 0073): a SUPER_ADMIN opens a review
  that snapshots every `MANAGER`/`SUPER_ADMIN` account with the role, account
  status, MFA state, and last sign-in at that moment; a reviewer records a
  decision (`ATTESTED` or `REVOKED`) per item, and may never attest its own
  access; the review closes only when every item is decided and every revoked
  subject has actually lost the privileged role (otherwise `REVIEW_INCOMPLETE`
  or `REVOCATION_PENDING`). The removal itself runs through the ordinary
  privileged actions, so it keeps the rank check, the last-admin guard, and
  the maker-checker designation. `users.last_login_at` is written on a
  successful login so a reviewer can see how long an account has been dormant.
  The review cadence, the accountable owner, and the evidence retention are
  Gate 0 decisions and are not assumed here.
- **Dormant lifecycle** (ADR 0080): `MARK_DORMANT` flags accounts idle longer than `DORMANT_AFTER_DAYS` and queues a notice; `SUSPEND_DORMANT` suspends them after `DORMANT_GRACE_DAYS` if they still have not signed in, revoking sessions; `REACTIVATE_DORMANT` clears it. The policy ships disabled (`DORMANT_AFTER_DAYS=0`), SUPER_ADMIN accounts are never auto-suspended, and every step is audited.
- **Customer step-up** (ADR 0079): `STEP_UP_REQUIRED` reads the owner-controlled `step_up_policy`; the gateway requires a fresh `X-Step-Up` proof for email change and MFA disable (and for transfers once the owner enables the row with a threshold). The transfer row ships disabled so existing transfers are unchanged; the threshold is a risk-owner decision, not a code constant.
- **Password policy** (ADR 0077): `REQUEST_SIGNUP`, `CHANGE_PASSWORD`, and `RESET_PASSWORD` refuse a common password from the owner-controlled `password_blocklist` (case-insensitive, SHA-256 keyed) with `PASSWORD_BLOCKED`, and refuse the current password or one of the last `PASSWORD_HISTORY_COUNT` (default 5; 0 disables) with `PASSWORD_REUSED`. History is recorded and trimmed inside the same transaction; the seed list is a development placeholder and production supplies its own data.
- **Session security** (ADR 0075): `REVOKE_OTHER_DEVICES` signs out every other device while keeping the caller's own family. An administrator (`SUPER_ADMIN`/`MANAGER`) refresh whose previous activity is older than `ADMIN_IDLE_TIMEOUT_SECONDS` (default 1800; 0 disables) is refused with `SESSION_EXPIRED`, the family is revoked, the token version is bumped, and `SESSION_IDLE_TIMEOUT` is audited; the access-token lifetime bounds the residual window. `LOGIN_NOTICE` records `(email, user agent, IP)` in `known_devices` and queues a `NEW_DEVICE` outbox notice on the first sighting (no code, IP only). Successful logins, step-up outcomes, and reset requests are audited (`AUTH_LOGIN_SUCCESS`, `STEP_UP_OK`/`STEP_UP_FAILED`, `PASSWORD_RESET_REQUESTED`), and `/metrics` exposes `gateway_auth_failures_total{reason=...}`.
- **Scoped permissions** (ADR 0074): the read-mostly gates (`LIST_AUDIT`, `ARCHIVE_AUDIT`, `RECONCILE`, `LIST_RECONCILIATIONS`, `LIST_EXCEPTIONS`, `/metrics`) enforce a named permission from the `permissions` catalog instead of a hardcoded `SUPER_ADMIN` check. Phase 1 reproduces the current behavior exactly (`SUPER_ADMIN` holds every permission, other roles hold none); the grant itself is data, and `CHECK_PERMISSION` answers while `LIST_PERMISSIONS` projects the effective set in the login and profile responses.
- **Last-admin protection**: the system refuses to leave itself without an active (VERIFIED) SUPER_ADMIN. `CHANGE_ROLE` rejects demoting the last one, `SET_USER_STATUS` rejects suspending/closing/unverifying it, and `DEACTIVATE_ACCOUNT` rejects self-closing it — all with `ERROR|LAST_ADMIN` (HTTP 409). Once a second active SUPER_ADMIN exists the change is allowed. Recovery if the admin population is ever lost is out-of-band (a DBA sets `role='SUPER_ADMIN'`); see ADR 0014.
- **The audit trail is readable over HTTP**: `GET /admin/audit` (SUPER_ADMIN) lists `audit_trail` rows (`id:created:action:subject:actor:entity_type:entity_id:status:detail`) with an optional `action` and `email` filter and `limit`/`offset` paging, plus a total. `ARCHIVE_AUDIT` requires a retention of at least one day (days=0 would move the whole live trail in one call and is refused).
- **Privileged accounts and recovery**: `MANAGER` may read any user (`GET_USER`/`LIST_USERS`/balances/session lists), set another user's status, revoke their sessions, and unlock/reset MFA — but never a higher-ranked account, and it cannot change roles, reverse transfers, reconcile, archive the audit, or read the audit trail (all SUPER_ADMIN-only in phase 1, enforced through the permission catalog). `/metrics` is gated on the `AUDIT_READ` permission (currently held only by `SUPER_ADMIN`). `POST /admin/unlock` (clear a lockout) and `POST /admin/mfa-reset` (disable a user's MFA) let an admin recover a user, both rank-gated and audited. **Step-up**: privileged admin writes (role change, status, unlock, MFA reset, audit archive, transfer reversal) require a fresh re-authentication proof from `POST /auth/step-up` in the `X-Step-Up` header — short-lived (STEP_UP_TTL_SECONDS, default 300s), bound to the caller and its token version, and not usable as an access token. **Admin accounts (SUPER_ADMIN/MANAGER) must have MFA enabled**: without it, step-up is refused (`MFA_SETUP_REQUIRED`) and no privileged write is possible; a non-admin needs only the password. At **login and refresh** the response carries `mfaEnrollmentRequired: true` for an admin without MFA, so the client is prompted to enrol; login and enrolment stay available, but no privileged write succeeds until MFA is enabled.
- Profile actions validate their own inputs in COBOL (email shape, date-of-birth format/ranges) as defence-in-depth alongside the gateway patterns; an email-change whose new address is taken between request and confirm is reported as `EMAIL_EXISTS` rather than an opaque failure.
- Refresh **rotation is atomic** (`CONSUME_SESSION`: a single conditional revoke; concurrent callers cannot both win). A replay of a consumed token is reuse — the gateway's `/auth/refresh` rejects it, the whole family is revoked, the user's `token_version` is bumped (so previously issued access tokens die immediately) and a `SESSION_REUSED` audit row is written.
- **Logout is per-device**: `/auth/logout` removes only the presented refresh session (so replaying a logged-out token is a plain `SESSION_NOT_FOUND`, not a reuse that would nuke every device) and, when the bearer is also presented, adds that access token's `jti` to the denylist. Other devices are unaffected; `POST /sessions/revoke-all` remains the logout-everywhere path.
- **JWT is algorithm-pinned**: every `jwt.verify` passes `algorithms: ['HS256']` and every `jwt.sign` sets `algorithm: 'HS256'`, so algorithm-confusion tokens (`alg: none`, HS384, ...) are rejected. In production `assertSecureConfig` additionally refuses secrets that are missing, the development defaults, shorter than 32 characters, or identical between access and refresh.
- **Refresh families have an absolute lifetime and a rotation cap**: each login starts a family (`refresh_families`); `CONSUME_SESSION` refuses — and revokes the family with `SESSION_FAMILY_EXPIRED` — once it is older than `REFRESH_ABSOLUTE_TTL_DAYS` (default 30) or has rotated more than `REFRESH_MAX_ROTATIONS` times (default 100), forcing a fresh login even though the current refresh token is still within its own expiry. Set either to 0 to disable that check. The check **fails closed** if the family state cannot be read.
- **Security events are audited**: reuse (`SESSION_REUSED`) and a forced family expiry (`SESSION_FAMILY_EXPIRED`) both write an `audit_trail` row with `status='FAILED'`. The access-token denylist is pruned of expired rows whenever a session is stored (`STORE_SESSION` housekeeping, alongside expired `refresh_sessions`), so it does not grow without bound.
- **Sessions carry metadata and the current device is marked**: `STORE_SESSION` records the client **user-agent and IP** on each refresh session, and `GET /sessions` returns them. The access token now carries a `sid` claim equal to its refresh-session `family`, so the list marks the caller's own session with `current`.
- Optional transfer caps are read from the environment and **off by default** (0): TRANSFER_MAX_PER_TXN caps one debit, TRANSFER_DAILY_LIMIT caps the rolling 24h debit total per account (from the `ledger`); both are whole units of the sender's currency, digits only, compared in exact major units — a malformed setting fails closed (`LIMIT_EXCEEDED`/`DAILY_LIMIT_EXCEEDED`).
- Email change updates `users.email`; related FKs (`refresh_sessions`, `pending_transactions`) cascade on update (migrations 0003 and 0004, which repairs a 0001/0003 ordering regression), so a logged-in user with a transfer intent can still change their email.
- Prepared statements are used for the parameterized queries in `user_core`, `wallet_core` and most of `auth_core`; the remaining `auth_core` statements (login/lockout, signup/verify, audit) embed `mysql_real_escape_string`-escaped values, which the whitelist validator plus escaping keep safe. The locking `SELECT ... FOR UPDATE` uses `SQL_PREPARE_EXEC_LOCK` (bound params, no row fetch) because reading its result via `mysql_stmt_store_result` makes MariaDB raise `ER_CHECKREAD` (1020) under contention. Prepared SQL is bounded at 1023 chars (`WS-PREP-SQL` `PIC X(1024)`).
- `audit_trail` records `REQUEST_SIGNUP` (SUCCESS), `VERIFY_EMAIL` (SUCCESS, and FAILED for a bad/expired/reused code when the email belongs to a user; unattributable attempts are skipped), `AUTH_LOGIN_FAILED`, `TRANSFER`, `EMAIL_CHANGE`, `CHANGE_ROLE`, and `AUTHZ_DENIED` (a refused authorization attempt for an authenticated actor, `detail` = the attempted target). **AUTHZ_DENIED** is written by the shared guards in `auth_core`, `user_core` and `wallet_core` — including the SUPER_ADMIN-only `RECONCILE`/`REVERSE_TRANSFER` and the `CHECK_BALANCE`/`GET_DASHBOARD` self-or-admin reads. **Actor attribution**: rows have a subject `user_id` and an `actor_id` that names who performed the action; admin-on-other events (`SET_USER_STATUS`, `SESSIONS_REVOKED`, `REVOKE_USER_SESSION`, `ARCHIVE_AUDIT`) set it, while self-service rows leave it NULL (the subject acted). Refresh tokens are single-use and rotate within a `family`; presenting an already-revoked token is treated as reuse and revokes the whole family (all sessions for that login), so a stolen token cannot be replayed.
- Expired `refresh_sessions` and `verification_logs` are pruned opportunistically (on session store and on signup). `audit_trail` is **append-only** (like `ledger`, an `UPDATE`-refusing trigger — migration 0028/`schema.sql`) and bounded: `ARCHIVE_AUDIT` moves rows past a retention window into the immutable `audit_trail_archive`; a correction is a new appended entry, never an in-place edit. Deleting a user **does not destroy their history**: a `BEFORE DELETE ON users` trigger copies the user's live `audit_trail` rows into `audit_trail_archive` before the FK cascade removes them. `audit_trail` is indexed on `action` and `actor_id` for the read path.
- Results are written as 500-char records and reassembled by the gateway; the buffers are 16 KB, so extremely large lists still have an upper bound. Invocation defaults to **process-per-request** (file mode); serve mode + keep-alive connection + a **gateway worker pool** are implemented and enabled with COBOL_POOL_SIZE (ADR-0010 phases 1-3). Every pool setting is **validated at startup** (a non-integer or out-of-range COBOL_POOL_SIZE / COBOL_POOL_PIPELINE / COBOL_POOL_TIMEOUT_MS / COBOL_POOL_QUEUE_MAX refuses to boot instead of leaving requests queued forever), the waiting queue is **bounded** (a request arriving at a full queue is rejected with 503 POOL_SATURATED), a request that waits longer than the timeout fails with 504, and closing the pool fails whatever is still waiting rather than leaking it.
- **Coverage cadence** (ADR 0078): the full `./ci.sh` (78 steps) no longer runs the coverage measurement; `scripts/nightly.sh` runs it on a schedule (30% floor, 1pp ratchet) and the release checklist requires a recent green run.
- **Tiered CI** (ADR 0076): `./ci-fast.sh` is the affected-surface inner-loop gate (docs-only changes finish in seconds; core changes run a twelve-suite money-path smoke set; middleware changes run the full gateway suite) and checks the assertion counts of what it runs against the same baseline manifest. `./ci.sh` remains the 71-step full merge and release evidence.
- **Test execution**: most functional shell suites run their requests through `tests/serve_harness.sh`, which keeps one `main_logic --serve` process (the same protocol the worker pool uses) instead of spawning a process per assertion. Suites that need fresh-process semantics (crash injection, per-call environment, file-mode assertions) keep the default invocation. The test-only KDF cost is 10000 iterations (`ci.sh`); the KDF suite asserts the compiled production default (600000) with explicit per-call values.
- **Test coverage (deliberate)**: gateway tests never skip silently — a failed database seed fails the test via `requireSeed` (`middleware/test/support.js`), and `ci.sh` fails the gateway step on any reported skip. Every `result.js` error code's HTTP status is asserted against an explicit contract table, and the table and the implementation must list exactly the same codes (a new code without a status fails the test). `TRANSFER_IN_PROGRESS` and the replay-on-commit path are exercised by seeding a `PENDING`/`COMMITTED` intent. The COBOL transient detector (`DB_BUSY` on lock-wait/deadlock/lost-connection) and CURRENCY_MISMATCH (a legacy code with no current producer — cross-currency is supported, ADR 0005) are covered at the mapping level only, not end-to-end. **Fixtures keep the ledger consistent**: seeded accounts always get a matching opening ledger row (`middleware/test/support.js`), and the gateway/endpoints/profile suites delete the users they create, so a full `./ci.sh` leaves no account whose balance diverges from the ledger (a manual `RUN_RECONCILIATION` reports zero mismatches).
- **Operations are procedural, not automatic**: `scripts/backup.sh` takes a consistent snapshot plus a manifest (git rev, per-table counts and live checksums), `scripts/restore.sh` replays and verifies it (counts, checksums, migration check, bridge smoke), and `tests/test_backup_restore.sh` round-trips this path in CI with a canary row that must disappear. `docs/runbooks/` holds incident, alert (signal inventory; numeric thresholds stay owner-approved), backup/restore, deploy/rollback, and secret-rotation procedures; `docs/patch-policy.md` gates dependencies via `npm audit --omit=dev --audit-level=high` in CI, and `docs/release-checklist.md` is the per-release evidence template. Still missing (Gate 0 owners): approved SLOs, RPO/RTO, backup schedules/retention, automatic alerting, and independent assessment.

## 8. Production status and transition

Production status: **owner approvals are recorded in `docs/APPROVALS.md`**;
signed evidence is retained in the private evidence store. The implementation
transition is governed by `docs/PRODUCTION_GRADE_PLAN.md` and
`docs/adr/0081-production-grade-transition.md`. Current implementation gaps
include:

- The generated reference module is isolated and tagged, and must be replaced
  by the generic reference-data model; it must not grow.
- No container, Kubernetes, or CI/CD deployment pipeline is present.
- No SAST/DAST, SBOM, secret scan, or independent penetration test evidence.
- No approved SLO/RPO/RTO or completed disaster-recovery drill.
- Approval of production scope, jurisdiction, and the compliance matrix is recorded in `docs/APPROVALS.md`; implementation evidence remains tracked.
- Target runtime is GnuCOBOL/MySQL/Linux (ADR 0082); the owner approval is
  recorded in `docs/APPROVALS.md`.
- The 100k/60k milestone is a historical volume milestone and is not a
  substitute for approval evidence.
- Owner posture: target production berlisensi, full product scope.
  Entity: PT Flopay Teknologi Indonesia (Indonesia); license 28/145/DKSP/Srt/B
  (Izin Penyelenggara Uang Elektronik dan Transfer Dana), active 2026-05-12,
  supervised by Bank Indonesia and OJK. Named owners and approvals are recorded
  in `docs/GATE0_PACKET.md` and `docs/APPROVALS.md`. Batch 2
  inputs: KYC in-house + Dukcapil; sanctions/PEP Dow Jones; monitoring in-house
  COBOL rules; fraud 24/7 in-house; limits IDR 25m/50m and USD 5k/10k; fee
  IDR 2,500/txn; risk-based auto hold; FX residual 0.01; SLO 99.95% with read
  p95 200ms and transfer p95 400ms; RPO 5m/RTO 1h; patch 3/14/30 days;
  retention 7y/90d/30d; reports LBPUE + trial balance; release approvers owner
  + CISO + COO + Compliance. Implementation evidence remains tracked in this
  file and `docs/TRACEABILITY.md`.
- The consolidated Gate 0 decision packet, input checklist, and proposed
  technical defaults are in `docs/GATE0_PACKET.md`.
- Non-generated net baseline: 58.093; target 100.000 per
  `docs/DELIVERY_RULES.md`.
