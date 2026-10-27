# Domain Overview — Cobol Banking Core

High-level map of the banking domains, their COBOL modules, and their database
tables. The full column-level catalog is in `data_dictionary.md`.

## Core platform
- `auth_core`, `auth_password_core`, `user_core`, `wallet_core`
- `ref_engine`, `ref_ext_core`, `gl_core`, `batch_core`
- `report_core`, `fee_core`, `eod_core`, `statement_core`
- `notification_core`, `alert_core`, `dashboard_core`
- Audit/compliance/ops modules (access_audit, audit_*, compliance_*, etc.)

## Lending & deposits
- `loan_core`, `loan_schedule_core` — loans, schedules, installments
- `deposit_core` — deposit accounts, accruals, transactions
- `card_core` — card accounts and transactions
- `collection_core` — collection cases and activities

## Payments & treasury
- `payment_core`, `payment_clearing_core`, `payment_hold_core`, `payment_instruction_core`
- `billpay_core`, `remittance_core`, `standing_order_core`
- `treasury_liquidity_core`, `treasury_position_core`, `fx_deal_core`, `fx_hedging_core`

## Compliance & risk
- `kyc_periodic_core`, `kyc_review_core`, `aml_screening_core`
- `sanctions_list_core`, `sanctions_hold_core`, `fraud_case_core`, `fraud_ops_core`
- `risk_screening_core`, `lbpue_core`

## Finance & accounting
- `gl_core`, `gl_allocation_core`, `gl_reval_core`, `gl_period_close_core`
- `cost_center_core`, `fixed_asset_core`, `consolidation_core`
- `budget_core`, `procurement_core`, `tax_report_core`

## Data, reporting & IT ops
- `report_core`, `report_builder_core`, `report_*`, `analytics_snapshot_core`
- `metric_definition_core`, `data_lineage_core`, `data_quality_core`, `data_retention_core`
- `backup_*`, `disaster_recovery_core`, `incident_*`, `change_*`
- `capacity_*`, `sla_tracking_core`, `slo_report_core`

## Table groups
Tables are grouped by their leading prefix in `data_dictionary.md`. Every domain
module follows the standard 9-action pattern (CREATE, LIST, GET, UPDATE,
DELETE/CLOSE, SUMMARY, AUDIT, VALIDATE, plus a domain-specific action), and
most tables have a matching `_audit` table for traceability.

## Notes
- Baseline schema: 478 tables (`database/schema.sql`).
- Migrations: 147 (latest `0147_loan_hardening`).
- Runtime database: `cobol_db` (MariaDB/MySQL).
- Application account is DML-only (`cobol_user` after `grants.sh`); migrations
  run under a separate privileged account.