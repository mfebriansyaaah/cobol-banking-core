# Password policy: deny list and bounded history

Status: accepted
Date: 2026-10-20
Phase: Gate 2 (access control). Strengthens `A-P0-ACCESS` credential handling.

## Context

Password changes and resets already enforce a minimum length and rehash with
PBKDF2. Two gaps remain:

1. A user can set a widely used password (`password`, `12345678`, ...). The
   deny list is a standard control and does not need a jurisdiction-specific
   decision.
2. A user can cycle back to a recent password immediately after changing it,
   which defeats the purpose of forcing a change.

Both are credential policy, not business logic that depends on the customer's
jurisdiction, so they can be implemented now. The deny list itself is
owner-controlled data: the seed in the migration is a small development
placeholder, not an approved production list.

## Decision

1. **The deny list is data.** `password_blocklist` stores the SHA-256 hex of
   the lowercased password, so matching is case-insensitive. `REQUEST_SIGNUP`,
   `CHANGE_PASSWORD`, and `RESET_PASSWORD` refuse a blocklisted value with
   `PASSWORD_BLOCKED`. The production list is supplied by the accountable
   owner (data change, reviewed like a migration); the seed is a development
   placeholder and is documented as such.
2. **History is bounded and configurable.** `password_history` records the
   hash of each password a user sets. A change or reset refuses a value that
   matches the current password or any of the last
   `PASSWORD_HISTORY_COUNT` entries (default 5; `0` disables the check) with
   `PASSWORD_REUSED`. Recording and trimming happen inside the same
   transaction as the password update, so a failure rolls the change back.
   The trim keeps exactly the configured number of rows, so the table cannot
   grow without bound.
3. **The policy runs before hashing.** The candidate is checked before the
   expensive KDF, so a refused password does not cost a PBKDF2 derivation and
   cannot follow a partially applied flow.
4. **Database failures fail closed.** A policy query error returns `DB_ERROR`
   rather than accepting the password.
5. **The check uses the lowercased candidate.** Case-only variations of a
   blocklisted password are refused; the same normalization is used for the
   hash stored in the deny list, so the two sides always agree.

## Why the history is not a compliance claim

`PASSWORD_HISTORY_COUNT=5` is a configurable default, not a regulator-approved
number. The ADR records the mechanism; the value is a policy knob an owner can
change without a code change. The deny-list contents are likewise owner data.

## Consequences

- Migration `0044`: `password_history` and `password_blocklist` (with the
  development seed), folded into the schema baseline.
- A small C helper (`sha256_hex_lower`) for the normalised deny-list key; it
  writes exactly 64 bytes and no terminator, per the buffer contract.
- Two error codes, `PASSWORD_BLOCKED` and `PASSWORD_REUSED` (HTTP 400), added
  to the gateway contract.
- A new suite (`tests/test_password_policy.sh`) covers signup/change/reset,
  case-insensitivity, the current-password refusal, the bound, the disable
  switch, and the trim.
- `A-P0-ACCESS` stays `partial`: the review cadence and owner sign-off remain
  Gate 0 decisions.
