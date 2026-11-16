# Dataset Decision (R-03)

- Date: 2026-11-16 (draft; final on R-02 green + G-01 sign-off)
- Deciders: OWNER + CURATOR + SEC (see `docs/OWNERSHIP.md`)

## Checklist

- [ ] `docs/DATASET_LICENSE_APPROVAL.md` signed (G-01) — **BLOCKED: awaiting owner/legal**
- [x] G-02/G-03/G-04 DONE; no personal emails in history export; no live secrets
- [x] S-01/S-02/S-03 DONE; tests pass
- [x] C-01…C-06 DONE; quarantine empty (D-14 satisfied, C-04 300/300)
- [x] A-01…A-08 DONE (A-05 split a/b; all merged)
- [ ] R-01 DONE (card drafted; final numbers after R-02)
- [ ] R-02 full matrix green (serial full run in progress)
- [ ] `scripts/export_dataset.sh --profile source` succeeds end-to-end
- [ ] `sha256sum -c SHA256SUMS` succeeds
- [ ] `DATASET_CARD.md` reviewed

## Decision

**PENDING.** Current projection: **Layak dengan Revisi (dataset internal
berlisensi)** once G-01 is signed and R-02 is green. Without G-01 the
dataset is **Tidak Layak** regardless of technical readiness.
