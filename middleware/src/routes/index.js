import { REF_ENGINE_ROUTES } from './ref_engine.js';
import { GL_ROUTES } from './gl.js';
import { BATCH_ROUTES } from './batch.js';
import { REPORT_ROUTES } from './report.js';
import { IMPORT_ROUTES } from './import.js';
import { FEE_ROUTES } from './fee.js';
import { EOD_ROUTES } from './eod.js';
import { STATEMENT_ROUTES } from './statement.js';
import { EOD_JOB_ROUTES } from './eod_jobs.js';
import { REF_EXT_ROUTES } from './ref_ext.js';
import { NOTIFICATION_ROUTES } from './notification.js';
import { PAYMENT_ROUTES } from './payment.js';
import { RECON_ROUTES } from './recon.js';
import { REPORT_DELIVERY_ROUTES } from './report_delivery.js';
import { DISPUTE_OPS_ROUTES } from './dispute_ops.js';
import { EXPORT_ARCHIVE_ROUTES } from './export_archive.js';
import { RECON_OPS_ROUTES } from './recon_ops.js';
import { ALERT_ROUTES } from './alerts.js';
import { DASHBOARD_ROUTES } from './dashboard.js';
import { AUDIT_ANALYTICS_ROUTES } from './audit_analytics.js';
import { IMPORT_RECON_ROUTES } from './import_recon.js';
import { RECON_EXCEPTION_ROUTES } from './recon_exception.js';
import { DISPUTE_NOTIFY_ROUTES } from './dispute_notify.js';
import { EXPORT_STREAM_ROUTES } from './export_stream.js';
import { ALERT_ESCALATION_ROUTES } from './alert_escalation.js';
import { AUDIT_DRILLDOWN_ROUTES } from './audit_drilldown.js';
import { COMPLIANCE_EXPORT_ROUTES } from './compliance_export.js';
import { PAYMENT_HOLD_ROUTES } from './payment_hold.js';
import { PAYMENT_CLEARING_ROUTES } from './payment_clearing.js';
import { TREASURY_LIQUIDITY_ROUTES } from './treasury_liquidity.js';
import { KYC_PERIODIC_ROUTES } from './kyc_periodic.js';
import { GL_ALLOCATION_ROUTES } from './gl_allocation.js';
import { BACKUP_DRILL_ROUTES } from './backup_drill.js';
import { REPORT_BUILDER_ROUTES } from './report_builder.js';
import { AML_SCREENING_ROUTES } from './aml_screening.js';
import { SANCTIONS_LIST_ROUTES } from './sanctions_list.js';
import { FRAUD_CASE_ROUTES } from './fraud_case.js';
import { COST_CENTER_ROUTES } from './cost_center.js';
import { FIXED_ASSET_ROUTES } from './fixed_asset.js';
import { CONSOLIDATION_ROUTES } from './consolidation.js';
import { FX_HEDGING_ROUTES } from './fx_hedging.js';
import { BILLPAY_ROUTES } from './billpay.js';
import { INCIDENT_POSTMORTEM_ROUTES } from './incident_postmortem.js';
import { CHANGE_APPROVAL_ROUTES } from './change_approval.js';
import { CAPACITY_FORECAST_ROUTES } from './capacity_forecast.js';
import { DATA_LINEAGE_ROUTES } from './data_lineage.js';
import { METRIC_DEFINITION_ROUTES } from './metric_definition.js';
import { ANALYTICS_SNAPSHOT_ROUTES } from './analytics_snapshot.js';
import { MERCHANT_ROUTES } from './merchant.js';
import { TRADE_FINANCE_ROUTES } from './trade_finance.js';
import { DDB_ROUTES } from './direct_debit.js';
import { CCL_ROUTES } from './compliance_calendar.js';
import { ESC_ROUTES } from './escrow_account.js';
import { ORG_ROUTES } from './organization_unit.js';
import { PMS_ROUTES } from './permission_set.js';
import { RLM_ROUTES } from './role_management.js';
import { AXC_ROUTES } from './access_control.js';
import { UAC_ROUTES } from './user_activity.js';
import { SGC_ROUTES } from './system_config.js';
import { BUM_ROUTES } from './backup_management.js';
import { DTA_ROUTES } from './data_archive.js';
import { ADT_ROUTES } from './audit_trail.js';
import { TXM_ROUTES } from './tax_management.js';
import { FMM_ROUTES } from './fee_management.js';
import { RTM_ROUTES } from './rate_management.js';
import { APM_ROUTES } from './api_management.js';
import { INB_ROUTES } from './internet_banking.js';
import { DGB_ROUTES } from './digital_banking.js';
import { MBW_ROUTES } from './mobile_wallet.js';
import { PWG_ROUTES } from './payment_gateway.js';
import { MCS_ROUTES } from './merchant_settlement.js';
import { DBC_ROUTES } from './debit_card.js';
import { CRC_ROUTES } from './credit_card.js';
import { WLM_ROUTES } from './wealth_management.js';
import { PRL_ROUTES } from './payroll_processing.js';
import { SCF_ROUTES } from './supply_chain_finance.js';
import { IVC_ROUTES } from './invoice_financing.js';
import { BKG_ROUTES } from './bank_guarantee.js';
import { LOC_ROUTES } from './letter_of_credit.js';
import { BND_ROUTES } from './bond_trading.js';
import { POM_ROUTES } from './portfolio_management.js';
import { ASM_ROUTES } from './asset_management.js';
import { SLT_ROUTES } from './sla_tracker.js';
import { RPS_ROUTES } from './report_schedule.js';
import { NTP_ROUTES } from './notification_template.js';
import { SIN_ROUTES } from './standing_instruction.js';
import { CLM_ROUTES } from './collateral_mgmt.js';
import { TSD_ROUTES } from './treasury_deal.js';
import { CUSTOMER_ROUTES } from './customer.js';
import { PRODUCT_CATALOG_ROUTES } from './product_catalog.js';
import { INTEREST_RATE_ROUTES } from './interest_rate.js';
import { CLT_ROUTES } from './collateral.js';
import { STO_ROUTES } from './standing_order.js';
import { RMT_ROUTES } from './remittance.js';
import { CSM_ROUTES } from './case_management.js';
import { DOC_ROUTES } from './document.js';
import { WFA_ROUTES } from './workflow_approval.js';
import { ACCOUNT_ROUTES } from './account.js';
import { ONCALL_DELIVERY_ROUTES } from './oncall_delivery.js';
import { COMPLIANCE_RETENTION_ROUTES } from './compliance_retention.js';
import { LEGAL_HOLD_ROUTES } from './legal_hold.js';
import { KEY_ROTATION_ROUTES } from './key_rotation.js';
import { DSAR_ROUTES } from './dsar.js';
import { RETENTION_JOB_ROUTES } from './retention_job.js';
import { REPORT_SCHEDULER_ROUTES } from './report_scheduler.js';
import { AUDIT_SNAPSHOT_ROUTES } from './audit_snapshot.js';
import { REPORT_ARCHIVE_ROUTES } from './report_archive.js';
import { FRAUD_OPS_ROUTES } from './fraud_ops.js';
import { LBPUE_ROUTES } from './lbpue.js';
import { KYC_REVIEW_ROUTES } from './kyc_review.js';
import { REGULATORY_REPORT_ROUTES } from './regulatory_report.js';
import { LOAN_ROUTES } from './loan.js';
import { LOAN_SCHEDULE_ROUTES } from './loan_schedule.js';
import { DEPOSIT_ROUTES } from './deposit.js';
import { CARD_ROUTES } from './card.js';
import { COLLECTION_ROUTES } from './collection.js';
import { TAX_REPORT_ROUTES } from './tax_report.js';
import { FEE_WAIVER_ROUTES } from './fee_waiver.js';
import { LIMIT_PROFILE_ROUTES } from './limit_profile.js';
import { GL_REVAL_ROUTES } from './gl_reval.js';
import { GL_PERIOD_CLOSE_ROUTES } from './gl_period_close.js';
import { SANCTIONS_HOLD_ROUTES } from './sanctions_hold.js';
import { KYC_ROUTES } from './kyc.js';
import { RISK_SCREENING_ROUTES } from './risk_screening.js';
import { POLICY_ATTESTATION_ROUTES } from './policy_attestation.js';
import { REGULATORY_CALENDAR_ROUTES } from './regulatory_calendar.js';
import { VENDOR_ROUTES } from './vendor.js';
import { ASSET_ROUTES } from './asset.js';
import { VENDOR_RISK_ROUTES } from './vendor_risk.js';
import { ASSET_MAINTENANCE_ROUTES } from './asset_maintenance.js';
import { BUDGET_ROUTES } from './budget.js';
import { PROCUREMENT_ROUTES } from './procurement.js';
import { FX_DEAL_ROUTES } from './fx_deal.js';
import { TREASURY_POSITION_ROUTES } from './treasury_position.js';
import { SETTLEMENT_RECON_ROUTES } from './settlement_recon.js';
import { STATEMENT_DELIVERY_ROUTES } from './statement_delivery.js';
import { STATEMENT_RECON_ROUTES } from './statement_recon.js';
import { PAYMENT_INSTRUCTION_ROUTES } from './payment_instructions.js';
import { ONCALL_ROUTES } from './oncall.js';
import { SLO_REPORT_ROUTES } from './slo_report.js';
import { PIPELINE_ALERT_ROUTES } from './pipeline_alert.js';
import { INCIDENT_ROUTES } from './incident.js';
import { CHANGE_CONTROL_ROUTES } from './change_control.js';
import { BACKUP_RESTORE_ROUTES } from './backup_restore.js';
import { SECRET_ROTATION_ROUTES } from './secret_rotation.js';
import { DISASTER_RECOVERY_ROUTES } from './disaster_recovery.js';
import { CAPACITY_PLAN_ROUTES } from './capacity_plan.js';
import { AUDIT_RETENTION_ROUTES } from './audit_retention.js';
import { COMPLIANCE_AUDIT_ROUTES } from './compliance_audit.js';
import { VENDOR_COMPLIANCE_ROUTES } from './vendor_compliance.js';
import { DATA_QUALITY_ROUTES } from './data_quality.js';
import { NOTIFICATION_AUDIT_ROUTES } from './notification_audit.js';
import { REPORT_AUDIT_ROUTES } from './report_audit.js';
import { DATA_RETENTION_ROUTES } from './data_retention.js';
import { ACCESS_AUDIT_ROUTES } from './access_audit.js';
import { BACKUP_VERIFICATION_ROUTES } from './backup_verification.js';
import { SLA_TRACKING_ROUTES } from './sla_tracking.js';

