# Domain Overview — Cobol Banking Core

High-level map of the banking domains, their COBOL modules, and their database
tables. The full module inventory is in [MODULE_INDEX.md](MODULE_INDEX.md); the
column-level catalog is in [DATA_DICTIONARY.md](DATA_DICTIONARY.md).

## Core platform

- `auth_core`, `auth_password_core`, `user_core`, `wallet_core`
- Auth family: `auth_mfa_core` (MFA enrollment + backup codes),
  `auth_session_core` (session/token engine, ADR-0010 split from `auth_core`),
  `auth_recovery_core` (MFA/operation recovery workflow),
  `auth_review_core` (access reviews + permission checks),
  `auth_ops_core` (outbox claim + audit archive ops)
- Wallet family: `wallet_hold_core` (place/release hold),
  `wallet_dispute_core` (ledger dispute lifecycle),
  `wallet_recon_core` (reconciliation runs + exceptions),
  `wallet_reversal_core` (transfer reversal),
  `wallet_statement_core` (statements)
- `phone_otp_core` — OTP issue/verify/resend + device-link confirm
  (server-side delivery, see [Integrations](INTEGRATIONS.md))
- `ref_engine`, `ref_ext_core`, `gl_core`, `batch_core`
- `report_core`, `fee_core`, `eod_core`, `statement_core`
- `notification_core`, `alert_core`, `dashboard_core`
- Audit/compliance/ops modules (access_audit, audit_*, compliance_*, etc.)

## Lending & deposits

- `loan_core`, `loan_schedule_core` — loans, schedules, installments
- Schedule splits: `loan_schedule_lifecycle_core` (approve/reject/close/
  reopen/cancel/hold/release), `loan_schedule_posting_core` (post/accrue/
  settle + forecast/adjust), `loan_schedule_report_core` (summary/export/audit)
- `deposit_core` — deposit accounts, accruals, transactions
- `card_core` — card accounts and transactions
- `collection_core` — collection cases and activities

## Merchant Acquiring (canonical)

- `merchant_core` — onboarding: create → submit KYC → approve (risk + fee
  profile) → activate (account + fee guard) → suspend/close (open-settlement
  guard). Tables: `merchant`, `merchant_fee_profile`, `merchant_audit`.
- `merchant_settlement_core` — settlement: txn ingest (fee MDR+fixed) →
  open → calc (aggregate CAPTURED unsettled) → post (payment clearing + GL
  link) → settle (paid + txn SETTLED + volume) → cancel (release).
  Tables: `merchant_transaction`, `merchant_settlement`,
  `merchant_settlement_item`.
- Routes: `/merchants*` lifecycle, `/merchant-settlements*` batch.
  Legacy generic CREATE/CALC/UPDATE/DELETE kept for compat, marked deprecated.

## Payroll Processing (canonical)

- `payroll_processing_core` — batch lifecycle: create (company/account link)
  → add item → validate (totals/accounts) → approve → process (tax rule rate,
  balance check, payments) → pay (POSTED → PAID + clearing link) → close.
  Tables: `payroll_processing`, `payroll_employee`, `payroll_item`,
  `payroll_payment`, `payroll_audit`.
- Routes: `/payrolls` + `/payrolls/:id/*` lifecycle; legacy generic
  CREATE/CALC/UPDATE/DELETE/VALIDATE kept for backward compat.

## Fixed Asset (canonical)

- `fixed_asset_core` — lifecycle: capitalize (cost/residual/life guards) →
  depreciate (straight-line, one row per period) → revalue/impair (NBV +
  accumulated adjustment, GL link) → dispose (gain/loss = proceeds − NBV,
  GL link). Tables: `fixed_asset`, `fixed_asset_depreciation`,
  `fixed_asset_disposal`, `fixed_asset_audit`.
- Routes: `/fixed-assets` + `/fixed-assets/:id/{depreciate,revalue,dispose}`;
  legacy generic CREATE/CALC/UPDATE/DELETE kept for compat, `asset_management`
  deprecated.

## Loyalty / Rewards (canonical)

- `loyalty_core` — lifecycle: create (rate/currency guards) → activate
  (DRAFT guard) → enroll (program ACTIVE + customer check) → earn
  (idempotent source, amount × earn_rate) → redeem (balance guard, GL link)
  → expire (as-of job, reverses earn rows) → adjust (signed delta, LIMIT).
  Tables: `loyalty_program` (extended), `loyalty_member`,
  `loyalty_points_ledger`, `loyalty_redemption`, `loyalty_campaign`,
  `loyalty_audit`.
- Routes: `/loyalty/programs`, `/loyalty/members`, `/loyalty/{earn,redeem,expire,adjust,validate}`, `/loyalty/{summary,audit}`.
- Deprecated (kept for backward compat): generic `loyalty_program`,
  `rewards_management`, `points_redemption`, `cashback` write paths
  (CALC/UPDATE/DELETE + stateless VALIDATE).

## Chargeback / Dispute Ops (canonical)

- `chargeback_core` — lifecycle: open (card CAPTURED check, amount cap,
  duplicate guard, 30-day deadline, HOLD ledger) → assign → evidence →
  represent (evidence + deadline guards) → accept (DEBIT + GL/PMC link) /
  reject (RELEASE) → arbitrate → close (terminal-state guard).
  Tables: `chargeback_case`, `chargeback_evidence`, `chargeback_event`,
  `chargeback_ledger`, `chargeback_audit` (shared with legacy via
  `chargeback_id` = case id).
- Routes: `/chargebacks/open`, `/:id/{assign,evidence,represent,accept,reject,arbitrate,close}`,
  `/chargebacks/cases*` list/get/summary.
