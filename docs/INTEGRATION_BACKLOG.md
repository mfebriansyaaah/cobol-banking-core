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
| PARTIAL (open items) | 66 |

Open/in-progress items: 232 of 309 recorded.

| Module | Status | Items |
| --- | --- | ---: |
| `account_core` | PARTIAL | 1 |
| `auth_core` | PARTIAL | 22 |
| `auth_mfa_core` | PARTIAL | 2 |
| `auth_ops_core` | PARTIAL | 3 |
| `auth_password_core` | PARTIAL | 1 |
| `auth_recovery_core` | PARTIAL | 5 |
| `auth_review_core` | PARTIAL | 4 |
| `auth_session_core` | PARTIAL | 5 |
| `bank_guarantee_core` | PARTIAL | 2 |
| `card_core` | PARTIAL | 1 |
| `card_posting_core` | PARTIAL | 1 |
| `chargeback_core` | PARTIAL | 7 |
| `collateral_core` | PARTIAL | 13 |
| `collection_core` | PARTIAL | 1 |
| `compliance_calendar_core` | PARTIAL | 1 |
| `corp_core` | PARTIAL | 1 |
| `cost_center_core` | PARTIAL | 1 |
| `dashboard_core` | PARTIAL | 12 |
| `deposit_core` | PARTIAL | 1 |
| `deposit_posting_core` | PARTIAL | 1 |
| `eod_core` | PARTIAL | 5 |
| `eod_jobs_core` | PARTIAL | 4 |
| `fee_core` | PARTIAL | 7 |
| `fixed_asset_core` | PARTIAL | 1 |
| `fx_rate_core` | PARTIAL | 1 |
| `gl_allocation_core` | PARTIAL | 1 |
| `gl_core` | PARTIAL | 7 |
| `identity_core` | PARTIAL | 7 |
| `import_core` | PARTIAL | 9 |
| `import_post_core` | PARTIAL | 4 |
| `import_recon_core` | PARTIAL | 7 |
| `import_row_core` | PARTIAL | 2 |
| `letter_of_credit_core` | PARTIAL | 2 |
| `loan_core` | PARTIAL | 6 |
| `loan_posting_core` | PARTIAL | 1 |
| `loan_schedule_core` | PARTIAL | 1 |
| `loan_schedule_lifecycle_core` | PARTIAL | 1 |
| `loan_schedule_posting_core` | PARTIAL | 1 |
| `loan_schedule_report_core` | PARTIAL | 1 |
| `loyalty_core` | PARTIAL | 5 |
| `merchant_core` | PARTIAL | 13 |
| `merchant_settlement_core` | PARTIAL | 7 |
| `notification_template_core` | PARTIAL | 1 |
| `payment_clearing_core` | PARTIAL | 6 |
| `payment_core` | PARTIAL | 6 |
| `payment_hold_core` | PARTIAL | 4 |
| `payment_instruction_core` | PARTIAL | 6 |
| `payroll_processing_core` | PARTIAL | 13 |
| `phone_otp_core` | PARTIAL | 4 |
| `report_core` | PARTIAL | 16 |
| `report_run_core` | PARTIAL | 2 |
| `report_schedule_core` | PARTIAL | 1 |
| `risk_core` | PARTIAL | 1 |
| `sla_tracker_core` | PARTIAL | 1 |
| `statement_core` | PARTIAL | 6 |
| `statement_recon_core` | PARTIAL | 8 |
| `tax_management_core` | PARTIAL | 6 |
| `treasury_liquidity_core` | PARTIAL | 6 |
| `user_core` | PARTIAL | 6 |
| `wallet_core` | PARTIAL | 15 |
| `wallet_dispute_core` | PARTIAL | 7 |
| `wallet_hold_core` | PARTIAL | 2 |
| `wallet_recon_core` | PARTIAL | 4 |
| `wallet_reversal_core` | PARTIAL | 4 |
| `wallet_statement_core` | PARTIAL | 1 |
| `wallet_transfer_core` | PARTIAL | 5 |

