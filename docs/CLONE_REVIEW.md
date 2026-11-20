# Clone Review (Phase 2)

This is the Phase 2 disposition record for the eight clone-shaped modules in
`tests/clone_baseline.txt`. The baseline is a ratchet: a new clone-shaped
module cannot appear without review, and an existing module may not become
more similar without a recorded reason.

`source` keeps every module for reproducibility; `train` excludes every
non-recommended module (including all eight below) via
`scripts/train_profile.mjs`.

| Module | Similarity | Link | Decision |
| --- | ---: | --- | --- |
| `account_core` | 0.95 | L0 | **Retain, frozen.** Exact 9-action template clone; no proven core link; excluded from `train`. Refactor only if a real consumer appears. |
| `compliance_calendar_core` | 0.95 | L0 | **Retain, frozen.** Exact clone; regulatory calendar routes/tables are domain-specific but the code shape is template; excluded from `train`. |
| `notification_template_core` | 0.95 | L0 | **Retain, frozen.** Exact clone; notification-template CRUD is a support surface; excluded from `train`. |
| `report_schedule_core` | 0.95 | L0 | **Retain, frozen.** Exact clone; report scheduling is covered by its DB suite; excluded from `train`. |
| `sla_tracker_core` | 0.95 | L0 | **Retain, frozen.** Exact clone; SLA tracking is a support surface; excluded from `train`. |
| `fixed_asset_core` | 0.67 | L0 | **Retain, frozen for now.** Template-shaped but carries a real depreciation/revalue/dispose lifecycle and GL link; keep out of `train` until a core linkage proof or a dedicated refactor exists. |
| `merchant_settlement_core` | 0.68 | L0 | **Retain, frozen for now.** Template-shaped but carries fee/settlement/GL logic; keep out of `train` until the merchant linkage is proven. |
| `tax_management_core` | 0.66 | L0 | **Retain, frozen for now.** Template-shaped but carries tax rule/calc/post/reverse logic; keep out of `train` until the linkage is proven. |

The two reviewer notes emitted by `check_clone_budget.mjs` are also resolved:

- `collateral_core` is 0.77 clone-shaped but **L2-linked**; its collateral
  register/appraise/pledge/repossess/dispose lifecycle is business-specific.
  Keep the link; do not treat it as a retire candidate.
- `loan_core` is 0.62 clone-shaped but **L3-linked**; its disbursement/repay
  paths are money paths with DB and mutation coverage. Keep the link.

Evidence: `tests/clone_baseline.txt` (refreshed line counts and similarities),
`manifest/module_quality.json` (recommended flag and clone similarity), and
the per-module DB suites named in `docs/MODULE_QUALITY.md`.
