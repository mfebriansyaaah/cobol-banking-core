# Integration Backlog

> Generated structure by `scripts/check_integration_completion.mjs`
> (`--write` only adds missing computed-OPEN items; it never modifies
> existing entries). Items close by wiring the missing link (no new
> features) or by WAIVED with an accepted-risk reason + owner. Pure-read
> paragraphs (paged LIST/GET/SUMMARY/AUDIT/VALIDATE with no writes) are
> exempt and not listed: a read needs no core link to be correct. Route
> auth/shape depth stays with check_route_auth and the field-order gate.

| Module status | Modules |
| --- | ---: |
| CONNECTED (no open items) | 0 |
| PARTIAL (open items) | 25 |

Open/in-progress items: 163 of 211 recorded.

| Module | Status | Items |
| --- | --- | ---: |
| `auth_core` | PARTIAL | 22 |
| `auth_password_core` | PARTIAL | 1 |
| `card_core` | PARTIAL | 1 |
| `collateral_core` | PARTIAL | 13 |
| `collection_core` | PARTIAL | 1 |
| `dashboard_core` | PARTIAL | 12 |
| `deposit_core` | PARTIAL | 2 |
| `fee_core` | PARTIAL | 8 |
| `gl_core` | PARTIAL | 7 |
| `identity_core` | PARTIAL | 7 |
| `import_post_core` | PARTIAL | 4 |
| `import_recon_core` | PARTIAL | 7 |
| `loan_core` | PARTIAL | 6 |
| `loan_schedule_core` | PARTIAL | 1 |
| `merchant_core` | PARTIAL | 13 |
| `payment_clearing_core` | PARTIAL | 6 |
| `payment_core` | PARTIAL | 7 |
| `payment_hold_core` | PARTIAL | 4 |
| `payment_instruction_core` | PARTIAL | 12 |
| `payroll_processing_core` | PARTIAL | 13 |
| `statement_core` | PARTIAL | 9 |
| `statement_recon_core` | PARTIAL | 8 |
| `treasury_liquidity_core` | PARTIAL | 6 |
| `user_core` | PARTIAL | 7 |
| `wallet_core` | PARTIAL | 18 |

