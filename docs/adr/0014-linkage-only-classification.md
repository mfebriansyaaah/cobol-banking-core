# ADR 0014: Linkage-only classification

## Status

Accepted.

## Context

The tier model conflates provenance, core linkage, and review strictness.
Tier 2 is labeled "generated" although only 8 modules are clone-shaped; the
rest are independent or diverged. The generator is removed.

## Decision

`linkageLevel` (L0–L3) plus `UTILITY` is the only classification.
`coreModules` is the anchor list. Status remains a review disposition.
Coverage floor applies to L3 only. `recommendedForTraining` requires
ACTIVE/PILOT + L2/L3 + non-clone. The 8 clone-shaped modules are refactored
or retired. `scripts/generate_module.py` is deleted.

## Consequences

Tier fields/files are removed; docs are linkage-only; CI gates key off
linkage; FROZEN/REVIEW modules must be promoted or retired; coverage
measurement focuses on L3.
