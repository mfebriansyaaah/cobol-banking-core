# Dataset Decision (R-03)

- Date: 2026-11-16 (draft; final on R-02 green + G-01 sign-off)
- Deciders: OWNER + CURATOR + SEC (see `docs/OWNERSHIP.md`)

## Checklist

- [x] `docs/DATASET_LICENSE_APPROVAL.md` signed (G-01) — typed owner approval, 2026-11-16, internal + limited commercial
- [x] G-02/G-03/G-04 DONE; no personal emails in history export; no live secrets
- [x] S-01/S-02/S-03 DONE; tests pass
- [x] C-01…C-06 DONE; quarantine empty (D-14 satisfied, C-04 300/300)
- [x] A-01…A-08 DONE (A-05 split a/b; all merged)
- [x] R-01 DONE (card drafted with final technical evidence)
- [ ] R-02 full matrix green (all gates green except premerge 4-shard `payment_race` flake; serial full green twice)
- [ ] `scripts/export_dataset.sh --profile source` run on this branch with the real approval (verification in progress)
- [x] `sha256sum -c SHA256SUMS` succeeds (830 files, no excluded paths)
- [x] `DATASET_CARD.md` reviewed; residual premerge flake documented

## Decision

**PENDING R-02.** G-01 is satisfied by the typed owner approval above.
The projection is **Layak dengan Revisi (dataset internal berlisensi)**
once the known 4-shard `payment_race` test flake is stabilized (or the
flake is explicitly waived with owner sign-off). Until then R-03 stays
open.
