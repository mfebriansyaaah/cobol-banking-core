# Spec: user-profile

Status: **built** — dashboard, real user listing, and the two-step email change are implemented on the bridge.
Last verified against code: 2026-10-10

## Objective (unchanged)

Profile management: a read-only dashboard of essential account info, plus a strict two-step verification flow for changing the registered email.

## As-Built (live, routed by `main_logic`)

- **Source:** `cobol/src/user_core.cob` (program id `user_core`), compiled by `build.sh`, DB via `cobol/src/sql_bridge.c`.

| Action | Params | Behavior today | Outputs |
|---|---|---|---|
| `GET_USER` | `p1=email` | `SELECT id, email, full_name, status, role, created_at FROM users WHERE email='…'` | `SUCCESS\|USER\|<id>\|<email>\|<name>\|<status>\|<role>\|<created>` · `ERROR\|NOT_FOUND` |
| `LIST_USERS` | `p1=limit` (default 20), `p2=offset` (default 0), `p4=role` (optional) | paged with a total; one row per user `id:email:name:role:status`, rows joined by `;`; optional role filter | `SUCCESS\|LIST_DONE\|<total>\|<id:email:name:role:status;…>` |
| `GET_DASHBOARD` | `p1=email` | `email`, `full_name`, `status`, `role`, `dob`, `created_at`, and **all** the user's accounts as `iso:balance:available:status` rows at the currency's own precision (same projection as `CHECK_BALANCE`); `LEFT JOIN accounts` so a user without accounts still has a profile | `SUCCESS\|DASHBOARD\|<email>\|<name>\|<status>\|<role>\|<dob>\|<created>\|<iso:balance:available:status;…>` · `ERROR\|ACCOUNT_NOT_FOUND` |
| `REQ_EMAIL_CHANGE` | `p1=current email`, `p2=new email`, `p3=actor`, `p4=password` | validate both emails; actor must own the current email and the **current password** must match; **neutral** about whether the new address is taken — if free, a 6-digit code is stored against it (`purpose=EMAIL_CHANGE`, 24h); if taken, returns the same success with no code | `SUCCESS\|CODE_SENT\|<code>` (free) · `SUCCESS\|CODE_SENT` (taken) · `ERROR\|ACCOUNT_NOT_FOUND` · `ERROR\|INVALID_CREDENTIALS` · `ERROR\|INVALID_INPUT` · `ERROR\|EMAIL_CHANGE_FAILED` · `ERROR\|FORBIDDEN` |
| `CONFIRM_EMAIL_CHANGE` | `p1=current email`, `p2=new email`, `p3=code` | match an unused, unexpired `EMAIL_CHANGE` code; move the email, **bump `token_version`**, and **revoke every refresh session** in one transaction (clean re-login); a new address taken in the meantime is `EMAIL_EXISTS` | `SUCCESS\|EMAIL_CHANGED` · `ERROR\|INVALID_CODE` · `ERROR\|EMAIL_EXISTS` · `ERROR\|INVALID_INPUT` · `ERROR\|EMAIL_CHANGE_FAILED` |
| `UPDATE_PROFILE` | `p1=email`, `p2=full name`, `p3=actor` (owner), `p4=dob` (optional) | owner-only self-service; validate the email and (when given) the date of birth, then update `full_name`/`dob` with an audit row in one transaction; a blank name is refused | `SUCCESS\|PROFILE_UPDATED` · `ERROR\|FORBIDDEN` · `ERROR\|ACCOUNT_NOT_FOUND` · `ERROR\|INVALID_INPUT` · `ERROR\|PROFILE_UPDATE_FAILED` |
| `DEACTIVATE_ACCOUNT` | `p1=email`, `p2=actor` (owner) | owner-only soft-close: set `status='CLOSED'`, bump `token_version`, revoke refresh sessions, audit; refuses when it is the last active `SUPER_ADMIN` (`ERROR\|LAST_ADMIN`) | `SUCCESS\|ACCOUNT_DEACTIVATED` · `ERROR\|FORBIDDEN` · `ERROR\|ACCOUNT_NOT_FOUND` · `ERROR\|LAST_ADMIN` · `ERROR\|DEACTIVATE_FAILED` |
| `SET_USER_STATUS` | `p1=email`, `p2=status`, `p3=actor` (admin) | admin sets `UNVERIFIED`/`VERIFIED`/`SUSPENDED`/`CLOSED`; the actor may not be lower-ranked than the target (MANAGER < SUPER_ADMIN); refuses to disable the last active `SUPER_ADMIN` (`ERROR\|LAST_ADMIN`); bump `token_version`, revoke refresh sessions, audit | `SUCCESS\|STATUS_CHANGED` · `ERROR\|FORBIDDEN` · `ERROR\|ACCOUNT_NOT_FOUND` · `ERROR\|INVALID_STATUS` · `ERROR\|LAST_ADMIN` · `ERROR\|STATUS_CHANGE_FAILED` |
| `UNLOCK_USER` | `p1=email`, `p2=actor` (admin not lower-ranked) | clears `failed_logins`/`locked_until` so a locked user can log in; audit (subject + actor) | `SUCCESS\|ACCOUNT_UNLOCKED` · `ERROR\|FORBIDDEN` · `ERROR\|ACCOUNT_NOT_FOUND` · `ERROR\|INVALID_INPUT` · `ERROR\|UNLOCK_FAILED` |
| `ADMIN_RESET_MFA` | `p1=email`, `p2=actor` (admin not lower-ranked) | clears `mfa_enabled`/`mfa_secret` so a user can re-enroll; audit (subject + actor) | `SUCCESS\|MFA_RESET` · `ERROR\|FORBIDDEN` · `ERROR\|ACCOUNT_NOT_FOUND` · `ERROR\|INVALID_INPUT` · `ERROR\|MFA_RESET_FAILED` |

### Tests

`CONFIRM_EMAIL_CHANGE` works for a logged-in user: `users.email` changes propagate through the `refresh_sessions`/`pending_transactions` FKs (`ON UPDATE CASCADE`, migration 0003).

`tests/test_user_profile.sh` (41 assertions) and `tests/test_account_lifecycle.sh` (15 assertions). Wired into `ci.sh`.

## Notes / not yet done

- A profile may be updated in place: `UPDATE_PROFILE` sets `full_name` (and `dob` when supplied) for the owner only, with an audit row. `GET_DASHBOARD` now returns the full profile (email, name, status, role, dob, created) and covers every account the user holds (multi-currency) with per-currency precision plus the spendable (holds-aware) balance and status, and works for users with no accounts; a per-account drill-down is not implemented.
- `LIST_USERS` is paged (`limit`/`offset`) using the prepared multi-row bridge call (`SQL_PREPARE_EXEC_ROWS`); the response is one pipe-delimited line, so the result is still bounded by the COBOL output buffer size.
- Email-change code expiry is 24h to match signup; a shorter window (the original open question suggested 15 min) is not implemented.
- `audit_trail` records a `EMAIL_CHANGE` row on a successful confirm; the old address is notified out of band and the change forces a clean re-login (token-version bump + refresh-session revocation). Other profile reads are not audited (and need not be).

## Code style (enforced today)

- Action names must agree between `cobol/src/main_logic.cob` and the owning module (the routing contract).
- Output pipe-delimited, one line; no `GOBACK` in `PERFORM`ed paragraphs (see `CODING_STANDARDS.md`).

## Open questions

- Should email-change codes expire sooner than signup codes?
- Now that `LIST_USERS` is paged via the multi-row bridge call, should a future version return a structured page (total count plus items) instead of one delimited line?