- Deprecated (kept for backward compat): generic `chargeback_core` write
  paths (`CHB_CREATE/CALC/UPDATE/DELETE` on the generic table),
  `dispute_management_core` (card disputes belong here; ledger disputes stay
  in `wallet_core`).

## Payments & treasury

- `payment_core`, `payment_clearing_core`, `payment_hold_core`, `payment_instruction_core`
- `billpay_core`, `remittance_core`, `standing_order_core`
- `treasury_liquidity_core`, `treasury_position_core`, `fx_deal_core`, `fx_hedging_core`
- `fx_rate_core` — reference-rate store/serve (`FX_RATE_STORE`/`FX_RATE_GET`,
  see [FX](FX.md))

## Trade Finance (canonical)

- `letter_of_credit_core` — LC lifecycle: draft → submit → approve (credit limit)
  → issue (GL link) → amend → document → draw (accepted doc, amount cap) →
  settle (drawing + LC, GL link) → close.
  Tables: `letter_of_credit`, `lc_amendment`, `lc_document`, `lc_drawing`,
  `lc_settlement`.
- `bank_guarantee_core` — BG lifecycle: draft → submit → approve → issue →
  claim → settle → close. Tables: `bank_guarantee`, `bg_claim`.
- Routes: `/trade-finance/lc*`, `/trade-finance/bg*`.
- Deprecated generic clones (kept for compat, do not extend):
  `trade_finance_core` (TRF_), `documentary_credit`, `bankers_acceptance`,
  `export_finance`, `import_finance`, `factoring`.

## Compliance & risk

- `kyc_periodic_core`, `kyc_review_core`, `aml_screening_core`
- `sanctions_list_core`, `sanctions_hold_core`, `fraud_case_core`, `fraud_ops_core`
- `risk_screening_core`, `lbpue_core`
- `risk_core` — device/geo risk notations (`RISK_NOTE`/`RISK_STATUS`,
  see [Risk](RISK.md))
- `corp_core` — corporate LEI cache (`CORP_RESOLVE` upsert, `CORP_STATUS`
  read, see [Corporate Registry](CORPORATE.md))

## Finance & accounting

- `gl_core`, `gl_allocation_core`, `gl_reval_core`, `gl_period_close_core`
- `cost_center_core`, `fixed_asset_core`, `consolidation_core`
- `budget_core`, `procurement_core`, `tax_report_core`

## Tax Withholding (canonical)

- `tax_management_core` — rule engine (rate/fixed/threshold/max/currency/GL/
  effective/enabled) + withholding calc (threshold, max cap, duplicate-source
  guard) + post (CALCULATED → POSTED + GL link) + reverse + report runs.
  Tables: `tax_management` (extended), `tax_withholding_entry`,
  `tax_report_run`, `tax_audit`.
- Routes: `/tax/rules*`, `/tax/calculate`, `/tax/entries/:id/post|reverse`,
  `/tax/reports/run`. Deposit interest and fee paths integrate by orchestration:
  source domain posts base → `TXM_CALC` → `TXM_POST` + `GL_JOURNAL_POST`.
- Deprecated (do not use for new flows; kept for backward compat):
  `tax_withholding_core`, `tax_item_core` (generic template clones).

## Collateral Management (canonical)

- `collateral_core` is the canonical domain: register → appraise → revalue →
  pledge → allocate → release, plus repossess → dispose with GL linkage
  (`gl_journal_id`).
- Tables: `collateral`, `collateral_valuation`, `collateral_pledge`,
  `collateral_allocation`, `collateral_audit`.
- GL accounts: `1510` Repossessed Collateral, `4210` Gain on Disposal,
  `5210` Loss on Disposal. Post via `GL_JOURNAL_POST`, link via
  `CLT_REPOSSESS`/`CLT_DISPOSE` P4 (`glJournalId`).
- Deprecated (do not use for new flows; kept for backward compat):
  `collateral_mgmt_core`, `collateral_repossession_core`, `collateralized_core`.
  Their tables (`collateral_mgmt`, `collateral_repossession`,
  `collateralized`) are legacy generic clones.

## Data, reporting & IT ops

- `report_core`, `report_builder_core`, `analytics_snapshot_core`
- `report_run_core` — report run lifecycle (start/row/status/complete/fail +
  export/retry)
- `import_core` (batch lifecycle: create/validate/post/export/clone/retry;
  route `import.js` + table cases) + `import_row_core` (row stage/correct/skip)
- `backup_drill_core` — backup drill runs (create/run/validate/close + audit)
- `metric_definition_core`, `data_lineage_core`, `data_quality_core`, `data_retention_core`
- `disaster_recovery_core`, `incident_*`, `change_*`
- `capacity_*`, `sla_tracking_core`, `slo_report_core`

## Table groups

Tables are grouped by their leading prefix in `DATA_DICTIONARY.md`. Every domain
module follows the standard 9-action pattern (CREATE, LIST, GET, UPDATE,
DELETE/CLOSE, SUMMARY, AUDIT, VALIDATE, plus a domain-specific action), and
most tables have a matching `_audit` table for traceability.

## Notes

- Baseline schema: `database/schema.sql`; the table inventory is generated
  as [DATA_DICTIONARY.md](DATA_DICTIONARY.md) (counts live there, not here).
- Migration count: see the generated stats in the repo [README](../README.md).
- Runtime database: `cobol_db` (MariaDB/MySQL).
- Application account is DML-only (`cobol_user` after `grants.sh`); migrations
  run under a separate privileged account.
