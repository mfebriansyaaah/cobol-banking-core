# Assertion-count baseline enforced by CI

Status: accepted
Date: 2026-10-16
Phase: Test quality & coverage audit (FASE C).

## Context

`ci.sh` only failed on failing assertions; it never checked how many
assertions ran. The audit proved the gap was real, not theoretical: at the
time, the live suites reported 584 shell passes while `docs/STATUS.md` claimed
568 in one place and its own per-suite table summed to 559 — stale numbers no
check could catch. Deleting assertions (or silently losing them) lowered the
count while CI stayed green.

## Decision

- `tests/baseline_counts.txt` records the expected passing assertions per
  suite (42 shell runs, including both end-to-end modes, plus the gateway
  total): shell 584, gateway 98, full run 682.
- `ci.sh` records each suite's actual pass count during the run (one line per
  step, plus the gateway total derived from the runner summary) and a final
  step, `tests/baseline_check.sh`, fails on any mismatch or any unlisted
  suite — in either direction.
- `tests/status_check.sh` additionally recomputes the three headline numbers
  in `docs/STATUS.md` from the manifest, so the documented totals cannot drift
  from what CI runs.

## Consequences

- Coverage can only shrink deliberately: changing an assertion count requires
  updating the manifest and `docs/STATUS.md` in the same change, which the
  relevant experts review.
- A genuinely flaky count (a suite whose pass total varies run to run) would
  fail the baseline step loudly instead of hiding — none exists today.
