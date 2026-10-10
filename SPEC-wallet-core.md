# Spec: wallet-core

Status: **partially built** — functional surface exists and passes tests; the atomic/ledger guarantees the original spec demanded do **not** exist yet.
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
| `TRANSFER` | `p1=sender email`, `p2=target email`, `p3=amount` | precheck balance, then `UPDATE accounts SET balance = balance ± amount` on each side | `SUCCESS|TRANSFER_OK` · `ERROR|INSUFFICIENT_FUNDS` · `ERROR|ACCOUNT_NOT_FOUND` · `ERROR|TARGET_NOT_FOUND` |

### What is NOT there (the gap vs. the spec)

- [ ] **No atomic transaction**: no `BEGIN`/`COMMIT`/`ROLLBACK`. Each `UPDATE` autocommits; a failure between the two updates leaves half a transfer.
- [ ] **No ledger entry**: the `ledger` table is never written. `accounts.balance` changes with no immutable trail.
- [ ] **No row locking**: no `SELECT … FOR UPDATE`; two concurrent transfers can double-spend.
- [ ] **No balance/ledger reconciliation**; `accounts.balance` is the only source of truth.
- [ ] Amounts are passed as trimmed text and injected into SQL directly (no server-side bind/prepared statement).

### Where the missing logic already exists (do not duplicate)

`cobol/src/auth_identity.cob` **already contains** an atomic `TRANSFER`: `EXEC SQL SET AUTOCOMMIT = 0`, ledger `INSERT` for both sides, then `COMMIT` / `ROLLBACK` (see `PROCESS-TRANSFER`). It is written for the ODBC path and is **not compiled** by `build.sh` and not routed by `main_logic`. Consolidation means porting that logic into `wallet_core.cob` (via the existing bridge) rather than writing it anew — see "Open questions".

## To add (ordered)

1. Wrap the two `UPDATE`s (and the new ledger inserts) in a real transaction; the bridge currently exposes single statements only, so `sql_bridge.c` needs `BEGIN`/`COMMIT`/`ROLLBACK` support or a multi-statement execute call.
2. Write `ledger` rows for debit and credit before/with the balance update, matching `database/schema.sql` columns (`txn_ref`, `account_id`, `amount`, `type`, `currency_id`, `description`).
3. Row-level lock the sender account (`SELECT … FOR UPDATE`) to remove the double-spend window.
4. `test_atomic_txn.sh` to extend: force a mid-transfer failure and assert no balance change + no ledger rows.

## Code style (enforced today)

- Match by exact-length substring on the action field; never `FUNCTION TRIM(...) = "literal"` (see `CODING_STANDARDS.md`).
- All JSON-free, pipe-delimited output; one line to `output.txt`.
- Helper paragraphs `PERFORM`ed must not `GOBACK` and must not fall through (`EXIT PARAGRAPH.`).

## Open questions

- Consolidate into `wallet_core.cob`, or wire `auth_identity.cob` as the ledger module and make `wallet_core` a thin façade? Consolidation must not break the 18 green tests.
- Bridge design for transactions: expose `BEGIN`/`COMMIT`/`ROLLBACK` verbs, or a single "execute batch" call.
