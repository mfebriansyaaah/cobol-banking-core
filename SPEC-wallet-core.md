# Spec: wallet-core

Status: **built** — functional surface, atomic transfer, immutable ledger entries, sender row-lock, and an active balance/ledger reconciliation action.
Last verified against code: 2026-10-10

## Objective (unchanged)

Manage balances and record every cent moving in or out, with absolute data integrity (atomic transactions).

## As-Built (what exists today)

- **Source:** `cobol/src/wallet_core.cob` (program id `wallet_core`).
- **Reachable through:** `cobol/src/main_logic.cob` routes `CHECK_BALANCE` and `TRANSFER` here. Compiled into the single binary by `build.sh`.
- **DB access:** through the C bridge `cobol/src/sql_bridge.c` (`SET_QUERY` / `SQL_EXECUTE` / `GET_RESULT`) which uses **libmysqlclient**, not ODBC. Database `cobol_db`, credentials from `cobol/src/sql_bridge.c`.
- **I/O:** reads one pipe-delimited line `ACTION|p1|p2|p3|p4`; result line in `output.txt`.

### Actions actually implemented

| Action | Params | Behavior today | Outputs |
|---|---|---|---|
| `CHECK_BALANCE` | `p1=email` | `SELECT CONCAT(ROUND(a.balance,2)) FROM accounts a JOIN users u ON a.user_id=u.id WHERE u.email='…'` | `1000.00` · `ERROR|ACCOUNT_NOT_FOUND` |
| `TRANSFER` | `p1=sender email`, `p2=target email`, `p3=amount` | inside one transaction: `SELECT … FOR UPDATE` sender, resolve target, sufficiency check, debit + credit, two `ledger` inserts, then commit/rollback | `SUCCESS|TRANSFER_OK` · `ERROR|INSUFFICIENT_FUNDS` · `ERROR|ACCOUNT_NOT_FOUND` · `ERROR|TARGET_NOT_FOUND` |
| `RECONCILE` | — | lists accounts where `accounts.balance <> SUM(ledger)` (CREDIT − DEBIT) | `SUCCESS|RECONCILED` · `ERROR|MISMATCH\|acct\|balance\|ledger` |

### What is NOT there (the gap vs. the spec)

- [x] **Atomic transaction**: `TRANSFER` runs inside `SQL_BEGIN` … `SQL_COMMIT`, with `SQL_ROLLBACK` on every failure path. The bridge (`cobol/src/sql_bridge.c`) holds a persistent connection for the transaction span; plain `SQL_EXECUTE` still connects per call.
- [x] **Ledger entry**: two rows (DEBIT sender, CREDIT target, shared `txn_ref`) inserted within the same transaction.
- [x] **Row locking**: the sender account is read `SELECT … FOR UPDATE` before the balance check.
- [x] **Balance/ledger reconciliation**: `RECONCILE` reports any account whose stored balance differs from its ledger sum.
- [ ] Amounts are passed as trimmed text and injected into SQL directly (no server-side bind/prepared statement).

### Tests

- `tests/test_ledger_atomic.sh` — happy path writes exactly two ledger rows with one `txn_ref` and moves money, and records a `TRANSFER` row in `audit_trail` inside the same transaction; insufficient funds, unknown target, and unknown sender each roll back with zero ledger rows and untouched balances.
- `tests/test_reconciliation.sh` — `RECONCILE` is green on a fresh ledger-consistent state and after a real transfer; it flags a drifted balance and a mismatched ledger sum; a rolled-back transfer leaves no drift.
- Both wired into `ci.sh`.

## Code style (enforced today)

- Match by exact-length substring on the action field; never `FUNCTION TRIM(...) = "literal"` (see `CODING_STANDARDS.md`).
- All JSON-free, pipe-delimited output; one line to `output.txt`.
- Helper paragraphs `PERFORM`ed must not `GOBACK` and must not fall through (`EXIT PARAGRAPH.`).

## Open questions

- **Resolved** (ADR-free, chosen in Phase 1): transaction control is exposed as `SQL_BEGIN`/`SQL_COMMIT`/`SQL_ROLLBACK` verbs on the bridge, sharing a persistent connection for the transaction span.
- Remaining scope: enforce balance/ledger reconciliation on read (`CHECK_BALANCE` could assert `accounts.balance == SUM(ledger)`), and move to server-side parameter binding instead of string interpolation.
