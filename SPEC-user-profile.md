# Spec: user-profile

Status: **not started** — no dedicated module exists. A minimal slice is served by `user_core.cob`.
Last verified against code: 2026-10-10

## Objective (unchanged)

Profile management: a read-only dashboard of essential account info, plus a strict two-step verification flow for changing the registered email.

## As-Built (what exists today)

- **Source:** `cobol/src/user_core.cob` (program id `user_core`) — the closest thing to this module.
- **Reachable through:** `main_logic.cob` routes `GET_USER` and `LIST_USERS` here; compiled by `build.sh`; DB via `sql_bridge.c` (libmysqlclient, `cobol_db`).

| Action | Params | Behavior today | Outputs |
|---|---|---|---|
| `GET_USER` | `p1=email` | `SELECT id, email FROM users WHERE email='…' LIMIT 1` | `1|sender@test.com` · `ERROR|NOT_FOUND` |
| `LIST_USERS` | — | returns a fixed success string (no real listing yet) | `SUCCESS|LIST_DONE` |

- **No** dedicated `user_profile` module source exists. There is no `GET_DASHBOARD`, `REQ_EMAIL_CHANGE`, or `CONFIRM_EMAIL_CHANGE` implementation anywhere in the codebase.

## To add (the whole module is missing)

- [ ] `GET_DASHBOARD` returning exactly `balance`, `email`, `full_name` for the requesting user.
- [ ] `REQ_EMAIL_CHANGE`: generate a 6-digit code, persist it (`verification_logs` table already exists with `email`, `code`, `purpose ENUM('SIGNUP','EMAIL_CHANGE')`, `expires_at`, `is_used`).
- [ ] `CONFIRM_EMAIL_CHANGE`: update the email only if the code matches, is unused, and unexpired.
- [ ] Uniqueness guard: reject changing to an email already registered to another user (`users.email` is `UNIQUE`).
- [ ] Make `LIST_USERS` actually return the user list (it currently returns a constant).
- [ ] Tests: unauthorized access, verification-flow, and invalid-code cases (the original spec's testing strategy), added to `tests/`.

## Conventions to conform to (as built)

- Lives in the file-based binary: reads `input.txt` (`ACTION|p1|p2|p3|p4`), writes `output.txt`; connect via `sql_bridge.c` (`SET_QUERY`/`SQL_EXECUTE`/`GET_RESULT`).
- Action name must be added to the routing contract in **all three** of `main_logic.cob`, `user_core.cob` (or a new `user_profile.cob` registered in `build.sh`), and reviewed together.
- Substring match by exact length; no `FUNCTION TRIM(...) = "literal"` (`CODING_STANDARDS.md`).
- Amounts/ids returned as trimmed text; `DECIMAL-POINT IS COMMA` is set in existing modules.

## Code style

- Pipe-delimited single-line output; one result per run.
- `PERFORM`ed helper paragraphs: no `GOBACK`, end with `EXIT PARAGRAPH.`.

## Open questions

- New `user_profile.cob`, or extend `user_core.cob`? Extending avoids a fourth file in the routing contract.
- Email-change code expiry window (e.g. 15 minutes) — the original spec left this open.
