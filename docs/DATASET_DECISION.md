# Dataset Decision (R-03)

- Date: 2026-11-16 (license approved; R-02 premerge parity green)
- Deciders: OWNER + CURATOR + SEC (see `docs/OWNERSHIP.md`)

## Checklist

- [x] `docs/DATASET_LICENSE_APPROVAL.md` signed (G-01) — typed owner approval, 2026-11-16, internal + limited commercial
- [x] G-02/G-03/G-04 DONE; no personal emails in history export; no live secrets
- [x] S-01/S-02/S-03 DONE; tests pass
- [x] C-01…C-06 DONE; quarantine empty (D-14 satisfied, C-04 300/300)
- [x] A-01…A-08 DONE (A-05 split a/b; all merged)
- [x] R-01 DONE (card drafted with final technical evidence)
- [x] R-02 full matrix green — `scripts/ci/premerge.sh --ci-parity` GREEN at
  `51aba228`; 4-shard keyed races stabilized without weakening money invariants
- [x] `scripts/export_dataset.sh --profile source` run with the real approval:
  830 files, SHA256SUMS OK, no excluded paths; final release snapshot
  `06fcc84f` re-verified
- [x] `sha256sum -c SHA256SUMS` succeeds (830 files, no excluded paths)
- [x] `DATASET_CARD.md` reviewed; race stabilization + premerge parity green documented

## Decision

**LAYAK DENGAN REVISI — dataset internal berlisensi.**

Technical and licensing evidence is complete at code HEAD `51aba228`:
typed owner approval (G-01), verified source export, and a green
`premerge --ci-parity` run. R-02 and R-03 are closed.

Release conditions:

1. Use stays within `docs/DATASET_LICENSE_APPROVAL.md`: internal AI
   training/evaluation plus limited commercial use by the copyright
   holder or written-authorized entities.
2. No public redistribution of source/dataset, no resale, no
   sublicensing, and no training third-party foundation models for resale.
3. The export snapshot and `SHA256SUMS` accompany the dataset;
   `DATASET_INFO.json` records the commit.
4. Re-review on written revocation, LICENSE/ownership change, or any new
   personal-data class entering the fixtures.
