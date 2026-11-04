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
import { DISPUTE_OPS_ROUTES } from './dispute_ops.js';
import { EXPORT_ARCHIVE_ROUTES } from './export_archive.js';
import { RECON_OPS_ROUTES } from './recon_ops.js';
import { DASHBOARD_ROUTES } from './dashboard.js';
import { IMPORT_RECON_ROUTES } from './import_recon.js';
import { RECON_EXCEPTION_ROUTES } from './recon_exception.js';
import { DISPUTE_NOTIFY_ROUTES } from './dispute_notify.js';
import { EXPORT_STREAM_ROUTES } from './export_stream.js';
import { PAYMENT_HOLD_ROUTES } from './payment_hold.js';
import { PAYMENT_CLEARING_ROUTES } from './payment_clearing.js';
import { TREASURY_LIQUIDITY_ROUTES } from './treasury_liquidity.js';
import { KYC_PERIODIC_ROUTES } from './kyc_periodic.js';
import { GL_ALLOCATION_ROUTES } from './gl_allocation.js';
import { BACKUP_DRILL_ROUTES } from './backup_drill.js';
import { REPORT_BUILDER_ROUTES } from './report_builder.js';
import { SANCTIONS_LIST_ROUTES } from './sanctions_list.js';
import { FRAUD_CASE_ROUTES } from './fraud_case.js';
import { COST_CENTER_ROUTES } from './cost_center.js';
import { FIXED_ASSET_ROUTES } from './fixed_asset.js';
import { FX_HEDGING_ROUTES } from './fx_hedging.js';
import { INCIDENT_POSTMORTEM_ROUTES } from './incident_postmortem.js';
import { METRIC_DEFINITION_ROUTES } from './metric_definition.js';
import { MERCHANT_ROUTES } from './merchant.js';
import { TRADE_FINANCE_ROUTES } from './trade_finance.js';
import { DDB_ROUTES } from './direct_debit.js';
import { CCL_ROUTES } from './compliance_calendar.js';
import { ESC_ROUTES } from './escrow_account.js';
import { ORG_ROUTES } from './organization_unit.js';
import { SYL_ROUTES } from './syndicated_loan.js';
import { OSC_ROUTES } from './outsourcing_contract.js';
import { NSC_ROUTES } from './name_screening.js';
import { VAL_ROUTES } from './valuation.js';
import { MRG_ROUTES } from './margin.js';
import { LOG_ROUTES } from './logging.js';
import { TMO_ROUTES } from './timeout.js';
import { HEDG_ROUTES } from './hedge.js';
import { EXPS_ROUTES } from './exposure.js';
import { PSTN_ROUTES } from './position_mgmt.js';
import { FIL_ROUTES } from './fill.js';
import { EXE_ROUTES } from './execution.js';
import { ORD_ROUTES } from './order_mgmt.js';
import { QTE_ROUTES } from './quote.js';
import { PF_ROUTES } from './price_feed.js';
import { MKD_ROUTES } from './market_data.js';
import { IDXX_ROUTES } from './index_mgmt.js';
import { RBL_ROUTES } from './rebalancing.js';
import { PTF_ROUTES } from './portfolio.js';
import { INVS_ROUTES } from './investment.js';
import { TPR_ROUTES } from './transfer_pricing.js';
import { ICP_ROUTES } from './intercompany.js';
import { ELM_ROUTES } from './elimination.js';
import { DST_ROUTES } from './distribution.js';
import { OPTM_ROUTES } from './optimization.js';
import { SIM_ROUTES } from './simulation.js';
import { SCN_ROUTES } from './scenario.js';
import { VARA_ROUTES } from './variance.js';
import { FRCST_ROUTES } from './forecast.js';
import { RSV_ROUTES } from './reserve.js';
import { PC_ROUTES } from './profit_center.js';
import { IS_ROUTES } from './income_statement.js';
import { LIA_ROUTES } from './liability.js';
import { EQT_ROUTES } from './equity_account.js';
import { TB_ROUTES } from './trial_balance.js';
import { JRN_ROUTES } from './journal.js';
import { GLM_ROUTES } from './gl_master.js';
import { SUS_ROUTES } from './suspense.js';
import { VOS_ROUTES } from './vostro.js';
import { NOS_ROUTES } from './nostro.js';
import { NET_ROUTES } from './netting.js';
import { RECN_ROUTES } from './reconciliation.js';
import { WDL_ROUTES } from './withdrawal.js';
import { TRFS_ROUTES } from './transfer.js';
import { PAYM_ROUTES } from './payment_processing.js';
import { TXN_ROUTES } from './transaction.js';
import { FRDU_ROUTES } from './fraud_check.js';
import { SNCS_ROUTES } from './sanctions_check.js';
import { KYCC_ROUTES } from './kyc_check.js';
import { STN_ROUTES } from './structured_note.js';
import { WRI_ROUTES } from './warrant_issuing.js';
import { DIS_ROUTES } from './distressed.js';
import { MEZ_ROUTES } from './mezzanine.js';
import { DLL_ROUTES } from './direct_lending.js';
import { PDB_ROUTES } from './private_debt.js';
import { INF_ROUTES } from './infrastructure.js';
import { RET_ROUTES } from './real_estate.js';
import { VCP_ROUTES } from './venture_capital.js';
import { PEQ_ROUTES } from './private_equity.js';
import { HDF_ROUTES } from './hedge_fund.js';
import { MFD_ROUTES } from './mutual_fund.js';
import { ETF_ROUTES } from './etf.js';
import { FND_ROUTES } from './fund.js';
import { TRT_ROUTES } from './trust.js';
import { SPV_ROUTES } from './vehicle.js';
import { SPE_ROUTES } from './special_purpose.js';
import { SEC_ROUTES } from './securitization.js';
import { TRCH_ROUTES } from './tranche.js';
import { CDO_ROUTES } from './collateralized.js';
import { MBS_ROUTES } from './mortgage_backed.js';
import { STRU_ROUTES } from './structured.js';
import { WAR_ROUTES } from './warrant.js';
import { DRV_ROUTES } from './derivative.js';
import { EQY_ROUTES } from './equity.js';
import { RTY_ROUTES } from './retry.js';
import { RTL_ROUTES } from './rate_limiter.js';
import { HLC_ROUTES } from './health_check.js';
import { MTR_ROUTES } from './metrics.js';
import { TRC_ROUTES } from './tracing.js';
import { MON_ROUTES } from './monitoring.js';
import { IDX_ROUTES } from './indexing.js';
import { SRH_ROUTES } from './search.js';
import { RCM_ROUTES } from './recommendation.js';
import { PSN_ROUTES } from './personalization.js';
import { XPR_ROUTES } from './experiment.js';
import { FFL_ROUTES } from './feature_flag.js';
import { SSS_ROUTES } from './session_store.js';
import { LDB_ROUTES } from './load_balancer.js';
import { SVM_ROUTES } from './service_mesh.js';
import { EVB_ROUTES } from './event_bus.js';
import { MQQ_ROUTES } from './message_queue.js';
import { WHK_ROUTES } from './webhook.js';
import { IAM_ROUTES } from './in_app_message.js';
import { PSH_ROUTES } from './push_notification.js';
import { SMS_ROUTES } from './sms.js';
import { EML_ROUTES } from './email.js';
import { MDM_ROUTES } from './master_data.js';
import { DQL_ROUTES } from './dq_check.js';
import { ETL_ROUTES } from './etl.js';
import { DWH_ROUTES } from './data_warehouse.js';
import { RPTG_ROUTES } from './reporting.js';
import { MET_ROUTES } from './metric.js';
import { KPI_ROUTES } from './kpi.js';
import { SLV_ROUTES } from './sla_management.js';
import { SUB_ROUTES } from './subscription.js';
import { INVC_ROUTES } from './invoice.js';
import { TXW_ROUTES } from './tax_withholding.js';
import { PEN_ROUTES } from './pension.js';
import { OFB_ROUTES } from './offboarding.js';
import { ONB_ROUTES } from './onboarding.js';
import { REC_ROUTES } from './recruitment.js';
import { TRN_ROUTES } from './training.js';
import { PER_ROUTES } from './performance.js';
import { LEA_ROUTES } from './leave_management.js';
import { POS_ROUTES } from './position.js';
import { DPT_ROUTES } from './department.js';
import { EMP_ROUTES } from './employee.js';
import { PRF_ROUTES } from './profit.js';
import { REV_ROUTES } from './revenue.js';
import { PNL_ROUTES } from './pnl.js';
import { MTM_ROUTES } from './mark_to_market.js';
import { PRG_ROUTES } from './pricing.js';
import { GRK_ROUTES } from './greeks.js';
import { VOL_ROUTES } from './volatility.js';
import { VRS_ROUTES } from './variance_swap.js';
import { EQS_ROUTES } from './equity_swap.js';
import { TRS_ROUTES } from './total_return_swap.js';
import { IRS_ROUTES } from './interest_rate_swap.js';
import { FXS_ROUTES } from './fx_swap.js';
import { FXO_ROUTES } from './fx_option.js';
import { FXF_ROUTES } from './fx_forward.js';
import { MCC_ROUTES } from './multi_currency.js';
import { FCD_ROUTES } from './foreign_currency_deposit.js';
import { NDP_ROUTES } from './notice_deposit.js';
import { FDP_ROUTES } from './fixed_deposit.js';
import { RDP_ROUTES } from './recurring_deposit.js';
import { TDP_ROUTES } from './term_deposit.js';
import { SAV_ROUTES } from './savings_account.js';
import { PEP_ROUTES } from './pep_screening.js';
import { WTC_ROUTES } from './watchlist.js';
import { WHT_ROUTES } from './whitelist.js';
import { RKS_ROUTES } from './risk_score.js';
import { VLC_ROUTES } from './velocity_check.js';
import { TXL_ROUTES } from './transaction_limit.js';
import { LGA_ROUTES } from './login_attempt.js';
import { PWP_ROUTES } from './password_policy.js';
import { MFA_ROUTES } from './mfa_management.js';
import { OTP_ROUTES } from './otp_management.js';
import { TKM_ROUTES } from './token_management.js';
import { SSM_ROUTES } from './session_management.js';
import { DVM_ROUTES } from './device_management.js';
import { QRP_ROUTES } from './qr_payment.js';
import { PML_ROUTES } from './payment_link.js';
import { VRC_ROUTES } from './virtual_card.js';
import { PPC_ROUTES } from './prepaid_card.js';
import { GFC_ROUTES } from './gift_card.js';
import { PTR_ROUTES } from './points_redemption.js';
import { CSB_ROUTES } from './cashback.js';
import { RWD_ROUTES } from './rewards_management.js';
import { LYP_ROUTES } from './loyalty_program.js';
import { LOY_ROUTES } from './loyalty.js';
import { VDM_ROUTES } from './vendor_management.js';
import { INR_ROUTES } from './incident_report.js';
import { WHB_ROUTES } from './whistleblowing.js';
import { INV_ROUTES } from './investigation.js';
import { EXA_ROUTES } from './external_audit.js';
import { INA_ROUTES } from './internal_audit.js';
import { SST_ROUTES } from './stress_test.js';
import { RSM_ROUTES } from './risk_model.js';
import { LSR_ROUTES } from './loss_reserve.js';
import { PRV_ROUTES } from './provisioning.js';
import { WOF_ROUTES } from './write_off.js';
import { FCL_ROUTES } from './foreclosure.js';
import { CRP_ROUTES } from './collateral_repossession.js';
import { LGC_ROUTES } from './legal_case.js';
import { DRC_ROUTES } from './debt_recovery.js';
import { DCL_ROUTES } from './debt_collection.js';
import { GIN_ROUTES } from './guarantee_issuing.js';
import { PAD_ROUTES } from './policy_administration.js';
import { RIC_ROUTES } from './reinsurance_contract.js';
import { ISP_ROUTES } from './insurance_policy.js';
import { STP_ROUTES } from './structured_product.js';
import { MGT_ROUTES } from './margin_trading.js';
import { SEL_ROUTES } from './securities_lending.js';
import { RPO_ROUTES } from './repo_agreement.js';
import { OPT_ROUTES } from './option_trading.js';
import { FTC_ROUTES } from './future_contract.js';
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
import { DAS_ROUTES } from './digital_asset.js';
import { PMS_ROUTES } from './permission_set.js';
import { RLM_ROUTES } from './role_management.js';
import { UAC_ROUTES } from './user_activity.js';
import { SGC_ROUTES } from './system_config.js';
import { TXM_ROUTES } from './tax_management.js';
import { FMM_ROUTES } from './fee_management.js';
import { RTM_ROUTES } from './rate_management.js';
import { INB_ROUTES } from './internet_banking.js';
import { DGB_ROUTES } from './digital_banking.js';
import { MBW_ROUTES } from './mobile_wallet.js';
import { PWG_ROUTES } from './payment_gateway.js';
import { MCS_ROUTES } from './merchant_settlement.js';
import { DBC_ROUTES } from './debit_card.js';
import { WLM_ROUTES } from './wealth_management.js';
import { PRL_ROUTES } from './payroll_processing.js';
import { SCF_ROUTES } from './supply_chain_finance.js';
import { IVC_ROUTES } from './invoice_financing.js';
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
import { INTEREST_RATE_ROUTES } from './interest_rate.js';
import { CLT_ROUTES } from './collateral.js';
import { STO_ROUTES } from './standing_order.js';
import { RMT_ROUTES } from './remittance.js';
import { DOC_ROUTES } from './document.js';
import { WFA_ROUTES } from './workflow_approval.js';
import { ACCOUNT_ROUTES } from './account.js';
import { ONCALL_DELIVERY_ROUTES } from './oncall_delivery.js';
import { LEGAL_HOLD_ROUTES } from './legal_hold.js';
import { KEY_ROTATION_ROUTES } from './key_rotation.js';
import { DSAR_ROUTES } from './dsar.js';
import { RETENTION_JOB_ROUTES } from './retention_job.js';
import { REPORT_SCHEDULER_ROUTES } from './report_scheduler.js';
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
import { VENDOR_RISK_ROUTES } from './vendor_risk.js';
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
import { SECRET_ROTATION_ROUTES } from './secret_rotation.js';
import { DISASTER_RECOVERY_ROUTES } from './disaster_recovery.js';
import { VENDOR_COMPLIANCE_ROUTES } from './vendor_compliance.js';
import { NOTIFICATION_AUDIT_ROUTES } from './notification_audit.js';
import { REPORT_AUDIT_ROUTES } from './report_audit.js';
import { SLA_TRACKING_ROUTES } from './sla_tracking.js';
import { REOP_ROUTES } from './reopening_item.js';
import { MIG_ROUTES } from './migration.js';
import { NCL_ROUTES } from './nano_lending.js';
import { PDLG_ROUTES } from './peer_lending.js';
import { MCL_ROUTES } from './micro_lending.js';
import { HFC_ROUTES } from './housing_finance.js';
import { MTB_ROUTES } from './mortgage_bank.js';
import { FCOM_ROUTES } from './factoring_company.js';
import { LCO_ROUTES } from './leasing_company.js';
import { FCO_ROUTES } from './finance_company.js';
import { THR_ROUTES } from './thrift.js';
import { SVB_ROUTES } from './savings_bank.js';
import { IBNK_ROUTES } from './internet_banking2.js';
import { MBK_ROUTES } from './mobile_banking.js';
import { DBNK_ROUTES } from './digital_banking2.js';
import { WSB_ROUTES } from './wholesale_banking.js';
import { PRVB_ROUTES } from './private_banking.js';
import { IVB_ROUTES } from './investment_banking.js';
import { RTB_ROUTES } from './retail_banking.js';
import { QLT_ROUTES } from './quality.js';
import { TST_ROUTES } from './testing.js';
import { DEV_ROUTES } from './development.js';
import { RSH_ROUTES } from './research.js';
import { STG_ROUTES } from './strategy.js';
import { PLN2_ROUTES } from './planning.js';
import { FCM_ROUTES } from './forecast_mgmt.js';
import { EXP2_ROUTES } from './expense.js';
import { PYBL_ROUTES } from './payable.js';
import { REC2_ROUTES } from './receivable.js';
import { PYM2_ROUTES } from './payment_mgmt.js';
import { INVM_ROUTES } from './invoice_mgmt.js';
import { ORD2_ROUTES } from './order_mgmt2.js';
import { FLF_ROUTES } from './fulfillment.js';
import { TRK_ROUTES } from './tracking.js';
import { DLV_ROUTES } from './delivery.js';
import { SHP_ROUTES } from './shipping.js';
import { LOG2_ROUTES } from './logistics.js';
import { WHS_ROUTES } from './warehouse.js';
import { STK_ROUTES } from './stock.js';
import { INV2_ROUTES } from './inventory.js';
import { PUR_ROUTES } from './purchasing.js';
import { PRCM_ROUTES } from './procurement_mgmt.js';
import { SPL_ROUTES } from './supplier.js';
import { VDR_ROUTES } from './vendor_mgmt.js';
import { FID_ROUTES } from './fiduciary.js';
import { SR_ROUTES } from './surety.js';
import { EPL_ROUTES } from './employment_practices.js';
import { MNL_ROUTES } from './management_liability.js';
import { PRK_ROUTES } from './professional_risk.js';
import { EAO_ROUTES } from './errors_omissions.js';
import { FDL_ROUTES } from './fidelity.js';
import { GUA_ROUTES } from './guarantee.js';
import { POL_ROUTES } from './political_risk.js';
import { KNR_ROUTES } from './kidnap_ransom.js';
import { EMLI_ROUTES } from './employer_liability.js';
import { PUL_ROUTES } from './public_liability.js';
import { PDL_ROUTES } from './product_liability.js';
import { DOL_ROUTES } from './directors_liability.js';
import { PIN_ROUTES } from './professional_indemnity.js';
import { LIB_ROUTES } from './liability_insurance.js';
import { THF_ROUTES } from './theft_insurance.js';
import { FIR_ROUTES } from './fire_insurance.js';
import { MRN_ROUTES } from './marine_insurance.js';
import { TRV_ROUTES } from './travel_insurance.js';
import { HOM_ROUTES } from './home_insurance.js';
import { PTY_ROUTES } from './property_insurance.js';
import { HLT_ROUTES } from './health_insurance.js';
import { LIF_ROUTES } from './life_insurance.js';
import { ROL_ROUTES } from './rollback.js';
import { UPG_ROUTES } from './upgrade.js';
import { PCH_ROUTES } from './patch.js';
import { HFX_ROUTES } from './hotfix.js';
import { DEP2_ROUTES } from './deployment.js';
import { REL_ROUTES } from './release_mgmt.js';
import { PRB_ROUTES } from './problem.js';
import { INCD_ROUTES } from './incident_mgmt.js';
import { NTFC_ROUTES } from './notification_mgmt.js';
import { ESCL_ROUTES } from './escalation.js';
import { DLG_ROUTES } from './delegation.js';
import { SUB2_ROUTES } from './submission.js';
import { FIL2_ROUTES } from './filing.js';
import { REGN_ROUTES } from './registration.js';
import { PRM_ROUTES } from './permit.js';
import { LIC_ROUTES } from './license.js';
import { TRR_ROUTES } from './training_record.js';
import { PRR_ROUTES } from './procedure_review.js';
import { PLR_ROUTES } from './policy_review.js';
import { RSA_ROUTES } from './risk_assessment.js';
import { RGF_ROUTES } from './regulatory_filing.js';
import { WRT_ROUTES } from './warranty.js';
import { FNP_ROUTES } from './final_payment.js';
import { MSP_ROUTES } from './milestone_payment.js';
import { RTMN_ROUTES } from './retention_money.js';
import { PBD_ROUTES } from './performance_bond.js';
import { LOGG_ROUTES } from './letter_of_guarantee.js';
import { PMN_ROUTES } from './promissory_note.js';
import { BAC_ROUTES } from './bankers_acceptance.js';
import { DCRD_ROUTES } from './documentary_credit.js';
import { IMF_ROUTES } from './import_finance.js';
import { EXF_ROUTES } from './export_finance.js';
import { TCR_ROUTES } from './trade_credit.js';
import { SCFN_ROUTES } from './supply_chain.js';
import { IND_ROUTES } from './invoice_discounting.js';
import { P2P_ROUTES } from './peer_to_peer.js';
import { MCF_ROUTES } from './microfinance.js';
import { PWN_ROUTES } from './pawn.js';
import { HPR_ROUTES } from './hire_purchase.js';
import { LSG_ROUTES } from './leasing.js';
import { FCT_ROUTES } from './factoring.js';
import { ODR_ROUTES } from './overdraft.js';
import { PLN_ROUTES } from './personal_loan.js';
import { MTG_ROUTES } from './mortgage.js';
import { DEACT_ROUTES } from './deactivation_item.js';
import { TERM_ROUTES } from './termination_item.js';
import { SPN_ROUTES } from './suspension_item.js';
import { RVRSL_ROUTES } from './reversal_item.js';
import { RFND_ROUTES } from './refund_item.js';
import { RBT_ROUTES } from './rebate_item.js';
import { DISC_ROUTES } from './discount_item.js';
import { TAXS_ROUTES } from './tax_item.js';
import { PENL_ROUTES } from './penalty_item.js';
import { FEES_ROUTES } from './fee_item.js';
import { INTR_ROUTES } from './interest_item.js';
import { ACST_ROUTES } from './statement_item.js';
import { TXNS_ROUTES } from './transaction_item.js';
import { TRNF_ROUTES } from './transfer_item.js';
import { PYMT_ROUTES } from './payment_item.js';
import { DEPS_ROUTES } from './deposit_book.js';
import { LN_ROUTES } from './loan_account.js';
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
  ...DISPUTE_OPS_ROUTES,
  ...EXPORT_STREAM_ROUTES,
  ...EXPORT_ARCHIVE_ROUTES,
  ...RECON_OPS_ROUTES,
  ...DASHBOARD_ROUTES,
  ...IMPORT_RECON_ROUTES,
  ...RECON_EXCEPTION_ROUTES,
  ...DISPUTE_NOTIFY_ROUTES,
  ...PAYMENT_HOLD_ROUTES,
  ...PAYMENT_CLEARING_ROUTES,
  ...TREASURY_LIQUIDITY_ROUTES,
  ...KYC_PERIODIC_ROUTES,
  ...GL_ALLOCATION_ROUTES,
  ...BACKUP_DRILL_ROUTES,
  ...REPORT_BUILDER_ROUTES,
  ...SANCTIONS_LIST_ROUTES,
  ...FRAUD_CASE_ROUTES,
  ...COST_CENTER_ROUTES,
  ...FIXED_ASSET_ROUTES,
  ...FX_HEDGING_ROUTES,
  ...INCIDENT_POSTMORTEM_ROUTES,
  ...METRIC_DEFINITION_ROUTES,
  ...MERCHANT_ROUTES,
  ...TRADE_FINANCE_ROUTES,
  ...DDB_ROUTES,
  ...CCL_ROUTES,
  ...ESC_ROUTES,
  ...ORG_ROUTES,
  ...SYL_ROUTES,
  ...OSC_ROUTES,
  ...NSC_ROUTES,
  ...VAL_ROUTES,
  ...MRG_ROUTES,
  ...LOG_ROUTES,
  ...TMO_ROUTES,
  ...HEDG_ROUTES,
  ...EXPS_ROUTES,
  ...PSTN_ROUTES,
  ...FIL_ROUTES,
  ...EXE_ROUTES,
  ...ORD_ROUTES,
  ...QTE_ROUTES,
  ...PF_ROUTES,
  ...MKD_ROUTES,
  ...IDXX_ROUTES,
  ...RBL_ROUTES,
  ...PTF_ROUTES,
  ...INVS_ROUTES,
  ...TPR_ROUTES,
  ...ICP_ROUTES,
  ...ELM_ROUTES,
  ...DST_ROUTES,
  ...OPTM_ROUTES,
  ...SIM_ROUTES,
  ...SCN_ROUTES,
  ...VARA_ROUTES,
  ...FRCST_ROUTES,
  ...RSV_ROUTES,
  ...PC_ROUTES,
  ...IS_ROUTES,
  ...LIA_ROUTES,
  ...EQT_ROUTES,
  ...TB_ROUTES,
  ...JRN_ROUTES,
  ...GLM_ROUTES,
  ...SUS_ROUTES,
  ...VOS_ROUTES,
  ...NOS_ROUTES,
  ...NET_ROUTES,
  ...RECN_ROUTES,
  ...WDL_ROUTES,
  ...TRFS_ROUTES,
  ...PAYM_ROUTES,
  ...TXN_ROUTES,
  ...FRDU_ROUTES,
  ...SNCS_ROUTES,
  ...KYCC_ROUTES,
  ...STN_ROUTES,
  ...WRI_ROUTES,
  ...DIS_ROUTES,
  ...MEZ_ROUTES,
  ...DLL_ROUTES,
  ...PDB_ROUTES,
  ...INF_ROUTES,
  ...RET_ROUTES,
  ...VCP_ROUTES,
  ...PEQ_ROUTES,
  ...HDF_ROUTES,
  ...MFD_ROUTES,
  ...ETF_ROUTES,
  ...FND_ROUTES,
  ...TRT_ROUTES,
  ...SPV_ROUTES,
  ...SPE_ROUTES,
  ...SEC_ROUTES,
  ...TRCH_ROUTES,
  ...CDO_ROUTES,
  ...MBS_ROUTES,
  ...STRU_ROUTES,
  ...WAR_ROUTES,
  ...DRV_ROUTES,
  ...EQY_ROUTES,
  ...RTY_ROUTES,
  ...RTL_ROUTES,
  ...HLC_ROUTES,
  ...MTR_ROUTES,
  ...TRC_ROUTES,
  ...MON_ROUTES,
  ...IDX_ROUTES,
  ...SRH_ROUTES,
  ...RCM_ROUTES,
  ...PSN_ROUTES,
  ...XPR_ROUTES,
  ...FFL_ROUTES,
  ...SSS_ROUTES,
  ...LDB_ROUTES,
  ...SVM_ROUTES,
  ...EVB_ROUTES,
  ...MQQ_ROUTES,
  ...WHK_ROUTES,
  ...IAM_ROUTES,
  ...PSH_ROUTES,
  ...SMS_ROUTES,
  ...EML_ROUTES,
  ...MDM_ROUTES,
  ...DQL_ROUTES,
  ...ETL_ROUTES,
  ...DWH_ROUTES,
  ...RPTG_ROUTES,
  ...MET_ROUTES,
  ...KPI_ROUTES,
  ...SLV_ROUTES,
  ...SUB_ROUTES,
  ...INVC_ROUTES,
  ...TXW_ROUTES,
  ...PEN_ROUTES,
  ...OFB_ROUTES,
  ...ONB_ROUTES,
  ...REC_ROUTES,
  ...TRN_ROUTES,
  ...PER_ROUTES,
  ...LEA_ROUTES,
  ...POS_ROUTES,
  ...DPT_ROUTES,
  ...EMP_ROUTES,
  ...PRF_ROUTES,
  ...REV_ROUTES,
  ...PNL_ROUTES,
  ...MTM_ROUTES,
  ...PRG_ROUTES,
  ...GRK_ROUTES,
  ...VOL_ROUTES,
  ...VRS_ROUTES,
  ...EQS_ROUTES,
  ...TRS_ROUTES,
  ...IRS_ROUTES,
  ...FXS_ROUTES,
  ...FXO_ROUTES,
  ...FXF_ROUTES,
  ...MCC_ROUTES,
  ...FCD_ROUTES,
  ...NDP_ROUTES,
  ...FDP_ROUTES,
  ...RDP_ROUTES,
  ...TDP_ROUTES,
  ...SAV_ROUTES,
  ...PEP_ROUTES,
  ...WTC_ROUTES,
  ...WHT_ROUTES,
  ...RKS_ROUTES,
  ...VLC_ROUTES,
  ...TXL_ROUTES,
  ...LGA_ROUTES,
  ...PWP_ROUTES,
  ...MFA_ROUTES,
  ...OTP_ROUTES,
  ...TKM_ROUTES,
  ...SSM_ROUTES,
  ...DVM_ROUTES,
  ...QRP_ROUTES,
  ...PML_ROUTES,
  ...VRC_ROUTES,
  ...PPC_ROUTES,
  ...GFC_ROUTES,
  ...PTR_ROUTES,
  ...CSB_ROUTES,
  ...RWD_ROUTES,
  ...LYP_ROUTES,
  ...LOY_ROUTES,
  ...VDM_ROUTES,
  ...INR_ROUTES,
  ...WHB_ROUTES,
  ...INV_ROUTES,
  ...EXA_ROUTES,
  ...INA_ROUTES,
  ...SST_ROUTES,
  ...RSM_ROUTES,
  ...LSR_ROUTES,
  ...PRV_ROUTES,
  ...WOF_ROUTES,
  ...FCL_ROUTES,
  ...CRP_ROUTES,
  ...LGC_ROUTES,
  ...DRC_ROUTES,
  ...DCL_ROUTES,
  ...GIN_ROUTES,
  ...PAD_ROUTES,
  ...RIC_ROUTES,
  ...ISP_ROUTES,
  ...STP_ROUTES,
  ...MGT_ROUTES,
  ...SEL_ROUTES,
  ...RPO_ROUTES,
  ...OPT_ROUTES,
  ...FTC_ROUTES,
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
  ...DAS_ROUTES,
  ...PMS_ROUTES,
  ...RLM_ROUTES,
  ...UAC_ROUTES,
  ...SGC_ROUTES,
  ...TXM_ROUTES,
  ...FMM_ROUTES,
  ...RTM_ROUTES,
  ...INB_ROUTES,
  ...DGB_ROUTES,
  ...MBW_ROUTES,
  ...PWG_ROUTES,
  ...MCS_ROUTES,
  ...DBC_ROUTES,
  ...WLM_ROUTES,
  ...PRL_ROUTES,
  ...SCF_ROUTES,
  ...IVC_ROUTES,
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
  ...INTEREST_RATE_ROUTES,
  ...ACCOUNT_ROUTES,
  ...WFA_ROUTES,
  ...DOC_ROUTES,
  ...RMT_ROUTES,
  ...STO_ROUTES,
  ...CLT_ROUTES,
  ...ONCALL_DELIVERY_ROUTES,
  ...LEGAL_HOLD_ROUTES,
  ...KEY_ROTATION_ROUTES,
  ...DSAR_ROUTES,
  ...RETENTION_JOB_ROUTES,
  ...REPORT_SCHEDULER_ROUTES,
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
  ...VENDOR_RISK_ROUTES,
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
  ...SECRET_ROTATION_ROUTES,
  ...DISASTER_RECOVERY_ROUTES,
  ...VENDOR_COMPLIANCE_ROUTES,
  ...NOTIFICATION_AUDIT_ROUTES,
  ...REPORT_AUDIT_ROUTES,
  ...SLA_TRACKING_ROUTES,
  ...REOP_ROUTES,
  ...MIG_ROUTES,
  ...NCL_ROUTES,
  ...PDLG_ROUTES,
  ...MCL_ROUTES,
  ...HFC_ROUTES,
  ...MTB_ROUTES,
  ...FCOM_ROUTES,
  ...LCO_ROUTES,
  ...FCO_ROUTES,
  ...THR_ROUTES,
  ...SVB_ROUTES,
  ...IBNK_ROUTES,
  ...MBK_ROUTES,
  ...DBNK_ROUTES,
  ...WSB_ROUTES,
  ...PRVB_ROUTES,
  ...IVB_ROUTES,
  ...RTB_ROUTES,
  ...QLT_ROUTES,
  ...TST_ROUTES,
  ...DEV_ROUTES,
  ...RSH_ROUTES,
  ...STG_ROUTES,
  ...PLN2_ROUTES,
  ...FCM_ROUTES,
  ...EXP2_ROUTES,
  ...PYBL_ROUTES,
  ...REC2_ROUTES,
  ...PYM2_ROUTES,
  ...INVM_ROUTES,
  ...ORD2_ROUTES,
  ...FLF_ROUTES,
  ...TRK_ROUTES,
  ...DLV_ROUTES,
  ...SHP_ROUTES,
  ...LOG2_ROUTES,
  ...WHS_ROUTES,
  ...STK_ROUTES,
  ...INV2_ROUTES,
  ...PUR_ROUTES,
  ...PRCM_ROUTES,
  ...SPL_ROUTES,
  ...VDR_ROUTES,
  ...FID_ROUTES,
  ...SR_ROUTES,
  ...EPL_ROUTES,
  ...MNL_ROUTES,
  ...PRK_ROUTES,
  ...EAO_ROUTES,
  ...FDL_ROUTES,
  ...GUA_ROUTES,
  ...POL_ROUTES,
  ...KNR_ROUTES,
  ...EMLI_ROUTES,
  ...PUL_ROUTES,
  ...PDL_ROUTES,
  ...DOL_ROUTES,
  ...PIN_ROUTES,
  ...LIB_ROUTES,
  ...THF_ROUTES,
  ...FIR_ROUTES,
  ...MRN_ROUTES,
  ...TRV_ROUTES,
  ...HOM_ROUTES,
  ...PTY_ROUTES,
  ...HLT_ROUTES,
  ...LIF_ROUTES,
  ...ROL_ROUTES,
  ...UPG_ROUTES,
  ...PCH_ROUTES,
  ...HFX_ROUTES,
  ...DEP2_ROUTES,
  ...REL_ROUTES,
  ...PRB_ROUTES,
  ...INCD_ROUTES,
  ...NTFC_ROUTES,
  ...ESCL_ROUTES,
  ...DLG_ROUTES,
  ...SUB2_ROUTES,
  ...FIL2_ROUTES,
  ...REGN_ROUTES,
  ...PRM_ROUTES,
  ...LIC_ROUTES,
  ...TRR_ROUTES,
  ...PRR_ROUTES,
  ...PLR_ROUTES,
  ...RSA_ROUTES,
  ...RGF_ROUTES,
  ...WRT_ROUTES,
  ...FNP_ROUTES,
  ...MSP_ROUTES,
  ...RTMN_ROUTES,
  ...PBD_ROUTES,
  ...LOGG_ROUTES,
  ...PMN_ROUTES,
  ...BAC_ROUTES,
  ...DCRD_ROUTES,
  ...IMF_ROUTES,
  ...EXF_ROUTES,
  ...TCR_ROUTES,
  ...SCFN_ROUTES,
  ...IND_ROUTES,
  ...P2P_ROUTES,
  ...MCF_ROUTES,
  ...PWN_ROUTES,
  ...HPR_ROUTES,
  ...LSG_ROUTES,
  ...FCT_ROUTES,
  ...ODR_ROUTES,
  ...PLN_ROUTES,
  ...MTG_ROUTES,
  ...DEACT_ROUTES,
  ...TERM_ROUTES,
  ...SPN_ROUTES,
  ...RVRSL_ROUTES,
  ...RFND_ROUTES,
  ...RBT_ROUTES,
  ...DISC_ROUTES,
  ...TAXS_ROUTES,
  ...PENL_ROUTES,
  ...FEES_ROUTES,
  ...INTR_ROUTES,
  ...ACST_ROUTES,
  ...TXNS_ROUTES,
  ...TRNF_ROUTES,
  ...PYMT_ROUTES,
  ...DEPS_ROUTES,
  ...LN_ROUTES,
  ...PRDT_ROUTES,
  ...COLLECTION_ROUTES,
];
