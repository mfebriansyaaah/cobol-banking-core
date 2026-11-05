import { REF_ENGINE_ROUTES } from './ref_engine.js';
import { GL_ROUTES } from './gl.js';
import { REPORT_ROUTES } from './report.js';
import { IMPORT_ROUTES } from './import.js';
import { FEE_ROUTES } from './fee.js';
import { EOD_ROUTES } from './eod.js';
import { STATEMENT_ROUTES } from './statement.js';
import { EOD_JOB_ROUTES } from './eod_jobs.js';
import { REF_EXT_ROUTES } from './ref_ext.js';
import { PAYMENT_ROUTES } from './payment.js';
import { DASHBOARD_ROUTES } from './dashboard.js';
import { IMPORT_RECON_ROUTES } from './import_recon.js';
import { PAYMENT_HOLD_ROUTES } from './payment_hold.js';
import { PAYMENT_CLEARING_ROUTES } from './payment_clearing.js';
import { TREASURY_LIQUIDITY_ROUTES } from './treasury_liquidity.js';
import { GL_ALLOCATION_ROUTES } from './gl_allocation.js';
import { BACKUP_DRILL_ROUTES } from './backup_drill.js';
import { REPORT_BUILDER_ROUTES } from './report_builder.js';
import { COST_CENTER_ROUTES } from './cost_center.js';
import { FIXED_ASSET_ROUTES } from './fixed_asset.js';
import { MERCHANT_ROUTES } from './merchant.js';
import { TRADE_FINANCE_ROUTES } from './trade_finance.js';
import { CCL_ROUTES } from './compliance_calendar.js';
import { CDO_ROUTES } from './collateralized.js';
import { TXW_ROUTES } from './tax_withholding.js';
import { PTR_ROUTES } from './points_redemption.js';
import { CSB_ROUTES } from './cashback.js';
import { RWD_ROUTES } from './rewards_management.js';
import { LYP_ROUTES } from './loyalty_program.js';
import { LOY_ROUTES } from './loyalty.js';
import { CRP_ROUTES } from './collateral_repossession.js';
import { CHB_ROUTES } from './chargeback.js';
import { DSM_ROUTES } from './dispute_management.js';
import { TXM_ROUTES } from './tax_management.js';
import { MCS_ROUTES } from './merchant_settlement.js';
import { PRL_ROUTES } from './payroll_processing.js';
import { BKG_ROUTES } from './bank_guarantee.js';
import { LOC_ROUTES } from './letter_of_credit.js';
import { ASM_ROUTES } from './asset_management.js';
import { SLT_ROUTES } from './sla_tracker.js';
import { RPS_ROUTES } from './report_schedule.js';
import { NTP_ROUTES } from './notification_template.js';
import { CLM_ROUTES } from './collateral_mgmt.js';
import { CLT_ROUTES } from './collateral.js';
import { ACCOUNT_ROUTES } from './account.js';
import { LOAN_ROUTES } from './loan.js';
import { LOAN_SCHEDULE_ROUTES } from './loan_schedule.js';
import { DEPOSIT_ROUTES } from './deposit.js';
import { CARD_ROUTES } from './card.js';
import { COLLECTION_ROUTES } from './collection.js';
import { STATEMENT_RECON_ROUTES } from './statement_recon.js';
import { PAYMENT_INSTRUCTION_ROUTES } from './payment_instructions.js';
import { BAC_ROUTES } from './bankers_acceptance.js';
import { DCRD_ROUTES } from './documentary_credit.js';
import { IMF_ROUTES } from './import_finance.js';
import { EXF_ROUTES } from './export_finance.js';
import { FCT_ROUTES } from './factoring.js';
import { TAXS_ROUTES } from './tax_item.js';

export const ALL_ROUTES = [
  ...REF_ENGINE_ROUTES,
  ...GL_ROUTES,
  ...REPORT_ROUTES,
  ...IMPORT_ROUTES,
  ...FEE_ROUTES,
  ...EOD_ROUTES,
  ...STATEMENT_ROUTES,
  ...EOD_JOB_ROUTES,
  ...REF_EXT_ROUTES,
  ...PAYMENT_ROUTES,
  ...DASHBOARD_ROUTES,
  ...IMPORT_RECON_ROUTES,
  ...PAYMENT_HOLD_ROUTES,
  ...PAYMENT_CLEARING_ROUTES,
  ...TREASURY_LIQUIDITY_ROUTES,
  ...GL_ALLOCATION_ROUTES,
  ...BACKUP_DRILL_ROUTES,
  ...REPORT_BUILDER_ROUTES,
  ...COST_CENTER_ROUTES,
  ...FIXED_ASSET_ROUTES,
  ...MERCHANT_ROUTES,
  ...TRADE_FINANCE_ROUTES,
  ...CCL_ROUTES,
  ...CDO_ROUTES,
  ...TXW_ROUTES,
  ...PTR_ROUTES,
  ...CSB_ROUTES,
  ...RWD_ROUTES,
  ...LYP_ROUTES,
  ...LOY_ROUTES,
  ...CRP_ROUTES,
  ...CHB_ROUTES,
  ...DSM_ROUTES,
  ...TXM_ROUTES,
  ...MCS_ROUTES,
  ...PRL_ROUTES,
  ...BKG_ROUTES,
  ...LOC_ROUTES,
  ...ASM_ROUTES,
  ...SLT_ROUTES,
  ...RPS_ROUTES,
  ...NTP_ROUTES,
  ...CLM_ROUTES,
  ...ACCOUNT_ROUTES,
  ...CLT_ROUTES,
  ...LOAN_ROUTES,
  ...LOAN_SCHEDULE_ROUTES,
  ...DEPOSIT_ROUTES,
  ...CARD_ROUTES,
  ...STATEMENT_RECON_ROUTES,
  ...PAYMENT_INSTRUCTION_ROUTES,
  ...BAC_ROUTES,
  ...DCRD_ROUTES,
  ...IMF_ROUTES,
  ...EXF_ROUTES,
  ...FCT_ROUTES,
  ...TAXS_ROUTES,
  ...COLLECTION_ROUTES,
];