| Item | Module | Kind | Status | Owner | Reason |
| --- | --- | --- | --- | --- | --- |
| `account_core:audit:core-reference` | `account_core` | audit | DONE | backend | Manual: verify audit rows store a core reference (old/new value + core id); automation cannot prove semantics |
| `auth_core:action:outbox-claim-logic` | `auth_core` | action | WAIVED | assistant | Write paragraph with no core link (writes notification_outbox) |
| `auth_core:action:outbox-mark-logic` | `auth_core` | action | WAIVED | assistant | Write paragraph with no core link (writes notification_outbox) |
| `auth_core:action:revoke-access-token-logic` | `auth_core` | action | DONE | assistant | Write paragraph with no core link (writes revoked_access_tokens) |
| `auth_core:action:revoke-user-session-logic` | `auth_core` | action | DONE | assistant | Write paragraph with no core link (writes refresh_sessions) |
| `auth_core:action:store-session-logic` | `auth_core` | action | DONE | assistant | Write paragraph with no core link (writes refresh_families, refresh_sessions) |
| `auth_core:audit:core-reference` | `auth_core` | audit | DONE | assistant | Manual: verify audit rows store a core reference (old/new value + core id); automation cannot prove semantics |
| `auth_core:table:access-review-items` | `auth_core` | table | WAIVED | assistant | Domain table has no core business key or FK into a core table |
| `auth_core:table:access-reviews` | `auth_core` | table | WAIVED | assistant | Domain table has no core business key or FK into a core table |
| `auth_core:table:audit-trail` | `auth_core` | table | DONE | assistant | Domain table has no core business key or FK into a core table |
| `auth_core:table:dual-control-operations` | `auth_core` | table | DONE | assistant | Domain table has no core business key or FK into a core table |
| `auth_core:table:known-devices` | `auth_core` | table | DONE | assistant | Domain table has no core business key or FK into a core table |
| `auth_core:table:maker-requests` | `auth_core` | table | WAIVED | assistant | Domain table has no core business key or FK into a core table |
| `auth_core:table:mfa-backup-codes` | `auth_core` | table | DONE | assistant | Domain table has no core business key or FK into a core table |
| `auth_core:table:mfa-recovery-requests` | `auth_core` | table | WAIVED | assistant | Domain table has no core business key or FK into a core table |
| `auth_core:table:notification-outbox` | `auth_core` | table | DONE | assistant | Domain table has no core business key or FK into a core table |
| `auth_core:table:permissions` | `auth_core` | table | WAIVED | assistant | Domain table has no core business key or FK into a core table |
| `auth_core:table:refresh-families` | `auth_core` | table | DONE | assistant | Domain table has no core business key or FK into a core table |
| `auth_core:table:refresh-sessions` | `auth_core` | table | DONE | assistant | Domain table has no core business key or FK into a core table |
| `auth_core:table:revoked-access-tokens` | `auth_core` | table | DONE | assistant | Domain table has no core business key or FK into a core table |
| `auth_core:table:role-permissions` | `auth_core` | table | WAIVED | assistant | Domain table has no core business key or FK into a core table |
| `auth_core:table:step-up-policy` | `auth_core` | table | DONE | assistant | Domain table has no core business key or FK into a core table |
| `auth_core:table:verification-logs` | `auth_core` | table | DONE | assistant | Domain table has no core business key or FK into a core table |
| `auth_mfa_core:audit:core-reference` | `auth_mfa_core` | audit | OPEN | backend | Manual: verify audit rows store a core reference (old/new value + core id); automation cannot prove semantics |
| `auth_mfa_core:table:audit-trail` | `auth_mfa_core` | table | OPEN | backend | Domain table has no core business key or FK into a core table |
| `auth_ops_core:audit:core-reference` | `auth_ops_core` | audit | OPEN | backend | Manual: verify audit rows store a core reference (old/new value + core id); automation cannot prove semantics |
| `auth_ops_core:table:audit-trail` | `auth_ops_core` | table | OPEN | backend | Domain table has no core business key or FK into a core table |
| `auth_ops_core:table:role-permissions` | `auth_ops_core` | table | OPEN | backend | Domain table has no core business key or FK into a core table |
| `auth_password_core:audit:core-reference` | `auth_password_core` | audit | DONE | assistant | Manual: verify audit rows store a core reference (old/new value + core id); automation cannot prove semantics |
| `auth_recovery_core:audit:core-reference` | `auth_recovery_core` | audit | OPEN | identity | Manual: verify audit rows store a core reference (old/new value + core id); automation cannot prove semantics |
| `auth_recovery_core:table:audit-trail` | `auth_recovery_core` | table | OPEN | identity | Domain table has no core business key or FK into a core table |
| `auth_recovery_core:table:dual-control-operations` | `auth_recovery_core` | table | OPEN | identity | Domain table has no core business key or FK into a core table |
| `auth_recovery_core:table:maker-requests` | `auth_recovery_core` | table | OPEN | identity | Domain table has no core business key or FK into a core table |
| `auth_recovery_core:table:verification-logs` | `auth_recovery_core` | table | OPEN | identity | Domain table has no core business key or FK into a core table |
| `auth_review_core:audit:core-reference` | `auth_review_core` | audit | OPEN | identity | Manual: verify audit rows store a core reference (old/new value + core id); automation cannot prove semantics |
| `auth_review_core:table:audit-trail` | `auth_review_core` | table | OPEN | identity | Domain table has no core business key or FK into a core table |
| `auth_review_core:table:permissions` | `auth_review_core` | table | OPEN | identity | Domain table has no core business key or FK into a core table |
| `auth_review_core:table:role-permissions` | `auth_review_core` | table | OPEN | identity | Domain table has no core business key or FK into a core table |
| `auth_session_core:action:revoke-access-token-logic` | `auth_session_core` | action | OPEN | backend | Write paragraph with no core link (writes revoked_access_tokens) |
| `auth_session_core:audit:core-reference` | `auth_session_core` | audit | OPEN | backend | Manual: verify audit rows store a core reference (old/new value + core id); automation cannot prove semantics |
| `auth_session_core:table:audit-trail` | `auth_session_core` | table | OPEN | backend | Domain table has no core business key or FK into a core table |
| `auth_session_core:table:refresh-families` | `auth_session_core` | table | OPEN | backend | Domain table has no core business key or FK into a core table |
| `auth_session_core:table:revoked-access-tokens` | `auth_session_core` | table | OPEN | backend | Domain table has no core business key or FK into a core table |
| `bank_guarantee_core:audit:core-reference` | `bank_guarantee_core` | audit | OPEN | backend | Manual: verify audit rows store a core reference (old/new value + core id); automation cannot prove semantics |
| `bank_guarantee_core:table:customer` | `bank_guarantee_core` | table | OPEN | backend | Domain table has no core business key or FK into a core table |
| `card_core:audit:core-reference` | `card_core` | audit | OPEN | cards | Manual: verify audit rows store a core reference (old/new value + core id); automation cannot prove semantics |
| `card_posting_core:audit:core-reference` | `card_posting_core` | audit | OPEN | cards | Manual: verify audit rows store a core reference (old/new value + core id); automation cannot prove semantics |
| `chargeback_core:action:action-close` | `chargeback_core` | action | OPEN | backend | Write paragraph with no core link (writes chargeback) |
| `chargeback_core:action:action-create` | `chargeback_core` | action | OPEN | backend | Write paragraph with no core link (writes chargeback) |
| `chargeback_core:action:action-submit` | `chargeback_core` | action | OPEN | backend | Write paragraph with no core link (writes chargeback) |
| `chargeback_core:action:action-update` | `chargeback_core` | action | OPEN | backend | Write paragraph with no core link (writes chargeback) |
| `chargeback_core:audit:core-reference` | `chargeback_core` | audit | OPEN | backend | Manual: verify audit rows store a core reference (old/new value + core id); automation cannot prove semantics |
| `chargeback_core:table:chargeback` | `chargeback_core` | table | OPEN | backend | Domain table has no core business key or FK into a core table |
| `chargeback_core:table:merchant` | `chargeback_core` | table | OPEN | backend | Domain table has no core business key or FK into a core table |
| `collateral_core:action:action-allocate` | `collateral_core` | action | OPEN | collateral | Write paragraph with no core link (writes collateral_allocation) |
| `collateral_core:action:action-appraise` | `collateral_core` | action | OPEN | collateral | Write paragraph with no core link (writes collateral, collateral_valuation) |
| `collateral_core:action:action-close` | `collateral_core` | action | OPEN | collateral | Write paragraph with no core link (writes collateral) |
| `collateral_core:action:action-create` | `collateral_core` | action | OPEN | collateral | Write paragraph with no core link (writes collateral) |
| `collateral_core:action:action-dispose` | `collateral_core` | action | OPEN | collateral | Write paragraph with no core link (writes collateral) |
| `collateral_core:action:action-register` | `collateral_core` | action | OPEN | collateral | Write paragraph with no core link (writes collateral) |
| `collateral_core:action:action-repossess` | `collateral_core` | action | OPEN | collateral | Write paragraph with no core link (writes collateral) |
| `collateral_core:action:action-revalue` | `collateral_core` | action | OPEN | collateral | Write paragraph with no core link (writes collateral, collateral_valuation) |
| `collateral_core:action:action-submit` | `collateral_core` | action | OPEN | collateral | Write paragraph with no core link (writes collateral) |
| `collateral_core:action:action-update` | `collateral_core` | action | OPEN | collateral | Write paragraph with no core link (writes collateral) |
| `collateral_core:audit:core-reference` | `collateral_core` | audit | OPEN | collateral | Manual: verify audit rows store a core reference (old/new value + core id); automation cannot prove semantics |
| `collateral_core:table:collateral` | `collateral_core` | table | OPEN | collateral | Domain table has no core business key or FK into a core table |
| `collateral_core:table:collateral-valuation` | `collateral_core` | table | OPEN | collateral | Domain table has no core business key or FK into a core table |
| `collection_core:audit:core-reference` | `collection_core` | audit | OPEN | collection | Manual: verify audit rows store a core reference (old/new value + core id); automation cannot prove semantics |
| `compliance_calendar_core:audit:core-reference` | `compliance_calendar_core` | audit | DONE | backend | Manual: verify audit rows store a core reference (old/new value + core id); automation cannot prove semantics |
| `corp_core:audit:core-reference` | `corp_core` | audit | OPEN | backend | Manual: verify audit rows store a core reference (old/new value + core id); automation cannot prove semantics |
| `cost_center_core:audit:core-reference` | `cost_center_core` | audit | OPEN | backend | Manual: verify audit rows store a core reference (old/new value + core id); automation cannot prove semantics |
| `dashboard_core:audit:core-reference` | `dashboard_core` | audit | OPEN | reporting | Manual: verify audit rows store a core reference (old/new value + core id); automation cannot prove semantics |
| `dashboard_core:table:audit-trail` | `dashboard_core` | table | OPEN | reporting | Domain table has no core business key or FK into a core table |
| `dashboard_core:table:dispute-cases` | `dashboard_core` | table | OPEN | reporting | Domain table has no core business key or FK into a core table |
| `dashboard_core:table:import-batch` | `dashboard_core` | table | OPEN | reporting | Domain table has no core business key or FK into a core table |
| `dashboard_core:table:notification-outbox` | `dashboard_core` | table | DONE | backend | Domain table has no core business key or FK into a core table |
| `dashboard_core:table:ops-alert` | `dashboard_core` | table | OPEN | reporting | Domain table has no core business key or FK into a core table |
| `dashboard_core:table:payment-policy` | `dashboard_core` | table | OPEN | reporting | Domain table has no core business key or FK into a core table |
| `dashboard_core:table:payment-profile` | `dashboard_core` | table | OPEN | reporting | Domain table has no core business key or FK into a core table |
| `dashboard_core:table:pending-transactions` | `dashboard_core` | table | OPEN | reporting | Domain table has no core business key or FK into a core table |
| `dashboard_core:table:reconciliation-runs` | `dashboard_core` | table | OPEN | reporting | Domain table has no core business key or FK into a core table |
| `dashboard_core:table:report-run` | `dashboard_core` | table | DONE | backend | Domain table has no core business key or FK into a core table |
| `dashboard_core:table:report-schedule` | `dashboard_core` | table | OPEN | reporting | Domain table has no core business key or FK into a core table |
| `deposit_core:audit:core-reference` | `deposit_core` | audit | OPEN | deposit | Manual: verify audit rows store a core reference (old/new value + core id); automation cannot prove semantics |
| `deposit_posting_core:audit:core-reference` | `deposit_posting_core` | audit | OPEN | deposit | Manual: verify audit rows store a core reference (old/new value + core id); automation cannot prove semantics |
| `eod_core:action:action-cal-open` | `eod_core` | action | OPEN | backend | Write paragraph with no core link (writes eod_calendar) |
| `eod_core:action:action-run-fail` | `eod_core` | action | OPEN | backend | Write paragraph with no core link (writes eod_run) |
| `eod_core:audit:core-reference` | `eod_core` | audit | OPEN | backend | Manual: verify audit rows store a core reference (old/new value + core id); automation cannot prove semantics |
| `eod_core:table:eod-calendar` | `eod_core` | table | OPEN | backend | Domain table has no core business key or FK into a core table |
| `eod_core:table:eod-run` | `eod_core` | table | OPEN | backend | Domain table has no core business key or FK into a core table |
| `eod_jobs_core:audit:core-reference` | `eod_jobs_core` | audit | OPEN | backend | Manual: verify audit rows store a core reference (old/new value + core id); automation cannot prove semantics |
| `eod_jobs_core:table:audit-trail` | `eod_jobs_core` | table | OPEN | backend | Domain table has no core business key or FK into a core table |
| `eod_jobs_core:table:pending-transactions` | `eod_jobs_core` | table | OPEN | backend | Domain table has no core business key or FK into a core table |
| `eod_jobs_core:table:pending-transactions-archive` | `eod_jobs_core` | table | OPEN | backend | Domain table has no core business key or FK into a core table |
| `fee_core:action:action-vel-profile-create` | `fee_core` | action | OPEN | finance | Write paragraph with no core link (writes velocity_profile) |
| `fee_core:action:action-vel-record` | `fee_core` | action | OPEN | finance | Write paragraph with no core link (writes used_count, velocity_counter) |
| `fee_core:action:action-vel-record-all-txn` | `fee_core` | action | OPEN | finance | Write paragraph with no core link (writes used_count, velocity_counter) |
| `fee_core:audit:core-reference` | `fee_core` | audit | OPEN | finance | Manual: verify audit rows store a core reference (old/new value + core id); automation cannot prove semantics |
| `fee_core:table:pic` | `fee_core` | table | DONE | assistant | Domain table has no core business key or FK into a core table |
| `fee_core:table:velocity-counter` | `fee_core` | table | OPEN | finance | Domain table has no core business key or FK into a core table |
| `fee_core:table:velocity-profile` | `fee_core` | table | OPEN | finance | Domain table has no core business key or FK into a core table |
| `fixed_asset_core:audit:core-reference` | `fixed_asset_core` | audit | DONE | backend | Manual: verify audit rows store a core reference (old/new value + core id); automation cannot prove semantics |
| `fx_rate_core:audit:core-reference` | `fx_rate_core` | audit | OPEN | backend | Manual: verify audit rows store a core reference (old/new value + core id); automation cannot prove semantics |
| `gl_allocation_core:audit:core-reference` | `gl_allocation_core` | audit | OPEN | backend | Manual: verify audit rows store a core reference (old/new value + core id); automation cannot prove semantics |
| `gl_core:action:action-account-create` | `gl_core` | action | DONE | finance | Write paragraph with no core link (writes gl_account) |
| `gl_core:action:action-period-close` | `gl_core` | action | OPEN | finance | Write paragraph with no core link (writes gl_period) |
| `gl_core:action:action-period-open` | `gl_core` | action | OPEN | finance | Write paragraph with no core link (writes gl_period) |
| `gl_core:audit:core-reference` | `gl_core` | audit | OPEN | finance | Manual: verify audit rows store a core reference (old/new value + core id); automation cannot prove semantics |
| `gl_core:table:audit-trail` | `gl_core` | table | OPEN | finance | Domain table has no core business key or FK into a core table |
| `gl_core:table:gl-account` | `gl_core` | table | DONE | finance | Domain table has no core business key or FK into a core table |
| `gl_core:table:gl-period` | `gl_core` | table | OPEN | finance | Domain table has no core business key or FK into a core table |
| `identity_core:action:action-scr-screen` | `identity_core` | action | OPEN | identity | Write paragraph with no core link (writes manual_reviews, screening_checks) |
| `identity_core:audit:core-reference` | `identity_core` | audit | OPEN | identity | Manual: verify audit rows store a core reference (old/new value + core id); automation cannot prove semantics |
| `identity_core:table:audit-trail` | `identity_core` | table | OPEN | identity | Domain table has no core business key or FK into a core table |
| `identity_core:table:identity-verifications` | `identity_core` | table | OPEN | identity | Domain table has no core business key or FK into a core table |
| `identity_core:table:manual-reviews` | `identity_core` | table | OPEN | identity | Domain table has no core business key or FK into a core table |
| `identity_core:table:phone-links` | `identity_core` | table | OPEN | identity | Domain table has no core business key or FK into a core table |
| `identity_core:table:screening-checks` | `identity_core` | table | OPEN | identity | Domain table has no core business key or FK into a core table |
| `import_core:action:action-batch-clone` | `import_core` | action | DONE | backend | Write paragraph with no core link (writes import_batch, import_row) |
| `import_core:action:action-batch-create` | `import_core` | action | OPEN | backend | Write paragraph with no core link (writes import_batch) |
| `import_core:action:action-batch-fail` | `import_core` | action | OPEN | backend | Write paragraph with no core link (writes import_batch) |
| `import_core:action:action-batch-post` | `import_core` | action | DONE | backend | Write paragraph with no core link (writes import_batch, import_row) |
| `import_core:action:action-batch-retry` | `import_core` | action | DONE | backend | Write paragraph with no core link (writes import_batch, import_row) |
| `import_core:action:action-batch-validate` | `import_core` | action | DONE | backend | Write paragraph with no core link (writes import_batch, import_row) |
| `import_core:audit:core-reference` | `import_core` | audit | OPEN | backend | Manual: verify audit rows store a core reference (old/new value + core id); automation cannot prove semantics |
| `import_core:table:import-batch` | `import_core` | table | OPEN | backend | Domain table has no core business key or FK into a core table |
| `import_core:table:import-row` | `import_core` | table | DONE | backend | Domain table has no core business key or FK into a core table |
| `import_post_core:audit:core-reference` | `import_post_core` | audit | OPEN | backend | Manual: verify audit rows store a core reference (old/new value + core id); automation cannot prove semantics |
| `import_post_core:table:gl-period` | `import_post_core` | table | OPEN | backend | Domain table has no core business key or FK into a core table |
| `import_post_core:table:import-batch` | `import_post_core` | table | OPEN | backend | Domain table has no core business key or FK into a core table |
| `import_post_core:table:import-row` | `import_post_core` | table | DONE | backend | Domain table has no core business key or FK into a core table |
| `import_recon_core:action:action-finish` | `import_recon_core` | action | OPEN | reporting | Write paragraph with no core link (writes import_recon_run) |
| `import_recon_core:action:action-retry` | `import_recon_core` | action | OPEN | reporting | Write paragraph with no core link (writes import_recon_run) |
| `import_recon_core:action:action-start` | `import_recon_core` | action | OPEN | reporting | Write paragraph with no core link (writes import_recon_run) |
| `import_recon_core:audit:core-reference` | `import_recon_core` | audit | OPEN | reporting | Manual: verify audit rows store a core reference (old/new value + core id); automation cannot prove semantics |
| `import_recon_core:table:import-batch` | `import_recon_core` | table | OPEN | reporting | Domain table has no core business key or FK into a core table |
| `import_recon_core:table:import-recon-run` | `import_recon_core` | table | OPEN | reporting | Domain table has no core business key or FK into a core table |
| `import_recon_core:table:import-row` | `import_recon_core` | table | DONE | backend | Domain table has no core business key or FK into a core table |
| `import_row_core:audit:core-reference` | `import_row_core` | audit | OPEN | backend | Manual: verify audit rows store a core reference (old/new value + core id); automation cannot prove semantics |
| `import_row_core:table:import-batch` | `import_row_core` | table | OPEN | backend | Domain table has no core business key or FK into a core table |
| `letter_of_credit_core:audit:core-reference` | `letter_of_credit_core` | audit | OPEN | backend | Manual: verify audit rows store a core reference (old/new value + core id); automation cannot prove semantics |
| `letter_of_credit_core:table:customer` | `letter_of_credit_core` | table | OPEN | backend | Domain table has no core business key or FK into a core table |
| `loan_core:action:action-close` | `loan_core` | action | OPEN | lending | Write paragraph with no core link (writes loan) |
| `loan_core:action:action-create` | `loan_core` | action | OPEN | lending | Write paragraph with no core link (writes loan) |
| `loan_core:action:action-submit` | `loan_core` | action | OPEN | lending | Write paragraph with no core link (writes loan) |
| `loan_core:action:action-update` | `loan_core` | action | OPEN | lending | Write paragraph with no core link (writes loan) |
| `loan_core:audit:core-reference` | `loan_core` | audit | OPEN | lending | Manual: verify audit rows store a core reference (old/new value + core id); automation cannot prove semantics |
| `loan_core:table:loan` | `loan_core` | table | OPEN | lending | Domain table has no core business key or FK into a core table |
| `loan_posting_core:audit:core-reference` | `loan_posting_core` | audit | OPEN | backend | Manual: verify audit rows store a core reference (old/new value + core id); automation cannot prove semantics |
| `loan_schedule_core:audit:core-reference` | `loan_schedule_core` | audit | OPEN | lending | Manual: verify audit rows store a core reference (old/new value + core id); automation cannot prove semantics |
| `loan_schedule_lifecycle_core:audit:core-reference` | `loan_schedule_lifecycle_core` | audit | OPEN | backend | Manual: verify audit rows store a core reference (old/new value + core id); automation cannot prove semantics |
| `loan_schedule_posting_core:audit:core-reference` | `loan_schedule_posting_core` | audit | OPEN | backend | Manual: verify audit rows store a core reference (old/new value + core id); automation cannot prove semantics |
| `loan_schedule_report_core:audit:core-reference` | `loan_schedule_report_core` | audit | OPEN | backend | Manual: verify audit rows store a core reference (old/new value + core id); automation cannot prove semantics |
| `loyalty_core:action:action-activate` | `loyalty_core` | action | OPEN | backend | Write paragraph with no core link (writes loyalty_program) |
| `loyalty_core:action:action-create` | `loyalty_core` | action | OPEN | backend | Write paragraph with no core link (writes loyalty_program) |
| `loyalty_core:audit:core-reference` | `loyalty_core` | audit | OPEN | backend | Manual: verify audit rows store a core reference (old/new value + core id); automation cannot prove semantics |
| `loyalty_core:table:customer` | `loyalty_core` | table | OPEN | backend | Domain table has no core business key or FK into a core table |
| `loyalty_core:table:loyalty-program` | `loyalty_core` | table | OPEN | backend | Domain table has no core business key or FK into a core table |
| `merchant_core:action:action-approve` | `merchant_core` | action | OPEN | merchant | Write paragraph with no core link (writes merchant, merchant_fee_profile) |
| `merchant_core:action:action-close` | `merchant_core` | action | OPEN | merchant | Write paragraph with no core link (writes merchant) |
| `merchant_core:action:action-close-mch` | `merchant_core` | action | OPEN | merchant | Write paragraph with no core link (writes merchant) |
| `merchant_core:action:action-create` | `merchant_core` | action | OPEN | merchant | Write paragraph with no core link (writes merchant) |
| `merchant_core:action:action-set-fee` | `merchant_core` | action | OPEN | merchant | Write paragraph with no core link (writes merchant, merchant_fee_profile) |
| `merchant_core:action:action-submit` | `merchant_core` | action | OPEN | merchant | Write paragraph with no core link (writes merchant) |
| `merchant_core:action:action-submit-kyc` | `merchant_core` | action | OPEN | merchant | Write paragraph with no core link (writes merchant) |
| `merchant_core:action:action-suspend` | `merchant_core` | action | OPEN | merchant | Write paragraph with no core link (writes merchant) |
| `merchant_core:action:action-update` | `merchant_core` | action | OPEN | merchant | Write paragraph with no core link (writes merchant) |
| `merchant_core:audit:core-reference` | `merchant_core` | audit | OPEN | merchant | Manual: verify audit rows store a core reference (old/new value + core id); automation cannot prove semantics |
| `merchant_core:table:customer` | `merchant_core` | table | OPEN | merchant | Domain table has no core business key or FK into a core table |
| `merchant_core:table:merchant` | `merchant_core` | table | OPEN | merchant | Domain table has no core business key or FK into a core table |
| `merchant_core:table:merchant-settlement` | `merchant_core` | table | OPEN | merchant | Domain table has no core business key or FK into a core table |
| `merchant_settlement_core:action:action-open` | `merchant_settlement_core` | action | OPEN | merchant | Write paragraph with no core link (writes merchant_settlement) |
| `merchant_settlement_core:action:action-post` | `merchant_settlement_core` | action | OPEN | merchant | Write paragraph with no core link (writes merchant_settlement) |
| `merchant_settlement_core:action:action-submit` | `merchant_settlement_core` | action | OPEN | merchant | Write paragraph with no core link (writes merchant_settlement) |
| `merchant_settlement_core:action:action-update` | `merchant_settlement_core` | action | OPEN | merchant | Write paragraph with no core link (writes merchant_settlement) |
| `merchant_settlement_core:audit:core-reference` | `merchant_settlement_core` | audit | DONE | backend | Manual: verify audit rows store a core reference (old/new value + core id); automation cannot prove semantics |
| `merchant_settlement_core:table:merchant` | `merchant_settlement_core` | table | OPEN | merchant | Domain table has no core business key or FK into a core table |
| `merchant_settlement_core:table:merchant-settlement` | `merchant_settlement_core` | table | OPEN | merchant | Domain table has no core business key or FK into a core table |
| `notification_template_core:audit:core-reference` | `notification_template_core` | audit | DONE | backend | Manual: verify audit rows store a core reference (old/new value + core id); automation cannot prove semantics |
| `payment_clearing_core:action:action-cancel` | `payment_clearing_core` | action | OPEN | payments | Write paragraph with no core link (writes payment_clearing) |
| `payment_clearing_core:action:action-create` | `payment_clearing_core` | action | OPEN | payments | Write paragraph with no core link (writes payment_clearing) |
| `payment_clearing_core:action:action-post` | `payment_clearing_core` | action | OPEN | payments | Write paragraph with no core link (writes payment_clearing) |
| `payment_clearing_core:action:action-settle` | `payment_clearing_core` | action | DONE | assistant | Write paragraph with no core link (writes payment_clearing) |
| `payment_clearing_core:audit:core-reference` | `payment_clearing_core` | audit | OPEN | payments | Manual: verify audit rows store a core reference (old/new value + core id); automation cannot prove semantics |
| `payment_clearing_core:table:payment-clearing` | `payment_clearing_core` | table | OPEN | payments | Domain table has no core business key or FK into a core table |
| `payment_core:action:action-policy-set` | `payment_core` | action | OPEN | payments | Write paragraph with no core link (writes max_per_txn, payment_policy) |
| `payment_core:action:action-profile-set` | `payment_core` | action | OPEN | payments | Write paragraph with no core link (writes daily_limit, payment_profile) |
| `payment_core:audit:core-reference` | `payment_core` | audit | OPEN | payments | Manual: verify audit rows store a core reference (old/new value + core id); automation cannot prove semantics |
| `payment_core:table:daily-limit` | `payment_core` | table | OPEN | payments | Domain table has no core business key or FK into a core table |
| `payment_core:table:payment-policy` | `payment_core` | table | OPEN | payments | Domain table has no core business key or FK into a core table |
| `payment_core:table:payment-profile` | `payment_core` | table | OPEN | payments | Domain table has no core business key or FK into a core table |
| `payment_hold_core:action:action-capture` | `payment_hold_core` | action | DONE | assistant | Write paragraph with no core link (writes payment_hold) |
| `payment_hold_core:action:action-expire` | `payment_hold_core` | action | OPEN | payments | Write paragraph with no core link (writes payment_hold) |
| `payment_hold_core:action:action-release` | `payment_hold_core` | action | OPEN | payments | Write paragraph with no core link (writes payment_hold) |
| `payment_hold_core:audit:core-reference` | `payment_hold_core` | audit | OPEN | payments | Manual: verify audit rows store a core reference (old/new value + core id); automation cannot prove semantics |
| `payment_instruction_core:action:action-cancel` | `payment_instruction_core` | action | OPEN | payments | Write paragraph with no core link (writes payment_instruction) |
| `payment_instruction_core:action:action-pause` | `payment_instruction_core` | action | OPEN | payments | Write paragraph with no core link (writes payment_instruction) |
| `payment_instruction_core:action:action-resume` | `payment_instruction_core` | action | OPEN | payments | Write paragraph with no core link (writes payment_instruction) |
| `payment_instruction_core:audit:core-reference` | `payment_instruction_core` | audit | OPEN | payments | Manual: verify audit rows store a core reference (old/new value + core id); automation cannot prove semantics |
| `payment_instruction_core:table:payment-instruction` | `payment_instruction_core` | table | OPEN | payments | Domain table has no core business key or FK into a core table |
| `payment_instruction_core:table:payment-instruction-run` | `payment_instruction_core` | table | OPEN | payments | Domain table has no core business key or FK into a core table |
| `payroll_processing_core:action:action-approve` | `payroll_processing_core` | action | OPEN | payroll | Write paragraph with no core link (writes payroll_processing) |
| `payroll_processing_core:action:action-close` | `payroll_processing_core` | action | OPEN | payroll | Write paragraph with no core link (writes payroll_processing) |
| `payroll_processing_core:action:action-close-pay` | `payroll_processing_core` | action | OPEN | payroll | Write paragraph with no core link (writes payroll_processing) |
| `payroll_processing_core:action:action-pay` | `payroll_processing_core` | action | OPEN | payroll | Write paragraph with no core link (writes payroll_employee, payroll_payment, payroll_processing) |
| `payroll_processing_core:action:action-submit` | `payroll_processing_core` | action | OPEN | payroll | Write paragraph with no core link (writes payroll_processing) |
| `payroll_processing_core:action:action-update` | `payroll_processing_core` | action | OPEN | payroll | Write paragraph with no core link (writes payroll_processing) |
| `payroll_processing_core:action:action-validate-batch` | `payroll_processing_core` | action | OPEN | payroll | Write paragraph with no core link (writes payroll_employee, payroll_processing) |
| `payroll_processing_core:audit:core-reference` | `payroll_processing_core` | audit | OPEN | payroll | Manual: verify audit rows store a core reference (old/new value + core id); automation cannot prove semantics |
| `payroll_processing_core:table:customer` | `payroll_processing_core` | table | OPEN | payroll | Domain table has no core business key or FK into a core table |
| `payroll_processing_core:table:payroll-employee` | `payroll_processing_core` | table | OPEN | payroll | Domain table has no core business key or FK into a core table |
| `payroll_processing_core:table:payroll-payment` | `payroll_processing_core` | table | OPEN | payroll | Domain table has no core business key or FK into a core table |
| `payroll_processing_core:table:payroll-processing` | `payroll_processing_core` | table | OPEN | payroll | Domain table has no core business key or FK into a core table |
| `payroll_processing_core:table:tax-management` | `payroll_processing_core` | table | OPEN | payroll | Domain table has no core business key or FK into a core table |
| `phone_otp_core:action:action-link-begin` | `phone_otp_core` | action | OPEN | backend | Write paragraph with no core link (writes phone_hash, phone_links) |
| `phone_otp_core:action:action-link-confirm` | `phone_otp_core` | action | OPEN | backend | Write paragraph with no core link (writes phone_links) |
| `phone_otp_core:audit:core-reference` | `phone_otp_core` | audit | OPEN | backend | Manual: verify audit rows store a core reference (old/new value + core id); automation cannot prove semantics |
| `phone_otp_core:table:phone-links` | `phone_otp_core` | table | OPEN | backend | Domain table has no core business key or FK into a core table |
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
| `report_core:table:gl-account` | `report_core` | table | WAIVED | assistant | Domain table has no core business key or FK into a core table |
| `report_core:table:report-run` | `report_core` | table | WAIVED | assistant | Domain table has no core business key or FK into a core table |
| `report_core:table:report-run-row` | `report_core` | table | WAIVED | assistant | Domain table has no core business key or FK into a core table |
| `report_core:table:report-template` | `report_core` | table | WAIVED | assistant | Domain table has no core business key or FK into a core table |
| `report_core:table:report-template-column` | `report_core` | table | WAIVED | assistant | Domain table has no core business key or FK into a core table |
| `report_run_core:action:action-run-row` | `report_run_core` | action | OPEN | backend | Write paragraph with no core link (writes report_run_row) |
| `report_run_core:audit:core-reference` | `report_run_core` | audit | OPEN | backend | Manual: verify audit rows store a core reference (old/new value + core id); automation cannot prove semantics |
| `report_schedule_core:audit:core-reference` | `report_schedule_core` | audit | DONE | backend | Manual: verify audit rows store a core reference (old/new value + core id); automation cannot prove semantics |
| `risk_core:audit:core-reference` | `risk_core` | audit | OPEN | backend | Manual: verify audit rows store a core reference (old/new value + core id); automation cannot prove semantics |
| `sla_tracker_core:audit:core-reference` | `sla_tracker_core` | audit | DONE | backend | Manual: verify audit rows store a core reference (old/new value + core id); automation cannot prove semantics |
| `statement_core:action:action-run-fail` | `statement_core` | action | OPEN | reporting | Write paragraph with no core link (writes statement_run) |
| `statement_core:action:action-run-start` | `statement_core` | action | OPEN | reporting | Write paragraph with no core link (writes statement_run) |
| `statement_core:audit:core-reference` | `statement_core` | audit | OPEN | reporting | Manual: verify audit rows store a core reference (old/new value + core id); automation cannot prove semantics |
| `statement_core:table:statement-archive` | `statement_core` | table | OPEN | reporting | Domain table has no core business key or FK into a core table |
| `statement_core:table:statement-archive-line` | `statement_core` | table | OPEN | reporting | Domain table has no core business key or FK into a core table |
| `statement_core:table:statement-run` | `statement_core` | table | OPEN | reporting | Domain table has no core business key or FK into a core table |
| `statement_recon_core:action:action-finish` | `statement_recon_core` | action | OPEN | reporting | Write paragraph with no core link (writes statement_recon_run) |
| `statement_recon_core:action:action-retry` | `statement_recon_core` | action | OPEN | reporting | Write paragraph with no core link (writes statement_recon_run) |
| `statement_recon_core:action:action-start` | `statement_recon_core` | action | OPEN | reporting | Write paragraph with no core link (writes statement_recon_run) |
| `statement_recon_core:audit:core-reference` | `statement_recon_core` | audit | OPEN | reporting | Manual: verify audit rows store a core reference (old/new value + core id); automation cannot prove semantics |
| `statement_recon_core:table:statement-archive` | `statement_recon_core` | table | OPEN | reporting | Domain table has no core business key or FK into a core table |
| `statement_recon_core:table:statement-archive-line` | `statement_recon_core` | table | OPEN | reporting | Domain table has no core business key or FK into a core table |
| `statement_recon_core:table:statement-recon-run` | `statement_recon_core` | table | OPEN | reporting | Domain table has no core business key or FK into a core table |
| `statement_recon_core:table:statement-run` | `statement_recon_core` | table | OPEN | reporting | Domain table has no core business key or FK into a core table |
| `tax_management_core:action:action-rule-create` | `tax_management_core` | action | OPEN | tax | Write paragraph with no core link (writes tax_management) |
| `tax_management_core:action:action-rule-update` | `tax_management_core` | action | OPEN | tax | Write paragraph with no core link (writes tax_management) |
| `tax_management_core:action:action-submit` | `tax_management_core` | action | OPEN | tax | Write paragraph with no core link (writes tax_management) |
| `tax_management_core:audit:core-reference` | `tax_management_core` | audit | DONE | backend | Manual: verify audit rows store a core reference (old/new value + core id); automation cannot prove semantics |
| `tax_management_core:table:tax-management` | `tax_management_core` | table | OPEN | tax | Domain table has no core business key or FK into a core table |
| `tax_management_core:table:tax-report-run` | `tax_management_core` | table | OPEN | tax | Domain table has no core business key or FK into a core table |
| `treasury_liquidity_core:action:action-cancel` | `treasury_liquidity_core` | action | OPEN | treasury | Write paragraph with no core link (writes treasury_liquidity) |
| `treasury_liquidity_core:action:action-close` | `treasury_liquidity_core` | action | OPEN | treasury | Write paragraph with no core link (writes treasury_liquidity) |
| `treasury_liquidity_core:action:action-create` | `treasury_liquidity_core` | action | OPEN | treasury | Write paragraph with no core link (writes treasury_liquidity) |
| `treasury_liquidity_core:action:action-post` | `treasury_liquidity_core` | action | OPEN | treasury | Write paragraph with no core link (writes treasury_liquidity) |
| `treasury_liquidity_core:audit:core-reference` | `treasury_liquidity_core` | audit | OPEN | treasury | Manual: verify audit rows store a core reference (old/new value + core id); automation cannot prove semantics |
| `treasury_liquidity_core:table:treasury-liquidity` | `treasury_liquidity_core` | table | OPEN | treasury | Domain table has no core business key or FK into a core table |
| `user_core:audit:core-reference` | `user_core` | audit | OPEN | backend | Manual: verify audit rows store a core reference (old/new value + core id); automation cannot prove semantics |
| `user_core:table:audit-trail` | `user_core` | table | OPEN | backend | Domain table has no core business key or FK into a core table |
| `user_core:table:mfa-backup-codes` | `user_core` | table | DONE | backend | Domain table has no core business key or FK into a core table |
| `user_core:table:notification-outbox` | `user_core` | table | WAIVED | assistant | Domain table has no core business key or FK into a core table |
| `user_core:table:refresh-sessions` | `user_core` | table | DONE | backend | Domain table has no core business key or FK into a core table |
| `user_core:table:verification-logs` | `user_core` | table | OPEN | backend | Domain table has no core business key or FK into a core table |
| `wallet_core:audit:core-reference` | `wallet_core` | audit | OPEN | wallet | Manual: verify audit rows store a core reference (old/new value + core id); automation cannot prove semantics |
| `wallet_core:table:audit-authz-denied` | `wallet_core` | table | WAIVED | assistant | Domain table has no core business key or FK into a core table |
| `wallet_core:table:audit-trail` | `wallet_core` | table | DONE | assistant | Domain table has no core business key or FK into a core table |
| `wallet_core:table:dispute-cases` | `wallet_core` | table | WAIVED | assistant | Domain table has no core business key or FK into a core table |
| `wallet_core:table:dispute-messages` | `wallet_core` | table | WAIVED | assistant | Domain table has no core business key or FK into a core table |
| `wallet_core:table:end` | `wallet_core` | table | WAIVED | assistant | Domain table has no core business key or FK into a core table |
| `wallet_core:table:exchange-rates` | `wallet_core` | table | DONE | assistant | Domain table has no core business key or FK into a core table |
| `wallet_core:table:if` | `wallet_core` | table | DONE | assistant | Domain table has no core business key or FK into a core table |
| `wallet_core:table:in` | `wallet_core` | table | DONE | assistant | Domain table has no core business key or FK into a core table |
| `wallet_core:table:not` | `wallet_core` | table | WAIVED | assistant | Domain table has no core business key or FK into a core table |
| `wallet_core:table:pending-transactions` | `wallet_core` | table | OPEN | wallet | Domain table has no core business key or FK into a core table |
| `wallet_core:table:reconciliation-runs` | `wallet_core` | table | WAIVED | assistant | Domain table has no core business key or FK into a core table |
| `wallet_core:table:reversal-fee-policy` | `wallet_core` | table | WAIVED | assistant | Domain table has no core business key or FK into a core table |
| `wallet_core:table:role-permissions` | `wallet_core` | table | WAIVED | assistant | Domain table has no core business key or FK into a core table |
| `wallet_core:table:transfer-reversals` | `wallet_core` | table | OPEN | wallet | Domain table has no core business key or FK into a core table |
| `wallet_dispute_core:action:reject-dispute-logic` | `wallet_dispute_core` | action | OPEN | backend | Write paragraph with no core link (writes audit_trail, dispute_cases) |
| `wallet_dispute_core:action:resolve-dispute-logic` | `wallet_dispute_core` | action | OPEN | backend | Write paragraph with no core link (writes audit_trail, dispute_cases) |
| `wallet_dispute_core:audit:core-reference` | `wallet_dispute_core` | audit | OPEN | backend | Manual: verify audit rows store a core reference (old/new value + core id); automation cannot prove semantics |
| `wallet_dispute_core:table:audit-trail` | `wallet_dispute_core` | table | OPEN | backend | Domain table has no core business key or FK into a core table |
| `wallet_dispute_core:table:dispute-cases` | `wallet_dispute_core` | table | OPEN | backend | Domain table has no core business key or FK into a core table |
| `wallet_dispute_core:table:dispute-messages` | `wallet_dispute_core` | table | OPEN | backend | Domain table has no core business key or FK into a core table |
| `wallet_dispute_core:table:pending-transactions` | `wallet_dispute_core` | table | OPEN | backend | Domain table has no core business key or FK into a core table |
| `wallet_hold_core:audit:core-reference` | `wallet_hold_core` | audit | OPEN | backend | Manual: verify audit rows store a core reference (old/new value + core id); automation cannot prove semantics |
| `wallet_hold_core:table:audit-trail` | `wallet_hold_core` | table | OPEN | backend | Domain table has no core business key or FK into a core table |
| `wallet_recon_core:audit:core-reference` | `wallet_recon_core` | audit | OPEN | backend | Manual: verify audit rows store a core reference (old/new value + core id); automation cannot prove semantics |
| `wallet_recon_core:table:audit-trail` | `wallet_recon_core` | table | OPEN | backend | Domain table has no core business key or FK into a core table |
| `wallet_recon_core:table:reconciliation-runs` | `wallet_recon_core` | table | OPEN | backend | Domain table has no core business key or FK into a core table |
| `wallet_recon_core:table:role-permissions` | `wallet_recon_core` | table | OPEN | backend | Domain table has no core business key or FK into a core table |
| `wallet_reversal_core:audit:core-reference` | `wallet_reversal_core` | audit | OPEN | backend | Manual: verify audit rows store a core reference (old/new value + core id); automation cannot prove semantics |
| `wallet_reversal_core:table:audit-trail` | `wallet_reversal_core` | table | OPEN | backend | Domain table has no core business key or FK into a core table |
| `wallet_reversal_core:table:reversal-fee-policy` | `wallet_reversal_core` | table | OPEN | backend | Domain table has no core business key or FK into a core table |
| `wallet_reversal_core:table:transfer-reversals` | `wallet_reversal_core` | table | OPEN | backend | Domain table has no core business key or FK into a core table |
| `wallet_statement_core:audit:core-reference` | `wallet_statement_core` | audit | OPEN | backend | Manual: verify audit rows store a core reference (old/new value + core id); automation cannot prove semantics |
| `wallet_transfer_core:action:transfer-logic` | `wallet_transfer_core` | action | WAIVED | wallet | TRANSFER-LOGIC is an orchestrator; core account/FX reads and writes moved to RESOLVE-SENDER-ACCOUNT, RESOLVE-TARGET-ACCOUNT and LOAD-TRANSFER-CONTEXT |
| `wallet_transfer_core:audit:core-reference` | `wallet_transfer_core` | audit | OPEN | wallet | Manual: verify audit rows store a core reference (old/new value + core id); automation cannot prove semantics |
| `wallet_transfer_core:table:audit-trail` | `wallet_transfer_core` | table | OPEN | wallet | Domain table has no core business key or FK into a core table |
| `wallet_transfer_core:table:exchange-rates` | `wallet_transfer_core` | table | OPEN | wallet | Domain table has no core business key or FK into a core table |
| `wallet_transfer_core:table:pending-transactions` | `wallet_transfer_core` | table | OPEN | wallet | Domain table has no core business key or FK into a core table |
