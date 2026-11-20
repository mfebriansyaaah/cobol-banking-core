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
| `account_core` | 0.95→n/a | L2 | **Refactored (PR-2a).** Template CALC/DELETE replaced by domain lifecycle ACTIVATE/FREEZE/UNFREEZE/CLOSE with guards; no longer clone-shaped (dropped from `clone_baseline.txt`); business-linked via `account` table; PILOT. |
| `compliance_calendar_core` | 0.95→n/a | L2 | **Refactored (PR-2a).** CALC/DELETE replaced by SCHEDULE (due-date)/COMPLETE (capped)/ESCALATE (overdue+reason)/CLOSE (no-pending+reason); no longer clone-shaped; business-linked via `compliance_calendar`; PILOT. |
| `notification_template_core` | 0.95→n/a | L2 | **Refactored (PR-2b).** CALC/DELETE replaced by PREVIEW (rendered sample)/VERSION (publish+increment)/DEACTIVATE (reason-required); no longer clone-shaped; business-linked via `ntf_template_config`; PILOT. |
| `report_schedule_core` | 0.95→n/a | L2 | **Refactored (PR-2b).** CALC/DELETE replaced by ENABLE/DISABLE (window guards)/RUN_NOW (capped at max); no longer clone-shaped; business-linked via `rpt_schedule_config`; PILOT. |
| `sla_tracker_core` | 0.95→n/a | L2 | **Refactored (PR-2c).** CALC/DELETE replaced by BREACH (actual-vs-target check)/ESCALATE (breached+reason)/CLOSE (reason-required); UPDATE carries target/actual; no longer clone-shaped; business-linked via `sla_tracker`; PILOT. |
| `fixed_asset_core` | 0.67 | L2 | **Refactored (PR-2c).** Generic DELETE removed (DISPOSE owns the terminal state with gain/loss + GL); CALC kept as the documented OPEN→ACTIVE activation path, DEPRECIATE remains the straight-line path; business-linked via `fixed_asset*`; PILOT. |
| `merchant_settlement_core` | 0.68→n/a | L2 | **Refactored (PR-2d).** Generic CREATE removed (OPEN creates batches) and DELETE removed (CANCEL owns terminal state); fee/calc/post/settle lifecycle and GL link retained; no longer clone-shaped; business-linked via `merchant_transaction`; PILOT. |
| `tax_management_core` | 0.66→n/a | L2 | **Refactored (PR-2d).** Generic CREATE/UPDATE/DELETE removed; rule engine (RULE_CREATE/UPDATE/GET/LIST + CALC/POST/REVERSE/REPORT) is the whole surface; enable/disable stays on RULE_UPDATE P4 (no duplicate action); no longer clone-shaped; business-linked via `tax_withholding_entry`; PILOT. |

The two reviewer notes emitted by `check_clone_budget.mjs` are also resolved:

- `collateral_core` is 0.77 clone-shaped but **L2-linked**; its collateral
  register/appraise/pledge/repossess/dispose lifecycle is business-specific.
  Keep the link; do not treat it as a retire candidate.
- `loan_core` is 0.62 clone-shaped but **L3-linked**; its disbursement/repay
  paths are money paths with DB and mutation coverage. Keep the link.

Evidence: `tests/clone_baseline.txt` (refreshed line counts and similarities),
`manifest/module_quality.json` (recommended flag and clone similarity), and
the per-module DB suites named in `docs/MODULE_QUALITY.md`.
