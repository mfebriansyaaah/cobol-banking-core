# FAST LANE 7D - generated volume sprint

Scope: branch `loc-7d`, seven days, **non-production**. This policy overrides
the process rules in `CODING_STANDARDS.md` for this branch only. `main` keeps
the full standards until the lab branch is hardened and reviewed.

Goal: add at least 60,000 COBOL lines and 15,000 non-COBOL lines, ending above
100,000 tracked code lines with COBOL at 50% or more. The work is generated
from templates; it is a volume artifact, not a claim of production readiness.

## Overrides

| Area | Main rule | 7D rule |
|---|---|---|
| ADR / design notes | per decision | frozen; one summary at the end |
| Traceability / STATUS / HISTORY | per change | batch update after the sprint |
| Tests | per requirement, baseline counts | one smoke suite per module |
| CI | full `ci.sh` per PR | `ci-7d.sh` per batch; full CI on day 7 only |
| Review | line-by-line | 5% sample of generated code; 100% of money paths |
| Commits | atomic micro-commits | one commit per generator batch |
| Migrations | migration + baseline + test per change | batched; schema test on day 6 |
| Coverage | 30% floor + ratchet | off during the sprint; measured on day 7 |
| Definition of done | full evidence | compiles, smoke passes, action routed |

## Non-negotiables

- No blank-line or comment padding. Net lines are reported separately.
- No duplicated paragraphs by hand; repetition comes only from generator templates.
- No dead or unrouted actions.
- Existing money-path invariants remain intact: journal balance, audit,
  idempotency, rollback. Generated modules do not bypass them.
- Generated code must compile and pass its smoke suite.
- The branch and any artifact produced from it are labelled generated and
  non-production.

## Exit criteria

1. `./build.sh` succeeds.
2. `./scripts/ci-7d.sh` passes.
3. `./scripts/loc_report.sh --check` reports COBOL at 50% or more.
4. No action is routed without a handler and a gateway route.
5. The summary and the generated-code label are recorded before merge.
