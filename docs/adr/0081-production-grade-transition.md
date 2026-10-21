# 0081 - Production-grade transition and the COBOL floor

Status: Proposed
Date: 2026-10-21
Deciders: repository owner, architecture, security, finance, operations
Related: `PRD_Enterprise.md`, `docs/PRODUCTION_GRADE_PLAN.md`,
`CODING_STANDARDS.md`, `docs/TRACEABILITY.md`

## Context

The October 2026 volume sprint produced a large generated reference-data
module: 211 entities, 1.055 actions, 211 smoke suites, and 53.394 net
COBOL lines. The repository reached 109.344 raw lines / 101.200 net lines,
with 64.703 COBOL raw / 62.544 COBOL net (9.150 curated / 53.394 generated net).

The volume milestone is useful as a lab artifact and as evidence that the
generator, build, and smoke harness scale. It is not a production data model,
a compliance claim, or a reason to keep 211 near-identical CRUD modules. The
codebase needs a production-grade transition without losing the COBOL net
floor that the owner set.

## Decision

1. **COBOL net >= 60.000 is a floor, not a target.** Every change reports the
   net COBOL delta. The floor is enforced by `scripts/loc_report.sh
   --check-floor`.
2. **Add before delete.** Replacement curated code lands before generated code
   is removed. A deletion of 1.000 net COBOL lines or more requires
   replacement lines in the same change or an approved follow-up.
3. **Generated code is isolated and tagged.** Generated output moves to
   `cobol/src/generated/`, carries an `@generated` marker, and is excluded
   from the production coverage target.
4. **Curated share ratchets upward.** The merge gate starts at 40% curated
   COBOL and rises to 100%. Generated share must not increase.
5. **Reference data is consolidated.** The 211 generated entities become a
   generic reference-data model (`ref_type`, `ref_value`, versioning,
   translations, hierarchy, audit) plus a small set of curated domains.
6. **Production readiness is evidence-based.** Full CI, coverage, security,
   reliability, observability, data governance, and owner approvals are
   required; LOC alone is never a readiness claim.

## Consequences

- The refactor may temporarily increase total code before generated blocks are
  removed. That is expected; the floor and the curated-share ratchet are the
  controls.
- Some generated SQL, JavaScript, shell, and COBOL will be deleted. Total code
  may fall, but must remain at or above 100.000 net unless the owner approves
  a different target.
- The 100k/60k milestone is tagged as a historical artifact and is not cited
  as production evidence.
- The production roadmap, workstreams, phases, and gates are maintained in
  `docs/PRODUCTION_GRADE_PLAN.md`.
- Gate 0 owners still decide jurisdiction, runtime, SLO/RPO/RTO, and
  compliance scope; this ADR does not grant any of those.

## Alternatives considered

- **Keep the 211 entities and harden each one.** Rejected as the primary path:
  it preserves repetition and a weak data model. A small number of curated
  domains may keep specialized tables, but not 211 copies.
- **Delete generated code first and rebuild later.** Rejected: it breaks the
  COBOL floor and the no-net-loss rule.
- **Treat the volume milestone as production-ready.** Rejected: size and CI
  green are not production evidence, and the repository is explicitly a
  prototype.
