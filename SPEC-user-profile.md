# Spec: user-profile

Status: **built** — dashboard, real user listing, and the two-step email change are implemented on the bridge.
Last verified against code: 2026-10-10

## Objective (unchanged)

Profile management: a read-only dashboard of essential account info, plus a strict two-step verification flow for changing the registered email.

## As-Built (live, routed by `main_logic`)

- **Source:** `cobol/src/user_core.cob` (program id `user_core`), compiled by `build.sh`, DB via `cobol/src/sql_bridge.c`.

| Action | Params | Behavior today | Outputs |
|---|---|---|---|
| `GET_USER` | `p1=email` | `SELECT id, email FROM users WHERE email='…' LIMIT 1` | `1\|sender@test.com` · `ERROR\|NOT_FOUND` |
| `LIST_USERS` | — | single-line list via `GROUP_CONCAT(id:email)` (the bridge returns one row) | `SUCCESS\|LIST_DONE\|<id:email;…>` |
| `GET_DASHBOARD` | `p1=email` | `balance`, `email`, `full_name` for the user's account | `SUCCESS\|DASHBOARD\|<balance>\|<email>\|<full_name>` · `ERROR\|ACCOUNT_NOT_FOUND` |
| `REQ_EMAIL_CHANGE` | `p1=current email`, `p2=new email` | current must exist, new must not be taken; generate a 6-digit code stored against the new email in `verification_logs` (`purpose=EMAIL_CHANGE`, 24h expiry) | `SUCCESS\|CODE_SENT\|<code>` · `ERROR\|ACCOUNT_NOT_FOUND` · `ERROR\|EMAIL_EXISTS` · `ERROR\|EMAIL_CHANGE_FAILED` |
| `CONFIRM_EMAIL_CHANGE` | `p1=current email`, `p2=new email`, `p3=code` | match an unused, unexpired `EMAIL_CHANGE` code; move the email and consume the code inside one transaction | `SUCCESS\|EMAIL_CHANGED` · `ERROR\|INVALID_CODE` · `ERROR\|EMAIL_CHANGE_FAILED` |

### Tests

`tests/test_user_profile.sh` (12 assertions). Wired into `ci.sh`.

## Notes / not yet done

- Multi-account users: `GET_DASHBOARD` takes a single (`LIMIT 1`) account; per-currency dashboards are not implemented.
- `LIST_USERS` returns at most the first 400 characters of the concatenated list (single-line contract).
- Email-change code expiry is 24h to match signup; a shorter window (the original open question suggested 15 min) is not implemented.
- `audit_trail` records a `EMAIL_CHANGE` row on a successful confirm; other profile reads are not audited (and need not be).

## Code style (enforced today)

- Action names must agree between `cobol/src/main_logic.cob` and the owning module (routing contract in `AGENTS.md`).
- Output pipe-delimited, one line; no `GOBACK` in `PERFORM`ed paragraphs (see `CODING_STANDARDS.md`).

## Open questions

- Should email-change codes expire sooner than signup codes?
- Should `LIST_USERS` page instead of concatenating into one line?
