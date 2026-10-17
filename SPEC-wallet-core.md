# Spec: wallet-core

Status: **built** — functional surface, atomic transfer, immutable ledger entries, sender row-lock, and an active balance/ledger reconciliation action.
Last verified against code: 2026-10-10

## Objective (unchanged)

Manage balances and record every cent moving in or out, with absolute data integrity (atomic transactions).

## As-Built (what exists today)

- **Source:** `cobol/src/wallet_core.cob` (program id `wallet_core`).
- **Reachable through:** `cobol/src/main_logic.cob` routes `CHECK_BALANCE` and `TRANSFER` here. Compiled into the single binary by `build.sh`.
- **DB access:** through the C bridge `cobol/src/sql_bridge.c` (`SQL_PREPARE_EXEC` / `SQL_EXECUTE` / `GET_RESULT`) which uses **libmysqlclient**, not ODBC. Database `cobol_db`, connection from the environment (`DB_HOST`/`DB_PORT`/`DB_USER`/`DB_PASS`/`DB_NAME`, with development defaults); no credentials are compiled into the source.
- **I/O:** reads one pipe-delimited line `ACTION|p1|p2|p3|p4`; result line in `output.txt`.

### Actions actually implemented

| Action | Params | Behavior today | Outputs |
|---|---|---|---|
| `CHECK_BALANCE` | `p1=email` | `SELECT CONCAT(c.iso_code, ':', ROUND(a.balance,2), ':', a.status) FROM accounts a JOIN users u ON a.user_id=u.id JOIN currencies c ON c.currency_id=a.currency_id WHERE u.email='…' ORDER BY c.iso_code` (multi-row) | `SUCCESS|BALANCES|USD:1000.00:ACTIVE[;…]` · `ERROR|ACCOUNT_NOT_FOUND` · `ERROR|FORBIDDEN` |
| `TRANSFER` | `p1=sender email`, `p2=target email`, `p3=amount`, `p4=idempotency key` (required by the gateway; unique per sender), `p5=fromCurrency`, `p6=toCurrency` (optional) | inside one transaction: both accounts must be `ACTIVE` and both currencies enabled, else rejected; a multi-account (multi-currency) sender/recipient must pin `p5`/`p6` (else `ERROR|AMBIGUOUS_ACCOUNT`); the amount must be a positive decimal whose fraction digits fit the sender currency's precision (0–4, the schema maximum); optional per-transaction and rolling 24h caps in whole sender-currency units (malformed settings fail closed); replay if the key already committed for this sender (`pending_transactions`), else resolve both accounts (optionally pinned by `p5`/`p6` ISO currency) and lock both rows in one `ORDER BY account_id ... FOR UPDATE` (deadlock-free), sufficiency check, one `journal_entries` row (source `TRANSFER`, actor = sender, pinned through `@jid`), debit + credit, two `ledger` inserts linked to the journal (the CREDIT row snapshots the applied FX rate; cross-currency uses the direct rate or the inverse pair's reciprocal, rounded to each currency's precision), a pre-commit balanced-leg verification (exactly one DEBIT and one CREDIT agreeing through the rate, either direction), a journal-linked audit row (detail = `to:amount:currency`), and the intent marked `COMMITTED`, then commit/rollback; stale intents are archived past a retention window | `SUCCESS|TRANSFER_OK` · `ERROR|ACCOUNT_NOT_FOUND` · `ERROR|TARGET_NOT_FOUND` · `ERROR|ACCOUNT_FROZEN` · `ERROR|ACCOUNT_CLOSED` · `ERROR|CURRENCY_INACTIVE` · `ERROR|AMBIGUOUS_ACCOUNT` · `ERROR|INSUFFICIENT_FUNDS` · `ERROR|LIMIT_EXCEEDED` · `ERROR|DAILY_LIMIT_EXCEEDED` · `ERROR|TRANSFER_IN_PROGRESS` · `ERROR|INVALID_AMOUNT` · `ERROR|RATE_NOT_FOUND` · `ERROR|DB_ERROR` · `ERROR|DB_BUSY` |
| `RECONCILE` | — | lists accounts where `accounts.balance <> SUM(ledger)` (CREDIT − DEBIT) | `SUCCESS|RECONCILED` · `ERROR|MISMATCH\|acct\|balance\|ledger` |
| `REVERSE_TRANSFER` | `p1=ref`, `p2=actor` (SUPER_ADMIN), `p3=sender` (opt) | one-time compensating reversal: reads the original `ledger` DEBIT/CREDIT rows (scoped by `from_email`), locks both accounts, credits the sender and debits the target (which must still hold the credited amount), writes two opposite `ledger` rows (rate snapshotted, linked to the new journal) and a `transfer_reversals` marker (per `orig_ref`+`from_email`), opens its own `journal_entries` row (source `REVERSAL`), a journal-linked audit row, and the same pre-commit balanced-leg verification, then commits; a shared ref without `sender` is `ERROR|AMBIGUOUS_TRANSACTION` | `SUCCESS|TRANSFER_REVERSED` · `ERROR|FORBIDDEN` · `ERROR|UNKNOWN_TRANSACTION` · `ERROR|AMBIGUOUS_TRANSACTION` · `ERROR|ALREADY_REVERSED` · `ERROR|INSUFFICIENT_FUNDS` · `ERROR|REVERSAL_FAILED` |
| `TX_STATUS` | `p1=ref`, `p2=actor` (owner or admin), `p3=sender` (optional, admin) | reads `pending_transactions` for the reference and reports `COMMITTED`/`PENDING`/`REVERSED` with the parties and amount; an admin may filter by sender, otherwise the newest by id is returned | `SUCCESS|TRANSFER\|<status>\|<from>\|<to>\|<amount>` · `ERROR|UNKNOWN_TRANSACTION` |

### What is NOT there (the gap vs. the spec)

- [x] **Atomic transaction**: `TRANSFER` runs inside `SQL_BEGIN` … `SQL_COMMIT`, with `SQL_ROLLBACK` on every failure path. The bridge (`cobol/src/sql_bridge.c`) holds a persistent connection for the transaction span; plain `SQL_EXECUTE` still connects per call.
- [x] **Ledger entry**: two rows (DEBIT sender, CREDIT target, shared `txn_ref`) inserted within the same transaction.
- [x] **Row locking**: the sender account is read `SELECT … FOR UPDATE` before the balance check.
- [x] **Balance/ledger reconciliation**: `RECONCILE` reports any account whose stored balance differs from its ledger sum.
- [x] **Idempotency**: an optional key (`p4`) makes `TRANSFER` replay-safe — a repeated key returns the prior success without moving money again; the intent is recorded in `pending_transactions` (`PENDING`→`COMMITTED`, rolled back on failure).
- [x] **Server-side binding**: the transfer path (lock, debit/credit, ledger inserts, audit, intent) runs through `SQL_PREPARE_EXEC` / `SQL_PREPARE_EXEC_LOCK` / `SQL_PREPARE_EXEC_ROWS`. The only interpolation left is the retention housekeeping (`pending_transactions` archive/prune), which embeds the env-supplied day count after guarding it to a leading digit.

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
- Reconciliation is covered by the dedicated `RECONCILE` action (not by `CHECK_BALANCE`, which still reads `accounts.balance` directly).
- Remaining scope: bind the retention-housekeeping day count as a server-side parameter instead of interpolating it (see `SPEC-auth-identity.md` for the remaining `auth_core` escaped statements).