| Item | Module | Kind | Status | Owner | Reason |
| --- | --- | --- | --- | --- | --- |
| `auth_core:action:outbox-claim-logic` | `auth_core` | action | WAIVED | assistant | Write paragraph with no core link (writes notification_outbox) |
| `auth_core:action:outbox-mark-logic` | `auth_core` | action | WAIVED | assistant | Write paragraph with no core link (writes notification_outbox) |
| `auth_core:action:revoke-access-token-logic` | `auth_core` | action | DONE | assistant | Write paragraph with no core link (writes revoked_access_tokens) |
| `auth_core:action:revoke-user-session-logic` | `auth_core` | action | DONE | assistant | Write paragraph with no core link (writes refresh_sessions) |
| `auth_core:action:store-session-logic` | `auth_core` | action | DONE | assistant | Write paragraph with no core link (writes refresh_families, refresh_sessions) |
| `auth_core:audit:core-reference` | `auth_core` | audit | DONE | assistant | Manual: verify audit rows store a core reference (old/new value + core id); automation cannot prove semantics |
| `auth_core:table:access-review-items` | `auth_core` | table | WAIVED | assistant | Domain table has no core business key or FK into a Tier-1 table |
| `auth_core:table:access-reviews` | `auth_core` | table | WAIVED | assistant | Domain table has no core business key or FK into a Tier-1 table |
| `auth_core:table:audit-trail` | `auth_core` | table | DONE | assistant | Domain table has no core business key or FK into a Tier-1 table |
| `auth_core:table:dual-control-operations` | `auth_core` | table | DONE | assistant | Domain table has no core business key or FK into a Tier-1 table |
| `auth_core:table:known-devices` | `auth_core` | table | DONE | assistant | Domain table has no core business key or FK into a Tier-1 table |
| `auth_core:table:maker-requests` | `auth_core` | table | WAIVED | assistant | Domain table has no core business key or FK into a Tier-1 table |
| `auth_core:table:mfa-backup-codes` | `auth_core` | table | DONE | assistant | Domain table has no core business key or FK into a Tier-1 table |
| `auth_core:table:mfa-recovery-requests` | `auth_core` | table | WAIVED | assistant | Domain table has no core business key or FK into a Tier-1 table |
| `auth_core:table:notification-outbox` | `auth_core` | table | DONE | assistant | Domain table has no core business key or FK into a Tier-1 table |
| `auth_core:table:permissions` | `auth_core` | table | WAIVED | assistant | Domain table has no core business key or FK into a Tier-1 table |
| `auth_core:table:refresh-families` | `auth_core` | table | DONE | assistant | Domain table has no core business key or FK into a Tier-1 table |
| `auth_core:table:refresh-sessions` | `auth_core` | table | DONE | assistant | Domain table has no core business key or FK into a Tier-1 table |
| `auth_core:table:revoked-access-tokens` | `auth_core` | table | DONE | assistant | Domain table has no core business key or FK into a Tier-1 table |
| `auth_core:table:role-permissions` | `auth_core` | table | WAIVED | assistant | Domain table has no core business key or FK into a Tier-1 table |
| `auth_core:table:step-up-policy` | `auth_core` | table | DONE | assistant | Domain table has no core business key or FK into a Tier-1 table |
| `auth_core:table:verification-logs` | `auth_core` | table | DONE | assistant | Domain table has no core business key or FK into a Tier-1 table |
| `auth_password_core:audit:core-reference` | `auth_password_core` | audit | DONE | assistant | Manual: verify audit rows store a core reference (old/new value + core id); automation cannot prove semantics |
| `card_core:audit:core-reference` | `card_core` | audit | OPEN | — | Manual: verify audit rows store a core reference (old/new value + core id); automation cannot prove semantics |
| `collateral_core:action:action-allocate` | `collateral_core` | action | OPEN | — | Write paragraph with no core link (writes collateral_allocation) |
| `collateral_core:action:action-appraise` | `collateral_core` | action | OPEN | — | Write paragraph with no core link (writes collateral, collateral_valuation) |
| `collateral_core:action:action-close` | `collateral_core` | action | OPEN | — | Write paragraph with no core link (writes collateral) |
| `collateral_core:action:action-create` | `collateral_core` | action | OPEN | — | Write paragraph with no core link (writes collateral) |
| `collateral_core:action:action-dispose` | `collateral_core` | action | OPEN | — | Write paragraph with no core link (writes collateral) |
| `collateral_core:action:action-register` | `collateral_core` | action | OPEN | — | Write paragraph with no core link (writes collateral) |
| `collateral_core:action:action-repossess` | `collateral_core` | action | OPEN | — | Write paragraph with no core link (writes collateral) |
| `collateral_core:action:action-revalue` | `collateral_core` | action | OPEN | — | Write paragraph with no core link (writes collateral, collateral_valuation) |
| `collateral_core:action:action-submit` | `collateral_core` | action | OPEN | — | Write paragraph with no core link (writes collateral) |
| `collateral_core:action:action-update` | `collateral_core` | action | OPEN | — | Write paragraph with no core link (writes collateral) |
| `collateral_core:audit:core-reference` | `collateral_core` | audit | OPEN | — | Manual: verify audit rows store a core reference (old/new value + core id); automation cannot prove semantics |
| `collateral_core:table:collateral` | `collateral_core` | table | OPEN | — | Domain table has no core business key or FK into a Tier-1 table |
| `collateral_core:table:collateral-valuation` | `collateral_core` | table | OPEN | — | Domain table has no core business key or FK into a Tier-1 table |
| `collection_core:audit:core-reference` | `collection_core` | audit | OPEN | — | Manual: verify audit rows store a core reference (old/new value + core id); automation cannot prove semantics |
| `dashboard_core:audit:core-reference` | `dashboard_core` | audit | OPEN | — | Manual: verify audit rows store a core reference (old/new value + core id); automation cannot prove semantics |
| `dashboard_core:table:audit-trail` | `dashboard_core` | table | OPEN | — | Domain table has no core business key or FK into a Tier-1 table |
| `dashboard_core:table:dispute-cases` | `dashboard_core` | table | OPEN | — | Domain table has no core business key or FK into a Tier-1 table |
| `dashboard_core:table:import-batch` | `dashboard_core` | table | OPEN | — | Domain table has no core business key or FK into a Tier-1 table |
| `dashboard_core:table:notification-outbox` | `dashboard_core` | table | OPEN | — | Domain table has no core business key or FK into a Tier-1 table |
| `dashboard_core:table:ops-alert` | `dashboard_core` | table | OPEN | — | Domain table has no core business key or FK into a Tier-1 table |
| `dashboard_core:table:payment-policy` | `dashboard_core` | table | OPEN | — | Domain table has no core business key or FK into a Tier-1 table |
| `dashboard_core:table:payment-profile` | `dashboard_core` | table | OPEN | — | Domain table has no core business key or FK into a Tier-1 table |
| `dashboard_core:table:pending-transactions` | `dashboard_core` | table | OPEN | — | Domain table has no core business key or FK into a Tier-1 table |
| `dashboard_core:table:reconciliation-runs` | `dashboard_core` | table | OPEN | — | Domain table has no core business key or FK into a Tier-1 table |
| `dashboard_core:table:report-run` | `dashboard_core` | table | OPEN | — | Domain table has no core business key or FK into a Tier-1 table |
| `dashboard_core:table:report-schedule` | `dashboard_core` | table | OPEN | — | Domain table has no core business key or FK into a Tier-1 table |
| `deposit_core:audit:core-reference` | `deposit_core` | audit | OPEN | — | Manual: verify audit rows store a core reference (old/new value + core id); automation cannot prove semantics |
| `deposit_core:table:days` | `deposit_core` | table | OPEN | — | Domain table has no core business key or FK into a Tier-1 table |
| `fee_core:action:action-vel-profile-create` | `fee_core` | action | OPEN | — | Write paragraph with no core link (writes velocity_profile) |
| `fee_core:action:action-vel-record` | `fee_core` | action | OPEN | — | Write paragraph with no core link (writes used_count, velocity_counter) |
| `fee_core:action:action-vel-record-all-txn` | `fee_core` | action | OPEN | — | Write paragraph with no core link (writes used_count, velocity_counter) |
| `fee_core:audit:core-reference` | `fee_core` | audit | OPEN | — | Manual: verify audit rows store a core reference (old/new value + core id); automation cannot prove semantics |
| `fee_core:table:pic` | `fee_core` | table | OPEN | — | Domain table has no core business key or FK into a Tier-1 table |
| `fee_core:table:used-count` | `fee_core` | table | OPEN | — | Domain table has no core business key or FK into a Tier-1 table |
| `fee_core:table:velocity-counter` | `fee_core` | table | OPEN | — | Domain table has no core business key or FK into a Tier-1 table |
| `fee_core:table:velocity-profile` | `fee_core` | table | OPEN | — | Domain table has no core business key or FK into a Tier-1 table |
| `gl_core:action:action-account-create` | `gl_core` | action | OPEN | — | Write paragraph with no core link (writes gl_account) |
| `gl_core:action:action-period-close` | `gl_core` | action | OPEN | — | Write paragraph with no core link (writes gl_period) |
| `gl_core:action:action-period-open` | `gl_core` | action | OPEN | — | Write paragraph with no core link (writes gl_period) |
| `gl_core:audit:core-reference` | `gl_core` | audit | OPEN | — | Manual: verify audit rows store a core reference (old/new value + core id); automation cannot prove semantics |
| `gl_core:table:audit-trail` | `gl_core` | table | OPEN | — | Domain table has no core business key or FK into a Tier-1 table |
| `gl_core:table:gl-account` | `gl_core` | table | OPEN | — | Domain table has no core business key or FK into a Tier-1 table |
| `gl_core:table:gl-period` | `gl_core` | table | OPEN | — | Domain table has no core business key or FK into a Tier-1 table |
| `identity_core:action:action-scr-screen` | `identity_core` | action | OPEN | — | Write paragraph with no core link (writes manual_reviews, screening_checks) |
| `identity_core:audit:core-reference` | `identity_core` | audit | OPEN | — | Manual: verify audit rows store a core reference (old/new value + core id); automation cannot prove semantics |
| `identity_core:table:audit-trail` | `identity_core` | table | OPEN | — | Domain table has no core business key or FK into a Tier-1 table |
| `identity_core:table:identity-verifications` | `identity_core` | table | OPEN | — | Domain table has no core business key or FK into a Tier-1 table |
| `identity_core:table:manual-reviews` | `identity_core` | table | OPEN | — | Domain table has no core business key or FK into a Tier-1 table |
| `identity_core:table:phone-links` | `identity_core` | table | OPEN | — | Domain table has no core business key or FK into a Tier-1 table |
| `identity_core:table:screening-checks` | `identity_core` | table | OPEN | — | Domain table has no core business key or FK into a Tier-1 table |
| `import_post_core:audit:core-reference` | `import_post_core` | audit | OPEN | — | Manual: verify audit rows store a core reference (old/new value + core id); automation cannot prove semantics |
| `import_post_core:table:gl-period` | `import_post_core` | table | OPEN | — | Domain table has no core business key or FK into a Tier-1 table |
| `import_post_core:table:import-batch` | `import_post_core` | table | OPEN | — | Domain table has no core business key or FK into a Tier-1 table |
| `import_post_core:table:import-row` | `import_post_core` | table | OPEN | — | Domain table has no core business key or FK into a Tier-1 table |
| `import_recon_core:action:action-finish` | `import_recon_core` | action | OPEN | — | Write paragraph with no core link (writes import_recon_run) |
| `import_recon_core:action:action-retry` | `import_recon_core` | action | OPEN | — | Write paragraph with no core link (writes import_recon_run) |
| `import_recon_core:action:action-start` | `import_recon_core` | action | OPEN | — | Write paragraph with no core link (writes import_recon_run) |
| `import_recon_core:audit:core-reference` | `import_recon_core` | audit | OPEN | — | Manual: verify audit rows store a core reference (old/new value + core id); automation cannot prove semantics |
| `import_recon_core:table:import-batch` | `import_recon_core` | table | OPEN | — | Domain table has no core business key or FK into a Tier-1 table |
| `import_recon_core:table:import-recon-run` | `import_recon_core` | table | OPEN | — | Domain table has no core business key or FK into a Tier-1 table |
| `import_recon_core:table:import-row` | `import_recon_core` | table | OPEN | — | Domain table has no core business key or FK into a Tier-1 table |
| `loan_core:action:action-close` | `loan_core` | action | OPEN | — | Write paragraph with no core link (writes loan) |
| `loan_core:action:action-create` | `loan_core` | action | OPEN | — | Write paragraph with no core link (writes loan) |
| `loan_core:action:action-submit` | `loan_core` | action | OPEN | — | Write paragraph with no core link (writes loan) |
| `loan_core:action:action-update` | `loan_core` | action | OPEN | — | Write paragraph with no core link (writes loan) |
| `loan_core:audit:core-reference` | `loan_core` | audit | OPEN | — | Manual: verify audit rows store a core reference (old/new value + core id); automation cannot prove semantics |
| `loan_core:table:loan` | `loan_core` | table | OPEN | — | Domain table has no core business key or FK into a Tier-1 table |
| `loan_schedule_core:audit:core-reference` | `loan_schedule_core` | audit | OPEN | — | Manual: verify audit rows store a core reference (old/new value + core id); automation cannot prove semantics |
| `merchant_core:action:action-approve` | `merchant_core` | action | OPEN | — | Write paragraph with no core link (writes merchant, merchant_fee_profile) |
| `merchant_core:action:action-close` | `merchant_core` | action | OPEN | — | Write paragraph with no core link (writes merchant) |
| `merchant_core:action:action-close-mch` | `merchant_core` | action | OPEN | — | Write paragraph with no core link (writes merchant) |
| `merchant_core:action:action-create` | `merchant_core` | action | OPEN | — | Write paragraph with no core link (writes merchant) |
| `merchant_core:action:action-set-fee` | `merchant_core` | action | OPEN | — | Write paragraph with no core link (writes merchant, merchant_fee_profile) |
| `merchant_core:action:action-submit` | `merchant_core` | action | OPEN | — | Write paragraph with no core link (writes merchant) |
| `merchant_core:action:action-submit-kyc` | `merchant_core` | action | OPEN | — | Write paragraph with no core link (writes merchant) |
| `merchant_core:action:action-suspend` | `merchant_core` | action | OPEN | — | Write paragraph with no core link (writes merchant) |
| `merchant_core:action:action-update` | `merchant_core` | action | OPEN | — | Write paragraph with no core link (writes merchant) |
| `merchant_core:audit:core-reference` | `merchant_core` | audit | OPEN | — | Manual: verify audit rows store a core reference (old/new value + core id); automation cannot prove semantics |
| `merchant_core:table:customer` | `merchant_core` | table | OPEN | — | Domain table has no core business key or FK into a Tier-1 table |
| `merchant_core:table:merchant` | `merchant_core` | table | OPEN | — | Domain table has no core business key or FK into a Tier-1 table |
| `merchant_core:table:merchant-settlement` | `merchant_core` | table | OPEN | — | Domain table has no core business key or FK into a Tier-1 table |
| `payment_clearing_core:action:action-cancel` | `payment_clearing_core` | action | OPEN | — | Write paragraph with no core link (writes payment_clearing) |
| `payment_clearing_core:action:action-create` | `payment_clearing_core` | action | OPEN | — | Write paragraph with no core link (writes payment_clearing) |
| `payment_clearing_core:action:action-post` | `payment_clearing_core` | action | OPEN | — | Write paragraph with no core link (writes payment_clearing) |
| `payment_clearing_core:action:action-settle` | `payment_clearing_core` | action | DONE | assistant | Write paragraph with no core link (writes payment_clearing) |
| `payment_clearing_core:audit:core-reference` | `payment_clearing_core` | audit | OPEN | — | Manual: verify audit rows store a core reference (old/new value + core id); automation cannot prove semantics |
| `payment_clearing_core:table:payment-clearing` | `payment_clearing_core` | table | OPEN | — | Domain table has no core business key or FK into a Tier-1 table |
| `payment_core:action:action-policy-set` | `payment_core` | action | OPEN | — | Write paragraph with no core link (writes max_per_txn, payment_policy) |
| `payment_core:action:action-profile-set` | `payment_core` | action | OPEN | — | Write paragraph with no core link (writes daily_limit, payment_profile) |
| `payment_core:audit:core-reference` | `payment_core` | audit | OPEN | — | Manual: verify audit rows store a core reference (old/new value + core id); automation cannot prove semantics |
| `payment_core:table:daily-limit` | `payment_core` | table | OPEN | — | Domain table has no core business key or FK into a Tier-1 table |
| `payment_core:table:max-per-txn` | `payment_core` | table | OPEN | — | Domain table has no core business key or FK into a Tier-1 table |
| `payment_core:table:payment-policy` | `payment_core` | table | OPEN | — | Domain table has no core business key or FK into a Tier-1 table |
| `payment_core:table:payment-profile` | `payment_core` | table | OPEN | — | Domain table has no core business key or FK into a Tier-1 table |
| `payment_hold_core:action:action-capture` | `payment_hold_core` | action | DONE | assistant | Write paragraph with no core link (writes payment_hold) |
| `payment_hold_core:action:action-expire` | `payment_hold_core` | action | OPEN | — | Write paragraph with no core link (writes payment_hold) |
| `payment_hold_core:action:action-release` | `payment_hold_core` | action | OPEN | — | Write paragraph with no core link (writes payment_hold) |
| `payment_hold_core:audit:core-reference` | `payment_hold_core` | audit | OPEN | — | Manual: verify audit rows store a core reference (old/new value + core id); automation cannot prove semantics |
| `payment_instruction_core:action:action-cancel` | `payment_instruction_core` | action | OPEN | — | Write paragraph with no core link (writes payment_instruction) |
| `payment_instruction_core:action:action-pause` | `payment_instruction_core` | action | OPEN | — | Write paragraph with no core link (writes payment_instruction) |
| `payment_instruction_core:action:action-resume` | `payment_instruction_core` | action | OPEN | — | Write paragraph with no core link (writes payment_instruction) |
| `payment_instruction_core:audit:core-reference` | `payment_instruction_core` | audit | OPEN | — | Manual: verify audit rows store a core reference (old/new value + core id); automation cannot prove semantics |
| `payment_instruction_core:table:cast` | `payment_instruction_core` | table | OPEN | — | Domain table has no core business key or FK into a Tier-1 table |
| `payment_instruction_core:table:move` | `payment_instruction_core` | table | OPEN | — | Domain table has no core business key or FK into a Tier-1 table |
| `payment_instruction_core:table:payment-instruction` | `payment_instruction_core` | table | OPEN | — | Domain table has no core business key or FK into a Tier-1 table |
| `payment_instruction_core:table:payment-instruction-run` | `payment_instruction_core` | table | OPEN | — | Domain table has no core business key or FK into a Tier-1 table |
| `payment_instruction_core:table:pic` | `payment_instruction_core` | table | OPEN | — | Domain table has no core business key or FK into a Tier-1 table |
| `payment_instruction_core:table:tallying` | `payment_instruction_core` | table | OPEN | — | Domain table has no core business key or FK into a Tier-1 table |
| `payment_instruction_core:table:to` | `payment_instruction_core` | table | OPEN | — | Domain table has no core business key or FK into a Tier-1 table |
| `payment_instruction_core:table:trim` | `payment_instruction_core` | table | OPEN | — | Domain table has no core business key or FK into a Tier-1 table |
| `payroll_processing_core:action:action-approve` | `payroll_processing_core` | action | OPEN | — | Write paragraph with no core link (writes payroll_processing) |
| `payroll_processing_core:action:action-close` | `payroll_processing_core` | action | OPEN | — | Write paragraph with no core link (writes payroll_processing) |
| `payroll_processing_core:action:action-close-pay` | `payroll_processing_core` | action | OPEN | — | Write paragraph with no core link (writes payroll_processing) |
| `payroll_processing_core:action:action-pay` | `payroll_processing_core` | action | OPEN | — | Write paragraph with no core link (writes payroll_employee, payroll_payment, payroll_processing) |
| `payroll_processing_core:action:action-submit` | `payroll_processing_core` | action | OPEN | — | Write paragraph with no core link (writes payroll_processing) |
| `payroll_processing_core:action:action-update` | `payroll_processing_core` | action | OPEN | — | Write paragraph with no core link (writes payroll_processing) |
| `payroll_processing_core:action:action-validate-batch` | `payroll_processing_core` | action | OPEN | — | Write paragraph with no core link (writes payroll_employee, payroll_processing) |
| `payroll_processing_core:audit:core-reference` | `payroll_processing_core` | audit | OPEN | — | Manual: verify audit rows store a core reference (old/new value + core id); automation cannot prove semantics |
| `payroll_processing_core:table:customer` | `payroll_processing_core` | table | OPEN | — | Domain table has no core business key or FK into a Tier-1 table |
| `payroll_processing_core:table:payroll-employee` | `payroll_processing_core` | table | OPEN | — | Domain table has no core business key or FK into a Tier-1 table |
| `payroll_processing_core:table:payroll-payment` | `payroll_processing_core` | table | OPEN | — | Domain table has no core business key or FK into a Tier-1 table |
| `payroll_processing_core:table:payroll-processing` | `payroll_processing_core` | table | OPEN | — | Domain table has no core business key or FK into a Tier-1 table |
| `payroll_processing_core:table:tax-management` | `payroll_processing_core` | table | OPEN | — | Domain table has no core business key or FK into a Tier-1 table |
| `report_core:action:action-column-create` | `report_core` | action | WAIVED | assistant | Write paragraph with no core link (writes report_template_column) |
| `report_core:action:action-column-update` | `report_core` | action | WAIVED | assistant | Write paragraph with no core link (writes report_template_column) |
| `report_core:action:action-run-complete` | `report_core` | action | WAIVED | assistant | Write paragraph with no core link (writes report_run) |
| `report_core:action:action-run-fail` | `report_core` | action | WAIVED | assistant | Write paragraph with no core link (writes report_run) |
| `report_core:action:action-run-retry` | `report_core` | action | WAIVED | assistant | Write paragraph with no core link (writes report_run) |
| `report_core:action:action-run-row` | `report_core` | action | WAIVED | assistant | Write paragraph with no core link (writes report_run_row) |
| `report_core:action:action-run-start` | `report_core` | action | WAIVED | assistant | Write paragraph with no core link (writes report_run) |
| `report_core:action:action-template-clone` | `report_core` | action | WAIVED | assistant | Write paragraph with no core link (writes report_template, report_template_column) |
| `report_core:action:action-template-create` | `report_core` | action | WAIVED | assistant | Write paragraph with no core link (writes report_template) |
| `report_core:action:action-template-update` | `report_core` | action | WAIVED | assistant | Write paragraph with no core link (writes report_template) |
| `report_core:audit:core-reference` | `report_core` | audit | DONE | assistant | Manual: verify audit rows store a core reference (old/new value + core id); automation cannot prove semantics |
| `report_core:table:gl-account` | `report_core` | table | WAIVED | assistant | Domain table has no core business key or FK into a Tier-1 table |
| `report_core:table:report-run` | `report_core` | table | WAIVED | assistant | Domain table has no core business key or FK into a Tier-1 table |
| `report_core:table:report-run-row` | `report_core` | table | WAIVED | assistant | Domain table has no core business key or FK into a Tier-1 table |
| `report_core:table:report-template` | `report_core` | table | WAIVED | assistant | Domain table has no core business key or FK into a Tier-1 table |
| `report_core:table:report-template-column` | `report_core` | table | WAIVED | assistant | Domain table has no core business key or FK into a Tier-1 table |
| `statement_core:action:action-run-fail` | `statement_core` | action | OPEN | — | Write paragraph with no core link (writes statement_run) |
| `statement_core:action:action-run-start` | `statement_core` | action | OPEN | — | Write paragraph with no core link (writes statement_run) |
| `statement_core:audit:core-reference` | `statement_core` | audit | OPEN | — | Manual: verify audit rows store a core reference (old/new value + core id); automation cannot prove semantics |
| `statement_core:table:delimited` | `statement_core` | table | OPEN | — | Domain table has no core business key or FK into a Tier-1 table |
| `statement_core:table:pic` | `statement_core` | table | OPEN | — | Domain table has no core business key or FK into a Tier-1 table |
| `statement_core:table:statement-archive` | `statement_core` | table | OPEN | — | Domain table has no core business key or FK into a Tier-1 table |
| `statement_core:table:statement-archive-line` | `statement_core` | table | OPEN | — | Domain table has no core business key or FK into a Tier-1 table |
| `statement_core:table:statement-run` | `statement_core` | table | OPEN | — | Domain table has no core business key or FK into a Tier-1 table |
| `statement_core:table:to` | `statement_core` | table | OPEN | — | Domain table has no core business key or FK into a Tier-1 table |
| `statement_recon_core:action:action-finish` | `statement_recon_core` | action | OPEN | — | Write paragraph with no core link (writes statement_recon_run) |
| `statement_recon_core:action:action-retry` | `statement_recon_core` | action | OPEN | — | Write paragraph with no core link (writes statement_recon_run) |
| `statement_recon_core:action:action-start` | `statement_recon_core` | action | OPEN | — | Write paragraph with no core link (writes statement_recon_run) |
| `statement_recon_core:audit:core-reference` | `statement_recon_core` | audit | OPEN | — | Manual: verify audit rows store a core reference (old/new value + core id); automation cannot prove semantics |
| `statement_recon_core:table:statement-archive` | `statement_recon_core` | table | OPEN | — | Domain table has no core business key or FK into a Tier-1 table |
| `statement_recon_core:table:statement-archive-line` | `statement_recon_core` | table | OPEN | — | Domain table has no core business key or FK into a Tier-1 table |
| `statement_recon_core:table:statement-recon-run` | `statement_recon_core` | table | OPEN | — | Domain table has no core business key or FK into a Tier-1 table |
| `statement_recon_core:table:statement-run` | `statement_recon_core` | table | OPEN | — | Domain table has no core business key or FK into a Tier-1 table |
| `treasury_liquidity_core:action:action-cancel` | `treasury_liquidity_core` | action | OPEN | — | Write paragraph with no core link (writes treasury_liquidity) |
| `treasury_liquidity_core:action:action-close` | `treasury_liquidity_core` | action | OPEN | — | Write paragraph with no core link (writes treasury_liquidity) |
| `treasury_liquidity_core:action:action-create` | `treasury_liquidity_core` | action | OPEN | — | Write paragraph with no core link (writes treasury_liquidity) |
| `treasury_liquidity_core:action:action-post` | `treasury_liquidity_core` | action | OPEN | — | Write paragraph with no core link (writes treasury_liquidity) |
| `treasury_liquidity_core:audit:core-reference` | `treasury_liquidity_core` | audit | OPEN | — | Manual: verify audit rows store a core reference (old/new value + core id); automation cannot prove semantics |
| `treasury_liquidity_core:table:treasury-liquidity` | `treasury_liquidity_core` | table | OPEN | — | Domain table has no core business key or FK into a Tier-1 table |
| `user_core:audit:core-reference` | `user_core` | audit | OPEN | — | Manual: verify audit rows store a core reference (old/new value + core id); automation cannot prove semantics |
| `user_core:table:audit-trail` | `user_core` | table | OPEN | — | Domain table has no core business key or FK into a Tier-1 table |
| `user_core:table:mfa-backup-codes` | `user_core` | table | OPEN | — | Domain table has no core business key or FK into a Tier-1 table |
| `user_core:table:notification-outbox` | `user_core` | table | OPEN | — | Domain table has no core business key or FK into a Tier-1 table |
| `user_core:table:refresh-sessions` | `user_core` | table | OPEN | — | Domain table has no core business key or FK into a Tier-1 table |
| `user_core:table:so` | `user_core` | table | OPEN | — | Domain table has no core business key or FK into a Tier-1 table |
| `user_core:table:verification-logs` | `user_core` | table | OPEN | — | Domain table has no core business key or FK into a Tier-1 table |
| `wallet_core:audit:core-reference` | `wallet_core` | audit | OPEN | — | Manual: verify audit rows store a core reference (old/new value + core id); automation cannot prove semantics |
| `wallet_core:table:audit-authz-denied` | `wallet_core` | table | OPEN | — | Domain table has no core business key or FK into a Tier-1 table |
| `wallet_core:table:audit-trail` | `wallet_core` | table | OPEN | — | Domain table has no core business key or FK into a Tier-1 table |
| `wallet_core:table:delimited` | `wallet_core` | table | OPEN | — | Domain table has no core business key or FK into a Tier-1 table |
| `wallet_core:table:dispute-cases` | `wallet_core` | table | WAIVED | assistant | Domain table has no core business key or FK into a Tier-1 table |
| `wallet_core:table:dispute-messages` | `wallet_core` | table | WAIVED | assistant | Domain table has no core business key or FK into a Tier-1 table |
| `wallet_core:table:end` | `wallet_core` | table | WAIVED | assistant | Domain table has no core business key or FK into a Tier-1 table |
| `wallet_core:table:exchange-rates` | `wallet_core` | table | OPEN | — | Domain table has no core business key or FK into a Tier-1 table |
| `wallet_core:table:if` | `wallet_core` | table | OPEN | — | Domain table has no core business key or FK into a Tier-1 table |
| `wallet_core:table:in` | `wallet_core` | table | OPEN | — | Domain table has no core business key or FK into a Tier-1 table |
| `wallet_core:table:not` | `wallet_core` | table | WAIVED | assistant | Domain table has no core business key or FK into a Tier-1 table |
| `wallet_core:table:pending-transactions` | `wallet_core` | table | OPEN | — | Domain table has no core business key or FK into a Tier-1 table |
| `wallet_core:table:pic` | `wallet_core` | table | OPEN | — | Domain table has no core business key or FK into a Tier-1 table |
| `wallet_core:table:reconciliation-runs` | `wallet_core` | table | WAIVED | assistant | Domain table has no core business key or FK into a Tier-1 table |
| `wallet_core:table:reversal-fee-policy` | `wallet_core` | table | WAIVED | assistant | Domain table has no core business key or FK into a Tier-1 table |
| `wallet_core:table:role-permissions` | `wallet_core` | table | WAIVED | assistant | Domain table has no core business key or FK into a Tier-1 table |
| `wallet_core:table:to` | `wallet_core` | table | OPEN | — | Domain table has no core business key or FK into a Tier-1 table |
| `wallet_core:table:transfer-reversals` | `wallet_core` | table | OPEN | — | Domain table has no core business key or FK into a Tier-1 table |
