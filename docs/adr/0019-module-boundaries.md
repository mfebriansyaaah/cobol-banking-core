# ADR 0019: Module boundaries (dependency rules, size budget)

## Status

Accepted (arch9 WP-24).

## Context

Fourteen COBOL modules exceed 1.000 lines (up to 1.635) and several gateway
route files bundle unrelated domains. Copybooks are shared, but nothing
stops a domain module from CALLing sideways into another domain, or
`middleware/src` from importing `middleware/services` directly (bypassing
the adapters layer that owns provider policy). ADR-0010 fixes the
transaction direction (zero-transaction callees); the general dependency
direction is still reviewer-enforced.

## Decision

- Dependency rule, enforced by `scripts/check_dependencies.mjs`:
  `middleware/src → middleware/adapters → middleware/services`;
  `middleware/contract` imports no runtime; COBOL domain modules CALL only
  through the recorded allowlist (`manifest/cobol_calls.json`), with the
  transaction direction from ADR-0010 unchanged.
- Size budget: COBOL modules stay at or under 1.000 lines (A6 gate;
  WP-24 splits: `wallet_transfer`, `card`, `loan`, `collection`, `deposit`
  families); copybooks stay limited to shared kernel concerns (trim,
  validate, result, txn, state, audit, idem, SQL exec wrappers).
- New modules follow the module-split call contract (ADR-0010) and the
  extraction playbook (ADR-0009); dispatch uses longest-prefix, so a split
  that keeps the old action prefix must move the actions to a new prefix.

## Consequences

- Zero dependency cycles; a change in one domain cannot silently reach
  another. The A6 allowlist burns down to zero as splits land.
- Alternatives rejected: microservice split (no boundary or contract
  stability yet; a monolith with enforced boundaries is cheaper to fix),
  generic SQL/state builder copybooks (explicit paragraphs stay auditable
  by juniors).
