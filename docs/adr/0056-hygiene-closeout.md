# Hygiene close-out: hook verification and deliberate duplication

Status: accepted
Date: 2026-10-17
Phase: CI/engineering hygiene audit (FASE D).

## Context

Two hygiene items needed a durable home rather than a fix. First, the
commit-msg hook had silently drifted: the installed copy predated the
AI-attribution guard, so the check that was supposed to protect authorship
was not running on this clone — caught only because the new `--check` mode
compares bytes. Second, the triplicated shell helpers (`q`/`run`/`check` in
every suite) and the missing `set -e` look like tech debt but are a deliberate
robustness trade: one shared helper file would couple all 43 suites to a
single point of failure, and counted assertions must never hide behind an
early exit.

## Decision

- `scripts/install-hooks.sh` gains `--check` (byte-compare tracked vs
  installed; names the drifting hook), and `tests/test_hooks.sh` (4 checks)
  pins match-on-clean, tamper detection with a trap-guarded restore, and
  reinstall convergence. The drift found during development was fixed by
  reinstalling.
- Record the self-containment rule as `CODING_STANDARDS.md` 14 (renumbering
  14-18 to 15-19), so a future "deduplicate the helpers" cleanup is judged
  against a written decision, not assumed to be an improvement.

## Consequences

- Hook protection is verified on every CI run instead of assumed per clone.
- Shell 625 -> 629, gateway 104 unchanged; full run 733 assertions.
