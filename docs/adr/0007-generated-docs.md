# ADR 0007: Generated documentation as source of truth

## Status

Accepted.

## Context

Hand-maintained docs rot: `docs/COMPLEXITY_BASELINE.md` still showed
605 modules and 419,381 lines from 2026-11-03 after the tree had moved
on (71 modules), and the README test table carried a stale date, stale
counts, and missing suites. Stale numbers are worse than no numbers —
they certify a state that no longer exists.

## Decision

Numbers that a script can compute are computed, committed, and gated;
prose explains, never counts:

- `docs/COMPLEXITY_BASELINE.md` ← `node scripts/audit_complexity.mjs --write`
  (gated by `--check`, wired into `check_docs.mjs`).
- README test table ← `node scripts/build_test_table.mjs --write`
  (rendered from `tests/baseline_counts.txt`, gated by `check_docs.mjs`).
- README stats + `docs/STATUS.md` + `docs/MODULE_INDEX.md` ←
  `node scripts/docs_stats.mjs --write` (gated by `check_docs.mjs`).
- `manifest/*.json`, `tier1_links.json`, domain/backlog registries ←
  their `scripts/* --write` generators (gated by the matching
  `check_*.mjs`).
- Regeneration is always deliberate (`--write` after review); CI only
  ever checks. A stale file fails the gate with the exact regen command.

## Consequences

- `git diff` on a docs PR shows whether numbers moved and why; reviewers
  never trust a hand-typed count again.
- Generators must be deterministic (no timestamps inside compared output
  except the explicitly excluded `generatedAt`/`commit` header lines).
- The `docs/archive/` records are exempt by design: frozen history is
  byte-identical by policy, and `lint:md` skips the directory.
