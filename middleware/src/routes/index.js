import { REF_ENGINE_ROUTES } from './ref_engine.js';
import { GL_ROUTES } from './gl.js';
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
import { RECON_OPS_ROUTES } from './recon_ops.js';
import { DASHBOARD_ROUTES } from './dashboard.js';
import { IMPORT_RECON_ROUTES } from './import_recon.js';
import { RECON_EXCEPTION_ROUTES } from './recon_exception.js';
import { PAYMENT_HOLD_ROUTES } from './payment_hold.js';
import { PAYMENT_CLEARING_ROUTES } from './payment_clearing.js';
import { TREASURY_LIQUIDITY_ROUTES } from './treasury_liquidity.js';
import { GL_ALLOCATION_ROUTES } from './gl_allocation.js';
import { BACKUP_DRILL_ROUTES } from './backup_drill.js';
import { REPORT_BUILDER_ROUTES } from './report_builder.js';
import { SANCTIONS_LIST_ROUTES } from './sanctions_list.js';
import { COST_CENTER_ROUTES } from './cost_center.js';
import { FIXED_ASSET_ROUTES } from './fixed_asset.js';
import { METRIC_DEFINITION_ROUTES } from './metric_definition.js';
import { MERCHANT_ROUTES } from './merchant.js';
import { TRADE_FINANCE_ROUTES } from './trade_finance.js';
import { CCL_ROUTES } from './compliance_calendar.js';
import { ORG_ROUTES } from './organization_unit.js';
import { SYL_ROUTES } from './syndicated_loan.js';
import { OSC_ROUTES } from './outsourcing_contract.js';
import { NSC_ROUTES } from './name_screening.js';
import { VAL_ROUTES } from './valuation.js';
import { TMO_ROUTES } from './timeout.js';
import { PSTN_ROUTES } from './position_mgmt.js';
import { ORD_ROUTES } from './order_mgmt.js';
import { QTE_ROUTES } from './quote.js';
import { PF_ROUTES } from './price_feed.js';
import { RBL_ROUTES } from './rebalancing.js';
import { PTF_ROUTES } from './portfolio.js';
import { TPR_ROUTES } from './transfer_pricing.js';
import { OPTM_ROUTES } from './optimization.js';
import { SIM_ROUTES } from './simulation.js';
import { SCN_ROUTES } from './scenario.js';
import { VARA_ROUTES } from './variance.js';
import { RSV_ROUTES } from './reserve.js';
import { PC_ROUTES } from './profit_center.js';
import { TB_ROUTES } from './trial_balance.js';
import { SUS_ROUTES } from './suspense.js';
import { VOS_ROUTES } from './vostro.js';
import { NOS_ROUTES } from './nostro.js';
import { NET_ROUTES } from './netting.js';
import { RECN_ROUTES } from './reconciliation.js';
import { WDL_ROUTES } from './withdrawal.js';
import { TRFS_ROUTES } from './transfer.js';
import { PAYM_ROUTES } from './payment_processing.js';
import { TXN_ROUTES } from './transaction.js';
import { SNCS_ROUTES } from './sanctions_check.js';
import { STN_ROUTES } from './structured_note.js';
import { WRI_ROUTES } from './warrant_issuing.js';
import { MEZ_ROUTES } from './mezzanine.js';
import { PDB_ROUTES } from './private_debt.js';
import { RET_ROUTES } from './real_estate.js';
import { VCP_ROUTES } from './venture_capital.js';
import { PEQ_ROUTES } from './private_equity.js';
import { MFD_ROUTES } from './mutual_fund.js';
import { TRT_ROUTES } from './trust.js';
import { SPV_ROUTES } from './vehicle.js';
import { SPE_ROUTES } from './special_purpose.js';
import { SEC_ROUTES } from './securitization.js';
import { TRCH_ROUTES } from './tranche.js';
import { CDO_ROUTES } from './collateralized.js';
import { MBS_ROUTES } from './mortgage_backed.js';
import { STRU_ROUTES } from './structured.js';
import { WAR_ROUTES } from './warrant.js';
import { RTY_ROUTES } from './retry.js';
import { RTL_ROUTES } from './rate_limiter.js';
import { MTR_ROUTES } from './metrics.js';
import { TRC_ROUTES } from './tracing.js';
import { MON_ROUTES } from './monitoring.js';
import { SRH_ROUTES } from './search.js';
import { RCM_ROUTES } from './recommendation.js';
import { PSN_ROUTES } from './personalization.js';
import { SSS_ROUTES } from './session_store.js';
import { SVM_ROUTES } from './service_mesh.js';
import { WHK_ROUTES } from './webhook.js';
import { PSH_ROUTES } from './push_notification.js';
import { SMS_ROUTES } from './sms.js';
import { RPTG_ROUTES } from './reporting.js';
import { MET_ROUTES } from './metric.js';
import { SLV_ROUTES } from './sla_management.js';
import { SUB_ROUTES } from './subscription.js';
import { TXW_ROUTES } from './tax_withholding.js';
import { PEN_ROUTES } from './pension.js';
import { OFB_ROUTES } from './offboarding.js';
import { ONB_ROUTES } from './onboarding.js';
import { REC_ROUTES } from './recruitment.js';
import { TRN_ROUTES } from './training.js';
import { PER_ROUTES } from './performance.js';
import { POS_ROUTES } from './position.js';
import { PRF_ROUTES } from './profit.js';
import { REV_ROUTES } from './revenue.js';
import { PNL_ROUTES } from './pnl.js';
import { PRG_ROUTES } from './pricing.js';
import { VOL_ROUTES } from './volatility.js';
import { VRS_ROUTES } from './variance_swap.js';
import { TRS_ROUTES } from './total_return_swap.js';
import { MCC_ROUTES } from './multi_currency.js';
import { NDP_ROUTES } from './notice_deposit.js';
import { RDP_ROUTES } from './recurring_deposit.js';
import { TDP_ROUTES } from './term_deposit.js';
import { SAV_ROUTES } from './savings_account.js';
import { PEP_ROUTES } from './pep_screening.js';
import { WTC_ROUTES } from './watchlist.js';
import { WHT_ROUTES } from './whitelist.js';
import { RKS_ROUTES } from './risk_score.js';
import { VLC_ROUTES } from './velocity_check.js';
import { TXL_ROUTES } from './transaction_limit.js';
import { PWP_ROUTES } from './password_policy.js';
import { MFA_ROUTES } from './mfa_management.js';
import { OTP_ROUTES } from './otp_management.js';
import { TKM_ROUTES } from './token_management.js';
import { SSM_ROUTES } from './session_management.js';
import { QRP_ROUTES } from './qr_payment.js';
import { PML_ROUTES } from './payment_link.js';
import { VRC_ROUTES } from './virtual_card.js';
import { PPC_ROUTES } from './prepaid_card.js';
import { PTR_ROUTES } from './points_redemption.js';
import { CSB_ROUTES } from './cashback.js';
import { RWD_ROUTES } from './rewards_management.js';
import { LYP_ROUTES } from './loyalty_program.js';
import { LOY_ROUTES } from './loyalty.js';
import { VDM_ROUTES } from './vendor_management.js';
import { WHB_ROUTES } from './whistleblowing.js';
import { SST_ROUTES } from './stress_test.js';
import { RSM_ROUTES } from './risk_model.js';
import { PRV_ROUTES } from './provisioning.js';
import { WOF_ROUTES } from './write_off.js';
import { CRP_ROUTES } from './collateral_repossession.js';
import { PAD_ROUTES } from './policy_administration.js';
import { RIC_ROUTES } from './reinsurance_contract.js';
import { STP_ROUTES } from './structured_product.js';
import { SEL_ROUTES } from './securities_lending.js';
import { RPO_ROUTES } from './repo_agreement.js';
import { OPT_ROUTES } from './option_trading.js';
import { SWP_ROUTES } from './swap_contract.js';
import { TLR_ROUTES } from './teller_management.js';
import { VLT_ROUTES } from './vault_management.js';
import { RFP_ROUTES } from './refund_processing.js';
import { CHB_ROUTES } from './chargeback.js';
import { DSM_ROUTES } from './dispute_management.js';
import { PIS_ROUTES } from './pisp_management.js';
import { OPN_ROUTES } from './open_banking.js';
import { NFT_ROUTES } from './nft_management.js';
import { SMC_ROUTES } from './smart_contract.js';
import { TKN_ROUTES } from './tokenization.js';
import { PMS_ROUTES } from './permission_set.js';
import { RLM_ROUTES } from './role_management.js';
import { UAC_ROUTES } from './user_activity.js';
import { SGC_ROUTES } from './system_config.js';
import { TXM_ROUTES } from './tax_management.js';
import { RTM_ROUTES } from './rate_management.js';
import { MBW_ROUTES } from './mobile_wallet.js';
import { PWG_ROUTES } from './payment_gateway.js';
import { MCS_ROUTES } from './merchant_settlement.js';
import { WLM_ROUTES } from './wealth_management.js';
import { PRL_ROUTES } from './payroll_processing.js';
import { SCF_ROUTES } from './supply_chain_finance.js';
import { BKG_ROUTES } from './bank_guarantee.js';
import { LOC_ROUTES } from './letter_of_credit.js';
import { POM_ROUTES } from './portfolio_management.js';
import { ASM_ROUTES } from './asset_management.js';
import { SLT_ROUTES } from './sla_tracker.js';
import { RPS_ROUTES } from './report_schedule.js';
import { NTP_ROUTES } from './notification_template.js';
import { SIN_ROUTES } from './standing_instruction.js';
import { CLM_ROUTES } from './collateral_mgmt.js';
import { TSD_ROUTES } from './treasury_deal.js';
import { PRODUCT_CATALOG_ROUTES } from './product_catalog.js';
import { CLT_ROUTES } from './collateral.js';
import { STO_ROUTES } from './standing_order.js';
import { RMT_ROUTES } from './remittance.js';
import { WFA_ROUTES } from './workflow_approval.js';
import { ACCOUNT_ROUTES } from './account.js';
import { ONCALL_DELIVERY_ROUTES } from './oncall_delivery.js';
import { RETENTION_JOB_ROUTES } from './retention_job.js';
import { REPORT_SCHEDULER_ROUTES } from './report_scheduler.js';
import { REPORT_ARCHIVE_ROUTES } from './report_archive.js';
import { REGULATORY_REPORT_ROUTES } from './regulatory_report.js';
import { LOAN_ROUTES } from './loan.js';
import { LOAN_SCHEDULE_ROUTES } from './loan_schedule.js';
import { DEPOSIT_ROUTES } from './deposit.js';
import { CARD_ROUTES } from './card.js';
import { COLLECTION_ROUTES } from './collection.js';
import { TAX_REPORT_ROUTES } from './tax_report.js';
import { SANCTIONS_HOLD_ROUTES } from './sanctions_hold.js';
import { RISK_SCREENING_ROUTES } from './risk_screening.js';
import { POLICY_ATTESTATION_ROUTES } from './policy_attestation.js';
import { REGULATORY_CALENDAR_ROUTES } from './regulatory_calendar.js';
import { VENDOR_ROUTES } from './vendor.js';
import { VENDOR_RISK_ROUTES } from './vendor_risk.js';
import { PROCUREMENT_ROUTES } from './procurement.js';
import { TREASURY_POSITION_ROUTES } from './treasury_position.js';
import { SETTLEMENT_RECON_ROUTES } from './settlement_recon.js';
import { STATEMENT_DELIVERY_ROUTES } from './statement_delivery.js';
import { STATEMENT_RECON_ROUTES } from './statement_recon.js';
import { PAYMENT_INSTRUCTION_ROUTES } from './payment_instructions.js';
import { ONCALL_ROUTES } from './oncall.js';
import { SLO_REPORT_ROUTES } from './slo_report.js';
import { PIPELINE_ALERT_ROUTES } from './pipeline_alert.js';
import { SECRET_ROTATION_ROUTES } from './secret_rotation.js';
import { VENDOR_COMPLIANCE_ROUTES } from './vendor_compliance.js';
import { NOTIFICATION_AUDIT_ROUTES } from './notification_audit.js';
import { REPORT_AUDIT_ROUTES } from './report_audit.js';
import { SLA_TRACKING_ROUTES } from './sla_tracking.js';
import { REOP_ROUTES } from './reopening_item.js';
import { MIG_ROUTES } from './migration.js';
import { NCL_ROUTES } from './nano_lending.js';
import { PDLG_ROUTES } from './peer_lending.js';
import { MCL_ROUTES } from './micro_lending.js';
import { MTB_ROUTES } from './mortgage_bank.js';
import { THR_ROUTES } from './thrift.js';
import { SVB_ROUTES } from './savings_bank.js';
import { MBK_ROUTES } from './mobile_banking.js';
import { WSB_ROUTES } from './wholesale_banking.js';
import { PRVB_ROUTES } from './private_banking.js';
import { RTB_ROUTES } from './retail_banking.js';
import { QLT_ROUTES } from './quality.js';
import { TST_ROUTES } from './testing.js';
import { RSH_ROUTES } from './research.js';
import { STG_ROUTES } from './strategy.js';
import { PLN2_ROUTES } from './planning.js';
import { PYBL_ROUTES } from './payable.js';
import { REC2_ROUTES } from './receivable.js';
import { PYM2_ROUTES } from './payment_mgmt.js';
import { ORD2_ROUTES } from './order_mgmt2.js';
import { TRK_ROUTES } from './tracking.js';
import { SHP_ROUTES } from './shipping.js';
import { WHS_ROUTES } from './warehouse.js';
import { STK_ROUTES } from './stock.js';
import { PUR_ROUTES } from './purchasing.js';
import { PRCM_ROUTES } from './procurement_mgmt.js';
import { SPL_ROUTES } from './supplier.js';
import { VDR_ROUTES } from './vendor_mgmt.js';
import { SR_ROUTES } from './surety.js';
import { PRK_ROUTES } from './professional_risk.js';
import { POL_ROUTES } from './political_risk.js';
import { PUL_ROUTES } from './public_liability.js';
import { PDL_ROUTES } from './product_liability.js';
import { PIN_ROUTES } from './professional_indemnity.js';
import { THF_ROUTES } from './theft_insurance.js';
import { TRV_ROUTES } from './travel_insurance.js';
import { PTY_ROUTES } from './property_insurance.js';
import { ROL_ROUTES } from './rollback.js';
import { UPG_ROUTES } from './upgrade.js';
import { PCH_ROUTES } from './patch.js';
import { REL_ROUTES } from './release_mgmt.js';
import { PRB_ROUTES } from './problem.js';
import { NTFC_ROUTES } from './notification_mgmt.js';
import { SUB2_ROUTES } from './submission.js';
import { REGN_ROUTES } from './registration.js';
import { PRM_ROUTES } from './permit.js';
import { TRR_ROUTES } from './training_record.js';
import { PRR_ROUTES } from './procedure_review.js';
import { PLR_ROUTES } from './policy_review.js';
import { RSA_ROUTES } from './risk_assessment.js';
import { RGF_ROUTES } from './regulatory_filing.js';
import { WRT_ROUTES } from './warranty.js';
import { MSP_ROUTES } from './milestone_payment.js';
import { RTMN_ROUTES } from './retention_money.js';
import { PBD_ROUTES } from './performance_bond.js';
import { PMN_ROUTES } from './promissory_note.js';
import { BAC_ROUTES } from './bankers_acceptance.js';
import { DCRD_ROUTES } from './documentary_credit.js';
import { IMF_ROUTES } from './import_finance.js';
import { EXF_ROUTES } from './export_finance.js';
import { TCR_ROUTES } from './trade_credit.js';
import { SCFN_ROUTES } from './supply_chain.js';
import { P2P_ROUTES } from './peer_to_peer.js';
import { MCF_ROUTES } from './microfinance.js';
import { PWN_ROUTES } from './pawn.js';
import { FCT_ROUTES } from './factoring.js';
import { ODR_ROUTES } from './overdraft.js';
import { PLN_ROUTES } from './personal_loan.js';
import { MTG_ROUTES } from './mortgage.js';
import { TERM_ROUTES } from './termination_item.js';
import { SPN_ROUTES } from './suspension_item.js';
import { RVRSL_ROUTES } from './reversal_item.js';
import { RFND_ROUTES } from './refund_item.js';
import { RBT_ROUTES } from './rebate_item.js';
import { TAXS_ROUTES } from './tax_item.js';
import { PENL_ROUTES } from './penalty_item.js';
import { ACST_ROUTES } from './statement_item.js';
import { TXNS_ROUTES } from './transaction_item.js';
import { TRNF_ROUTES } from './transfer_item.js';
import { PYMT_ROUTES } from './payment_item.js';
import { PRDT_ROUTES } from './product_item.js';

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
  ...NOTIFICATION_ROUTES,
  ...PAYMENT_ROUTES,
  ...RECON_ROUTES,
  ...REPORT_DELIVERY_ROUTES,
  ...RECON_OPS_ROUTES,
  ...DASHBOARD_ROUTES,
  ...IMPORT_RECON_ROUTES,
  ...RECON_EXCEPTION_ROUTES,
  ...PAYMENT_HOLD_ROUTES,
  ...PAYMENT_CLEARING_ROUTES,
  ...TREASURY_LIQUIDITY_ROUTES,
  ...GL_ALLOCATION_ROUTES,
  ...BACKUP_DRILL_ROUTES,
  ...REPORT_BUILDER_ROUTES,
  ...SANCTIONS_LIST_ROUTES,
  ...COST_CENTER_ROUTES,
  ...FIXED_ASSET_ROUTES,
  ...METRIC_DEFINITION_ROUTES,
  ...MERCHANT_ROUTES,
  ...TRADE_FINANCE_ROUTES,
  ...CCL_ROUTES,
  ...ORG_ROUTES,
  ...SYL_ROUTES,
  ...OSC_ROUTES,
  ...NSC_ROUTES,
  ...VAL_ROUTES,
  ...TMO_ROUTES,
  ...PSTN_ROUTES,
  ...ORD_ROUTES,
  ...QTE_ROUTES,
  ...PF_ROUTES,
  ...RBL_ROUTES,
  ...PTF_ROUTES,
  ...TPR_ROUTES,
  ...OPTM_ROUTES,
  ...SIM_ROUTES,
  ...SCN_ROUTES,
  ...VARA_ROUTES,
  ...RSV_ROUTES,
  ...PC_ROUTES,
  ...TB_ROUTES,
  ...SUS_ROUTES,
  ...VOS_ROUTES,
  ...NOS_ROUTES,
  ...NET_ROUTES,
  ...RECN_ROUTES,
  ...WDL_ROUTES,
  ...TRFS_ROUTES,
  ...PAYM_ROUTES,
  ...TXN_ROUTES,
  ...SNCS_ROUTES,
  ...STN_ROUTES,
  ...WRI_ROUTES,
  ...MEZ_ROUTES,
  ...PDB_ROUTES,
  ...RET_ROUTES,
  ...VCP_ROUTES,
  ...PEQ_ROUTES,
  ...MFD_ROUTES,
  ...TRT_ROUTES,
  ...SPV_ROUTES,
  ...SPE_ROUTES,
  ...SEC_ROUTES,
  ...TRCH_ROUTES,
  ...CDO_ROUTES,
  ...MBS_ROUTES,
  ...STRU_ROUTES,
  ...WAR_ROUTES,
  ...RTY_ROUTES,
  ...RTL_ROUTES,
  ...MTR_ROUTES,
  ...TRC_ROUTES,
  ...MON_ROUTES,
  ...SRH_ROUTES,
  ...RCM_ROUTES,
  ...PSN_ROUTES,
  ...SSS_ROUTES,
  ...SVM_ROUTES,
  ...WHK_ROUTES,
  ...PSH_ROUTES,
  ...SMS_ROUTES,
  ...RPTG_ROUTES,
  ...MET_ROUTES,
  ...SLV_ROUTES,
  ...SUB_ROUTES,
  ...TXW_ROUTES,
  ...PEN_ROUTES,
  ...OFB_ROUTES,
  ...ONB_ROUTES,
  ...REC_ROUTES,
  ...TRN_ROUTES,
  ...PER_ROUTES,
  ...POS_ROUTES,
  ...PRF_ROUTES,
  ...REV_ROUTES,
  ...PNL_ROUTES,
  ...PRG_ROUTES,
  ...VOL_ROUTES,
  ...VRS_ROUTES,
  ...TRS_ROUTES,
  ...MCC_ROUTES,
  ...NDP_ROUTES,
  ...RDP_ROUTES,
  ...TDP_ROUTES,
  ...SAV_ROUTES,
  ...PEP_ROUTES,
  ...WTC_ROUTES,
  ...WHT_ROUTES,
  ...RKS_ROUTES,
  ...VLC_ROUTES,
  ...TXL_ROUTES,
  ...PWP_ROUTES,
  ...MFA_ROUTES,
  ...OTP_ROUTES,
  ...TKM_ROUTES,
  ...SSM_ROUTES,
  ...QRP_ROUTES,
  ...PML_ROUTES,
  ...VRC_ROUTES,
  ...PPC_ROUTES,
  ...PTR_ROUTES,
  ...CSB_ROUTES,
  ...RWD_ROUTES,
  ...LYP_ROUTES,
  ...LOY_ROUTES,
  ...VDM_ROUTES,
  ...WHB_ROUTES,
  ...SST_ROUTES,
  ...RSM_ROUTES,
  ...PRV_ROUTES,
  ...WOF_ROUTES,
  ...CRP_ROUTES,
  ...PAD_ROUTES,
  ...RIC_ROUTES,
  ...STP_ROUTES,
  ...SEL_ROUTES,
  ...RPO_ROUTES,
  ...OPT_ROUTES,
  ...SWP_ROUTES,
  ...TLR_ROUTES,
  ...VLT_ROUTES,
  ...RFP_ROUTES,
  ...CHB_ROUTES,
  ...DSM_ROUTES,
  ...PIS_ROUTES,
  ...OPN_ROUTES,
  ...NFT_ROUTES,
  ...SMC_ROUTES,
  ...TKN_ROUTES,
  ...PMS_ROUTES,
  ...RLM_ROUTES,
  ...UAC_ROUTES,
  ...SGC_ROUTES,
  ...TXM_ROUTES,
  ...RTM_ROUTES,
  ...MBW_ROUTES,
  ...PWG_ROUTES,
  ...MCS_ROUTES,
  ...WLM_ROUTES,
  ...PRL_ROUTES,
  ...SCF_ROUTES,
  ...BKG_ROUTES,
  ...LOC_ROUTES,
  ...POM_ROUTES,
  ...ASM_ROUTES,
  ...SLT_ROUTES,
  ...RPS_ROUTES,
  ...NTP_ROUTES,
  ...SIN_ROUTES,
  ...CLM_ROUTES,
  ...TSD_ROUTES,
  ...PRODUCT_CATALOG_ROUTES,
  ...ACCOUNT_ROUTES,
  ...WFA_ROUTES,
  ...RMT_ROUTES,
  ...STO_ROUTES,
  ...CLT_ROUTES,
  ...ONCALL_DELIVERY_ROUTES,
  ...RETENTION_JOB_ROUTES,
  ...REPORT_SCHEDULER_ROUTES,
  ...REPORT_ARCHIVE_ROUTES,
  ...REGULATORY_REPORT_ROUTES,
  ...LOAN_ROUTES,
  ...LOAN_SCHEDULE_ROUTES,
  ...DEPOSIT_ROUTES,
  ...CARD_ROUTES,
  ...TAX_REPORT_ROUTES,
  ...SANCTIONS_HOLD_ROUTES,
  ...RISK_SCREENING_ROUTES,
  ...POLICY_ATTESTATION_ROUTES,
  ...REGULATORY_CALENDAR_ROUTES,
  ...VENDOR_ROUTES,
  ...VENDOR_RISK_ROUTES,
  ...PROCUREMENT_ROUTES,
  ...TREASURY_POSITION_ROUTES,
  ...SETTLEMENT_RECON_ROUTES,
  ...STATEMENT_DELIVERY_ROUTES,
  ...STATEMENT_RECON_ROUTES,
  ...PAYMENT_INSTRUCTION_ROUTES,
  ...ONCALL_ROUTES,
  ...SLO_REPORT_ROUTES,
  ...PIPELINE_ALERT_ROUTES,
  ...SECRET_ROTATION_ROUTES,
  ...VENDOR_COMPLIANCE_ROUTES,
  ...NOTIFICATION_AUDIT_ROUTES,
  ...REPORT_AUDIT_ROUTES,
  ...SLA_TRACKING_ROUTES,
  ...REOP_ROUTES,
  ...MIG_ROUTES,
  ...NCL_ROUTES,
  ...PDLG_ROUTES,
  ...MCL_ROUTES,
  ...MTB_ROUTES,
  ...THR_ROUTES,
  ...SVB_ROUTES,
  ...MBK_ROUTES,
  ...WSB_ROUTES,
  ...PRVB_ROUTES,
  ...RTB_ROUTES,
  ...QLT_ROUTES,
  ...TST_ROUTES,
  ...RSH_ROUTES,
  ...STG_ROUTES,
  ...PLN2_ROUTES,
  ...PYBL_ROUTES,
  ...REC2_ROUTES,
  ...PYM2_ROUTES,
  ...ORD2_ROUTES,
  ...TRK_ROUTES,
  ...SHP_ROUTES,
  ...WHS_ROUTES,
  ...STK_ROUTES,
  ...PUR_ROUTES,
  ...PRCM_ROUTES,
  ...SPL_ROUTES,
  ...VDR_ROUTES,
  ...SR_ROUTES,
  ...PRK_ROUTES,
  ...POL_ROUTES,
  ...PUL_ROUTES,
  ...PDL_ROUTES,
  ...PIN_ROUTES,
  ...THF_ROUTES,
  ...TRV_ROUTES,
  ...PTY_ROUTES,
  ...ROL_ROUTES,
  ...UPG_ROUTES,
  ...PCH_ROUTES,
  ...REL_ROUTES,
  ...PRB_ROUTES,
  ...NTFC_ROUTES,
  ...SUB2_ROUTES,
  ...REGN_ROUTES,
  ...PRM_ROUTES,
  ...TRR_ROUTES,
  ...PRR_ROUTES,
  ...PLR_ROUTES,
  ...RSA_ROUTES,
  ...RGF_ROUTES,
  ...WRT_ROUTES,
  ...MSP_ROUTES,
  ...RTMN_ROUTES,
  ...PBD_ROUTES,
  ...PMN_ROUTES,
  ...BAC_ROUTES,
  ...DCRD_ROUTES,
  ...IMF_ROUTES,
  ...EXF_ROUTES,
  ...TCR_ROUTES,
  ...SCFN_ROUTES,
  ...P2P_ROUTES,
  ...MCF_ROUTES,
  ...PWN_ROUTES,
  ...FCT_ROUTES,
  ...ODR_ROUTES,
  ...PLN_ROUTES,
  ...MTG_ROUTES,
  ...TERM_ROUTES,
  ...SPN_ROUTES,
  ...RVRSL_ROUTES,
  ...RFND_ROUTES,
  ...RBT_ROUTES,
  ...TAXS_ROUTES,
  ...PENL_ROUTES,
  ...ACST_ROUTES,
  ...TXNS_ROUTES,
  ...TRNF_ROUTES,
  ...PYMT_ROUTES,
  ...PRDT_ROUTES,
  ...COLLECTION_ROUTES,
];
