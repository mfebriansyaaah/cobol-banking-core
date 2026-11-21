# ADR 0015: Transaction kernel (TXN-BEGIN / TXN-FINISH / TXN-ABORT)

## Status

Accepted (arch9 WP-10).

## Context

302 `CALL "SQL_BEGIN"` sites in `cobol/src/*_core.cob` and `cobol/copy/*.cpy`
never check the result. When `START TRANSACTION` fails while a connection is
still alive, statements keep running in autocommit and a later `SQL_COMMIT`
fails — leaving partially written money movements. Reviewers cannot reliably
catch a missing check across 302 sites, and the per-file balance gate only
checks that BEGIN pairs with COMMIT/ROLLBACK, not that BEGIN succeeded
(same blind spot ADR-0010 documents for CALL edges).

## Decision

All transactions go through the shared kernel in `cobol/copy/common_txn.cpy`:

- `TXN-BEGIN` — issues `SQL_BEGIN`, reads the result, requires
  `SUCCESS|BEGIN`. On failure it sets `STEP-FAIL` and writes
  `ERROR|DB_ERROR` to `LS-OUTPUT-BUFFER`. Host contract: the caller must
  have `WS-RESULT`, `STEP-OK`/`STEP-FAIL`, and `LS-OUTPUT-BUFFER`, and must
  exit the paragraph when `STEP-FAIL` is set.
- `TXN-FINISH` (existing) — commit-checked finalizer, unchanged.
- `TXN-ABORT` — explicit rollback for early exits after a failed write that
  previously fell through to `EXIT PARAGRAPH` without rolling back.

Direct `CALL "SQL_BEGIN"` outside `common_txn.cpy` is forbidden; the A1
architecture gate (`scripts/check_architecture.mjs`) fails it. The only
remaining direct caller is the kernel itself; `cobol/src/sql_bridge.c`
implements (not calls) the entry point.

## Consequences

- Every module migrates to `PERFORM TXN-BEGIN` (WP-10, three waves:
  money-path, domain, ops/report/auth). A migrated file is removed from
  `tests/architecture_sql_begin_allowlist.txt`; deleting the file means zero
  exceptions are allowed.
- Failure injection (`SQL_BRIDGE_TEST_FAIL_BEGIN`) proves a failed BEGIN
  maps to `ERROR|DB_ERROR` with no partial writes.
- Alternatives rejected: a C-level wrapper (hides the failure from COBOL
  control flow), a generic SQL builder (too magical for a junior to audit;
  explicit paragraphs stay greppable).
