# Architecture Decision Records

Decisions with lasting structural impact. Each record states its own
status (`Accepted`, `Deferred`, ...); read the status line before
relying on a decision — deferred records are explicitly *not* in force.

| ADR | Decision | Status |
| --- | --- | --- |
| [0001-sql-bridge](0001-sql-bridge.md) | SQL bridge with max 6 binds | Accepted |
| [0002-concurrency-model](0002-concurrency-model.md) | Concurrency model for the COBOL core | Accepted |
| [0003-audit-model](0003-audit-model.md) | Audit model with old/new value | Accepted |
| [0004-result-buffer](0004-result-buffer.md) | 16KB result buffer fails loud, never silent-cuts (PR-061) | Accepted |
| [0005-request-tracing](0005-request-tracing.md) | Correlation-id request tracing instead of distributed tracing | Accepted |
| [0006-layer-boundaries](0006-layer-boundaries.md) | Layer boundaries, Option A (pragmatic signals) | Accepted |
| [0007-generated-docs](0007-generated-docs.md) | Generated documentation as source of truth | Accepted |
| [0008-idempotency-protocol](0008-idempotency-protocol.md) | Idempotency-key protocol (claim / replay / takeover) | Accepted |
| [0009-extraction-playbook](0009-extraction-playbook.md) | Module-extraction playbook (resolve / JOIN / passthrough) | Accepted |
| [0010-module-split-call-contract](0010-module-split-call-contract.md) | Module split via internal CALL inside one transaction (PR-05–09) | Accepted |
| [0011-migration-baseline-v2](0011-migration-baseline-v2.md) | Migration baseline v2 | Deferred (2026-11-16) |
| [0012-clone-template-freeze](0012-clone-template-freeze.md) | Clone-template freeze, no generator skeleton (DRY-08) | Accepted |
| [0013-idempotency-generalization-done](0013-idempotency-generalization-done.md) | Idempotency generalization complete (DRY-07) | Accepted |
