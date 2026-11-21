# ADR 0018: Data ownership and FK policy (email-keyed tables)

## Status

Accepted (arch9 WP-20).

## Context

The schema has 466 baseline tables (1.549 full) with only 87 foreign keys.
Many domain tables store `customer_email` / `account_email` / `owner_email`
with no FK to `users(id)`: an email change or user delete orphans product
rows, and ownership checks rely on string equality instead of identity.
There are also two account models: `accounts` (wallet/ledger, the money
path) and the legacy `account` table behind `/accounts*` CRUD, which carries
balances disconnected from the ledger. GL journals link from domain postings
via `SELECT id FROM gl_journal WHERE description = ?`, but `description` is
not unique — two journals with the same description can be confused, and
concurrent posts can double-link.

## Decision

- Every table gets an entry in `manifest/table_ownership.json`: owner area,
  PII columns, retention, FK policy (or a recorded exception). The schema
  gate fails new tables without one.
- Core money/ops/compliance tables gain a `user_id INT` FK to `users(id)`
  (`RESTRICT` when zero orphans, `SET NULL` otherwise); the email columns
  stay for display and backward compatibility. Tables keyed by
  `customer_ref`-style refs are documented first; FKs follow once ref
  semantics are confirmed. Email change is proven by test to keep products
  accessible.
- `gl_journal` gains a unique `txn_ref`; all domain postings link by
  `gl_journal_id`/ref, never by `description`.
- Legacy `account` (`account_core`, `/accounts*`) is deprecated, not merged:
  merging risks balance semantics; deprecation headers plus docs point new
  development at `accounts`/ledger.

## Consequences

- Migration is gradual (add column → backfill → constrain → switch reads),
  with orphan reports kept in evidence; no data is deleted by migration.
- `check_architecture.mjs` rule A4 plus the ownership gate prevent new
  description-links and ownerless tables.
- Alternatives rejected: big-bang email→user_id rewrite (too risky without
  dual-write), merging the two account models (shadow-ledger risk; see
  decision above).