export const ALL_ROUTES = [
  ...REF_ENGINE_ROUTES,
  ...GL_ROUTES,
  ...BATCH_ROUTES,
  ...REPORT_ROUTES,
  ...IMPORT_ROUTES,
  ...FEE_ROUTES,
  ...EOD_ROUTES,
  ...STATEMENT_ROUTES,
  ...EOD_JOB_ROUTES,
  ...REF_EXT_ROUTES,
  ...NOTIFICATION_ROUTES,
  ...PAYMENT_ROUTES,
  ...RECON_ROUTES,
  ...REPORT_DELIVERY_ROUTES,
  ...DISPUTE_OPS_ROUTES,
  ...EXPORT_ARCHIVE_ROUTES,
  ...RECON_OPS_ROUTES,
  ...ALERT_ROUTES,
  ...DASHBOARD_ROUTES,
  ...AUDIT_ANALYTICS_ROUTES,
  ...IMPORT_RECON_ROUTES,
  ...RECON_EXCEPTION_ROUTES,
  ...DISPUTE_NOTIFY_ROUTES,
  ...EXPORT_STREAM_ROUTES,
  ...ALERT_ESCALATION_ROUTES,
  ...AUDIT_DRILLDOWN_ROUTES,
  ...COMPLIANCE_EXPORT_ROUTES,
  ...PAYMENT_HOLD_ROUTES,
  ...PAYMENT_CLEARING_ROUTES,
  ...TREASURY_LIQUIDITY_ROUTES,
  ...KYC_PERIODIC_ROUTES,
  ...GL_ALLOCATION_ROUTES,
  ...BACKUP_DRILL_ROUTES,
  ...REPORT_BUILDER_ROUTES,
  ...AML_SCREENING_ROUTES,
  ...SANCTIONS_LIST_ROUTES,
  ...FRAUD_CASE_ROUTES,
  ...COST_CENTER_ROUTES,
  ...FIXED_ASSET_ROUTES,
  ...CONSOLIDATION_ROUTES,
  ...FX_HEDGING_ROUTES,
  ...BILLPAY_ROUTES,
  ...INCIDENT_POSTMORTEM_ROUTES,
  ...CHANGE_APPROVAL_ROUTES,
  ...CAPACITY_FORECAST_ROUTES,
  ...DATA_LINEAGE_ROUTES,
  ...METRIC_DEFINITION_ROUTES,
  ...ANALYTICS_SNAPSHOT_ROUTES,
  ...MERCHANT_ROUTES,
  ...TRADE_FINANCE_ROUTES,
  ...DDB_ROUTES,
  ...CCL_ROUTES,
  ...ESC_ROUTES,
  ...ORG_ROUTES,
  ...PMS_ROUTES,
  ...RLM_ROUTES,
  ...AXC_ROUTES,
  ...UAC_ROUTES,
  ...SGC_ROUTES,
  ...BUM_ROUTES,
  ...DTA_ROUTES,
  ...ADT_ROUTES,
  ...TXM_ROUTES,
  ...FMM_ROUTES,
  ...RTM_ROUTES,
  ...APM_ROUTES,
  ...INB_ROUTES,
  ...DGB_ROUTES,
  ...MBW_ROUTES,
  ...PWG_ROUTES,
  ...MCS_ROUTES,
  ...DBC_ROUTES,
  ...CRC_ROUTES,
  ...WLM_ROUTES,
  ...PRL_ROUTES,
  ...SCF_ROUTES,
  ...IVC_ROUTES,
  ...BKG_ROUTES,
  ...LOC_ROUTES,
  ...BND_ROUTES,
  ...POM_ROUTES,
  ...ASM_ROUTES,
  ...SLT_ROUTES,
  ...RPS_ROUTES,
  ...NTP_ROUTES,
  ...SIN_ROUTES,
  ...CLM_ROUTES,
  ...TSD_ROUTES,
  ...CUSTOMER_ROUTES,
  ...PRODUCT_CATALOG_ROUTES,
  ...INTEREST_RATE_ROUTES,
  ...ACCOUNT_ROUTES,
  ...WFA_ROUTES,
  ...DOC_ROUTES,
  ...CSM_ROUTES,
  ...RMT_ROUTES,
  ...STO_ROUTES,
  ...CLT_ROUTES,
  ...ONCALL_DELIVERY_ROUTES,
  ...COMPLIANCE_RETENTION_ROUTES,
  ...LEGAL_HOLD_ROUTES,
  ...KEY_ROTATION_ROUTES,
  ...DSAR_ROUTES,
  ...RETENTION_JOB_ROUTES,
  ...REPORT_SCHEDULER_ROUTES,
  ...AUDIT_SNAPSHOT_ROUTES,
  ...REPORT_ARCHIVE_ROUTES,
  ...FRAUD_OPS_ROUTES,
  ...LBPUE_ROUTES,
  ...KYC_REVIEW_ROUTES,
  ...REGULATORY_REPORT_ROUTES,
  ...LOAN_ROUTES,
  ...LOAN_SCHEDULE_ROUTES,
  ...DEPOSIT_ROUTES,
  ...CARD_ROUTES,
  ...TAX_REPORT_ROUTES,
  ...FEE_WAIVER_ROUTES,
  ...LIMIT_PROFILE_ROUTES,
  ...GL_REVAL_ROUTES,
  ...GL_PERIOD_CLOSE_ROUTES,
  ...SANCTIONS_HOLD_ROUTES,
  ...KYC_ROUTES,
  ...RISK_SCREENING_ROUTES,
  ...POLICY_ATTESTATION_ROUTES,
  ...REGULATORY_CALENDAR_ROUTES,
  ...VENDOR_ROUTES,
  ...ASSET_ROUTES,
  ...VENDOR_RISK_ROUTES,
  ...ASSET_MAINTENANCE_ROUTES,
  ...BUDGET_ROUTES,
  ...PROCUREMENT_ROUTES,
  ...FX_DEAL_ROUTES,
  ...TREASURY_POSITION_ROUTES,
  ...SETTLEMENT_RECON_ROUTES,
  ...STATEMENT_DELIVERY_ROUTES,
  ...STATEMENT_RECON_ROUTES,
  ...PAYMENT_INSTRUCTION_ROUTES,
  ...ONCALL_ROUTES,
  ...SLO_REPORT_ROUTES,
  ...PIPELINE_ALERT_ROUTES,
  ...INCIDENT_ROUTES,
  ...CHANGE_CONTROL_ROUTES,
  ...BACKUP_RESTORE_ROUTES,
  ...SECRET_ROTATION_ROUTES,
  ...DISASTER_RECOVERY_ROUTES,
  ...CAPACITY_PLAN_ROUTES,
  ...AUDIT_RETENTION_ROUTES,
  ...COMPLIANCE_AUDIT_ROUTES,
  ...VENDOR_COMPLIANCE_ROUTES,
  ...DATA_QUALITY_ROUTES,
  ...NOTIFICATION_AUDIT_ROUTES,
  ...REPORT_AUDIT_ROUTES,
  ...DATA_RETENTION_ROUTES,
  ...ACCESS_AUDIT_ROUTES,
  ...BACKUP_VERIFICATION_ROUTES,
  ...SLA_TRACKING_ROUTES,
  ...COLLECTION_ROUTES,
];
