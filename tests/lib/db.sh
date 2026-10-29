# DB helpers for tests. Sourced by runners.
ROOT="${ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
if [ -f "$ROOT/tests/.dbenv" ]; then
    # shellcheck disable=SC1091
    . "$ROOT/tests/.dbenv"
fi
export DB_HOST DB_PORT DB_USER DB_PASS DB_NAME

mysql_app() {
    mysql -h "${DB_HOST:-localhost}" -P "${DB_PORT:-3306}" \
        -u "${DB_USER:-cobol_user}" -p"${DB_PASS:-cobol_pass}" \
        "${DB_NAME:-cobol_db}" "$@"
}

mysql_migrate() {
    mysql -h "${DB_HOST:-localhost}" -P "${DB_PORT:-3306}" \
        -u "${DB_MIGRATE_USER:-$DB_USER}" -p"${DB_MIGRATE_PASS:-$DB_PASS}" \
        "${DB_NAME:-cobol_db}" "$@"
}

db_available() {
    mysql_app -N -B -e "SELECT 1;" >/dev/null 2>&1
}

# Fail-closed companion to db_available(). A DB-backed suite must never report
# success when it could not run: `exit 0` on a missing database is how an
# entire domain quietly leaves the gate while the run still prints "GREEN".
# Local runs can opt out with ALLOW_SKIP=1; CI never sets it.
require_db() {
    if db_available; then
        return 0
    fi
    if [ "${ALLOW_SKIP:-0}" = "1" ]; then
        echo "SKIP: DB unavailable (ALLOW_SKIP=1, local only)"
        exit 0
    fi
    echo "FAIL: DB unavailable; this suite cannot run and must not be counted as passed" >&2
    exit 1
}

db_exec() {
    mysql_app -e "$1" >/dev/null 2>&1
}

db_query() {
    mysql_app -N -B -e "$1" 2>/dev/null
}

db_seed() {
    mysql_app < "$ROOT/database/seed_test_data.sql" >/dev/null 2>&1
    # Every DB suite calls db_seed once in its main shell, so it doubles as
    # the hook that starts the persistent COBOL server (see tests/lib/cobol.sh).
    # shellcheck disable=SC1091
    . "$ROOT/tests/lib/cobol.sh"
    if [ "${COBOL_TEST_SERVE:-1}" = "1" ]; then
        start_cobol_server 2>/dev/null || true
    fi
}

# Reset D1 (loan_schedule) rows so tests are deterministic.
db_reset_loan_schedule() {
    db_exec "DELETE FROM loan_schedule_audit;"
    db_exec "DELETE FROM loan_installment;"
    db_exec "DELETE FROM loan_schedule;"
    db_exec "DELETE FROM loan_application WHERE customer_email = 'd1@test.com';"
}

# Reset D2 (deposit) rows so tests are deterministic. deposit_accrual and
# deposit_transaction cascade from deposit_account.
db_reset_deposit() {
    db_exec "DELETE FROM deposit_audit;"
    db_exec "DELETE FROM deposit_transaction;"
    db_exec "DELETE FROM deposit_accrual;"
    db_exec "DELETE FROM deposit_account;"
}

# Reset D3 (card) rows. card_transaction cascades from card_account.
db_reset_card() {
    db_exec "DELETE FROM card_audit;"
    db_exec "DELETE FROM card_transaction;"
    db_exec "DELETE FROM card_account;"
}

# Reset D4 (collections) rows plus the loan fixtures the suite creates.
db_reset_collection() {
    db_exec "DELETE FROM collection_activity;"
    db_exec "DELETE FROM collection_audit;"
    db_exec "DELETE FROM collection_case;"
    db_exec "DELETE i FROM loan_installment i JOIN loan_schedule s ON s.id = i.schedule_id JOIN loan_application l ON l.id = s.loan_id WHERE l.customer_email LIKE 'd4%';"
    db_exec "DELETE s FROM loan_schedule s JOIN loan_application l ON l.id = s.loan_id WHERE l.customer_email LIKE 'd4%';"
    db_exec "DELETE FROM loan_application WHERE customer_email LIKE 'd4%';"
}

db_reset_payment_clearing() {
    db_exec "DELETE FROM payment_clearing_audit;"
    db_exec "DELETE FROM payment_clearing;"
}

db_reset_treasury_liquidity() {
    db_exec "DELETE FROM treasury_liquidity_audit;"
    db_exec "DELETE FROM treasury_liquidity;"
}

db_reset_kyc_periodic() {
    db_exec "DELETE FROM kyc_periodic_audit;"
    db_exec "DELETE FROM kyc_periodic;"
}

db_reset_gl_allocation() {
    db_exec "DELETE FROM gl_allocation_audit;"
    db_exec "DELETE FROM gl_allocation;"
}

db_reset_backup_drill() {
    db_exec "DELETE FROM backup_drill_audit;"
    db_exec "DELETE FROM backup_drill;"
}

db_reset_report_builder() {
    db_exec "DELETE FROM report_builder_audit;"
    db_exec "DELETE FROM report_builder;"
}

db_reset_aml_screening() {
    db_exec "DELETE FROM aml_screening_audit;"
    db_exec "DELETE FROM aml_screening;"
}

db_reset_sanctions_list() {
    db_exec "DELETE FROM sanctions_list_audit;"
    db_exec "DELETE FROM sanctions_list;"
}

db_reset_fraud_case() {
    db_exec "DELETE FROM fraud_case_audit;"
    db_exec "DELETE FROM fraud_case;"
}

db_reset_cost_center() {
    db_exec "DELETE FROM cost_center_audit;"
    db_exec "DELETE FROM cost_center;"
}

db_reset_cost() {
    db_exec "DELETE FROM cost_audit;"
    db_exec "DELETE FROM cost;"
}

db_reset_fixed_asset() {
    db_exec "DELETE FROM fixed_asset_audit;"
    db_exec "DELETE FROM fixed_asset;"
}

db_reset_consolidation() {
    db_exec "DELETE FROM consolidation_audit;"
    db_exec "DELETE FROM consolidation;"
}

db_reset_fx_hedging() {
    db_exec "DELETE FROM fx_hedging_audit;"
    db_exec "DELETE FROM fx_hedging;"
}

db_reset_billpay() {
    db_exec "DELETE FROM billpay_audit;"
    db_exec "DELETE FROM billpay;"
}

db_reset_incident_postmortem() {
    db_exec "DELETE FROM incident_postmortem_audit;"
    db_exec "DELETE FROM incident_postmortem;"
}

db_reset_change_approval() {
    db_exec "DELETE FROM change_approval_audit;"
    db_exec "DELETE FROM change_approval;"
}

db_reset_capacity_forecast() {
    db_exec "DELETE FROM capacity_forecast_audit;"
    db_exec "DELETE FROM capacity_forecast;"
}

db_reset_data_lineage() {
    db_exec "DELETE FROM data_lineage_audit;"
    db_exec "DELETE FROM data_lineage;"
}

db_reset_metric_definition() {
    db_exec "DELETE FROM metric_definition_audit;"
    db_exec "DELETE FROM metric_definition;"
}

db_reset_analytics_snapshot() {
    db_exec "DELETE FROM analytics_snapshot_audit;"
    db_exec "DELETE FROM analytics_snapshot;"
}

db_reset_customer() {
    db_exec "DELETE FROM customer_audit;"
    db_exec "DELETE FROM customer;"
}

db_reset_product_catalog() {
    db_exec "DELETE FROM product_catalog_audit;"
    db_exec "DELETE FROM product_catalog;"
}

db_reset_interest_rate() {
    db_exec "DELETE FROM interest_rate_audit;"
    db_exec "DELETE FROM interest_rate;"
}

db_reset_collateral() {
    db_exec "DELETE FROM collateral_allocation;"
    db_exec "DELETE FROM collateral_pledge;"
    db_exec "DELETE FROM collateral_valuation;"
    db_exec "DELETE FROM collateral_audit;"
    db_exec "DELETE FROM collateral;"
}

db_reset_standing_order() {
    db_exec "DELETE FROM standing_order_audit;"
    db_exec "DELETE FROM standing_order;"
}

db_reset_remittance() {
    db_exec "DELETE FROM remittance_audit;"
    db_exec "DELETE FROM remittance;"
}

db_reset_case_management() {
    db_exec "DELETE FROM case_management_audit;"
    db_exec "DELETE FROM case_management;"
}

db_reset_document() {
    db_exec "DELETE FROM document_audit;"
    db_exec "DELETE FROM document;"
}

db_reset_workflow_approval() {
    db_exec "DELETE FROM workflow_approval_audit;"
    db_exec "DELETE FROM workflow_approval;"
}

db_reset_trade_finance() {
    db_exec "DELETE FROM trade_finance_audit;"
    db_exec "DELETE FROM trade_finance;"
}

db_reset_merchant() {
    db_exec "DELETE FROM merchant_audit;"
    db_exec "DELETE FROM merchant;"
}

db_reset_loan() {
    db_exec "DELETE FROM loan_audit;"
    db_exec "DELETE FROM loan;"
}


db_reset_account() {
    db_exec "DELETE FROM account_audit;"
    db_exec "DELETE FROM account;"
}

db_reset_treasury_deal() {
    db_exec "DELETE FROM treasury_deal_audit; DELETE FROM treasury_deal;"
}

db_reset_collateral_mgmt() {
    db_exec "DELETE FROM collateral_mgmt_audit; DELETE FROM collateral_mgmt;"
}

db_reset_standing_instruction() {
    db_exec "DELETE FROM standing_instruction_audit; DELETE FROM standing_instruction;"
}

db_reset_direct_debit() {
    db_exec "DELETE FROM direct_debit_audit; DELETE FROM direct_debit;"
}

db_reset_notification_template() {
    db_exec "DELETE FROM ntf_template_config_audit; DELETE FROM ntf_template_config;"
}

# Aliases for suites generated against the physical table name. Two suites
# called these names while db.sh only exported the domain name, so the reset
# never ran and every create hit a leftover row. Neither suite was in the old
# hand-maintained run_all.sh list, which is why nobody noticed.
db_reset_ntf_template_config() { db_reset_notification_template; }

db_reset_report_schedule() {
    db_exec "DELETE FROM rpt_schedule_config_audit; DELETE FROM rpt_schedule_config;"
}

db_reset_rpt_schedule_config() { db_reset_report_schedule; }

db_reset_sla_tracker() {
    db_exec "DELETE FROM sla_tracker_audit; DELETE FROM sla_tracker;"
}

db_reset_compliance_calendar() {
    db_exec "DELETE FROM compliance_calendar_audit; DELETE FROM compliance_calendar;"
}

db_reset_asset_management() {
    db_exec "DELETE FROM asset_management_audit;"
    db_exec "DELETE FROM asset_management;"
}

db_reset_portfolio_management() {
    db_exec "DELETE FROM portfolio_management_audit;"
    db_exec "DELETE FROM portfolio_management;"
}

db_reset_bond_trading() {
    db_exec "DELETE FROM bond_trading_audit;"
    db_exec "DELETE FROM bond_trading;"
}

db_reset_letter_of_credit() {
    db_exec "DELETE FROM letter_of_credit_audit;"
    db_exec "DELETE FROM letter_of_credit;"
}

db_reset_bank_guarantee() {
    db_exec "DELETE FROM bank_guarantee_audit;"
    db_exec "DELETE FROM bank_guarantee;"
}

db_reset_invoice_financing() {
    db_exec "DELETE FROM invoice_financing_audit;"
    db_exec "DELETE FROM invoice_financing;"
}

db_reset_supply_chain_finance() {
    db_exec "DELETE FROM supply_chain_finance_audit;"
    db_exec "DELETE FROM supply_chain_finance;"
}

db_reset_payroll_processing() {
    db_exec "DELETE FROM payroll_processing_audit;"
    db_exec "DELETE FROM payroll_processing;"
}

db_reset_wealth_management() {
    db_exec "DELETE FROM wealth_management_audit;"
    db_exec "DELETE FROM wealth_management;"
}

db_reset_escrow_account() {
    db_exec "DELETE FROM escrow_account_audit;"
    db_exec "DELETE FROM escrow_account;"
}

db_reset_credit_card() {
    db_exec "DELETE FROM credit_card_audit;"
    db_exec "DELETE FROM credit_card;"
}

db_reset_debit_card() {
    db_exec "DELETE FROM debit_card_audit;"
    db_exec "DELETE FROM debit_card;"
}

db_reset_merchant_settlement() {
    db_exec "DELETE FROM merchant_settlement_audit;"
    db_exec "DELETE FROM merchant_settlement;"
}

db_reset_payment_gateway() {
    db_exec "DELETE FROM payment_gateway_audit;"
    db_exec "DELETE FROM payment_gateway;"
}

db_reset_mobile_wallet() {
    db_exec "DELETE FROM mobile_wallet_audit;"
    db_exec "DELETE FROM mobile_wallet;"
}

db_reset_digital_banking() {
    db_exec "DELETE FROM digital_banking_audit;"
    db_exec "DELETE FROM digital_banking;"
}

db_reset_internet_banking() {
    db_exec "DELETE FROM internet_banking_audit;"
    db_exec "DELETE FROM internet_banking;"
}

db_reset_api_management() {
    db_exec "DELETE FROM api_management_audit;"
    db_exec "DELETE FROM api_management;"
}

db_reset_rate_management() {
    db_exec "DELETE FROM rate_management_audit;"
    db_exec "DELETE FROM rate_management;"
}

db_reset_fee_management() {
    db_exec "DELETE FROM fee_management_audit;"
    db_exec "DELETE FROM fee_management;"
}

db_reset_tax_management() {
    db_exec "DELETE FROM tax_management_audit;"
    db_exec "DELETE FROM tax_management;"
}

db_reset_audit_trail() {
    db_exec "DELETE FROM audit_trail_audit;"
    db_exec "DELETE FROM audit_trail;"
}

db_reset_adt_log() {
    db_exec "DELETE FROM adt_log_audit;"
    db_exec "DELETE FROM adt_log;"
}

db_reset_data_archive() {
    db_exec "DELETE FROM data_archive_audit;"
    db_exec "DELETE FROM data_archive;"
}

db_reset_backup_management() {
    db_exec "DELETE FROM backup_management_audit;"
    db_exec "DELETE FROM backup_management;"
}

db_reset_system_config() {
    db_exec "DELETE FROM system_config_audit;"
    db_exec "DELETE FROM system_config;"
}

db_reset_user_activity() {
    db_exec "DELETE FROM user_activity_audit;"
    db_exec "DELETE FROM user_activity;"
}

db_reset_access_control() {
    db_exec "DELETE FROM access_control_audit;"
    db_exec "DELETE FROM access_control;"
}

db_reset_role_management() {
    db_exec "DELETE FROM role_management_audit;"
    db_exec "DELETE FROM role_management;"
}

db_reset_permission_set() {
    db_exec "DELETE FROM permission_set_audit;"
    db_exec "DELETE FROM permission_set;"
}

db_reset_organization_unit() {
    db_exec "DELETE FROM organization_unit_audit;"
    db_exec "DELETE FROM organization_unit;"
}

db_reset_crypto_wallet() {
    db_exec "DELETE FROM crypto_wallet_audit;"
    db_exec "DELETE FROM crypto_wallet;"
}

db_reset_crypto_exchange() {
    db_exec "DELETE FROM crypto_exchange_audit;"
    db_exec "DELETE FROM crypto_exchange;"
}

db_reset_blockchain_tracker() {
    db_exec "DELETE FROM blockchain_tracker_audit;"
    db_exec "DELETE FROM blockchain_tracker;"
}

db_reset_digital_asset() {
    db_exec "DELETE FROM digital_asset_audit;"
    db_exec "DELETE FROM digital_asset;"
}

db_reset_tokenization() {
    db_exec "DELETE FROM tokenization_audit;"
    db_exec "DELETE FROM tokenization;"
}

db_reset_smart_contract() {
    db_exec "DELETE FROM smart_contract_audit;"
    db_exec "DELETE FROM smart_contract;"
}

db_reset_nft_management() {
    db_exec "DELETE FROM nft_management_audit;"
    db_exec "DELETE FROM nft_management;"
}

db_reset_open_banking() {
    db_exec "DELETE FROM open_banking_audit;"
    db_exec "DELETE FROM open_banking;"
}

db_reset_pisp_management() {
    db_exec "DELETE FROM pisp_management_audit;"
    db_exec "DELETE FROM pisp_management;"
}

db_reset_consent_management() {
    db_exec "DELETE FROM consent_management_audit;"
    db_exec "DELETE FROM consent_management;"
}

db_reset_customer_support() {
    db_exec "DELETE FROM customer_support_audit;"
    db_exec "DELETE FROM customer_support;"
}

db_reset_complaint_management() {
    db_exec "DELETE FROM complaint_management_audit;"
    db_exec "DELETE FROM complaint_management;"
}

db_reset_dispute_management() {
    db_exec "DELETE FROM dispute_management_audit;"
    db_exec "DELETE FROM dispute_management;"
}

db_reset_chargeback() {
    db_exec "DELETE FROM chargeback_audit;"
    db_exec "DELETE FROM chargeback;"
}

db_reset_refund_processing() {
    db_exec "DELETE FROM refund_processing_audit;"
    db_exec "DELETE FROM refund_processing;"
}

db_reset_cash_management() {
    db_exec "DELETE FROM cash_management_audit;"
    db_exec "DELETE FROM cash_management;"
}

db_reset_vault_management() {
    db_exec "DELETE FROM vault_management_audit;"
    db_exec "DELETE FROM vault_management;"
}

db_reset_atm_management() {
    db_exec "DELETE FROM atm_management_audit;"
    db_exec "DELETE FROM atm_management;"
}

db_reset_branch_management() {
    db_exec "DELETE FROM branch_management_audit;"
    db_exec "DELETE FROM branch_management;"
}

db_reset_teller_management() {
    db_exec "DELETE FROM teller_management_audit;"
    db_exec "DELETE FROM teller_management;"
}

db_reset_currency_exchange() {
    db_exec "DELETE FROM currency_exchange_audit;"
    db_exec "DELETE FROM currency_exchange;"
}

db_reset_swap_contract() {
    db_exec "DELETE FROM swap_contract_audit;"
    db_exec "DELETE FROM swap_contract;"
}

db_reset_future_contract() {
    db_exec "DELETE FROM future_contract_audit;"
    db_exec "DELETE FROM future_contract;"
}

db_reset_option_trading() {
    db_exec "DELETE FROM option_trading_audit;"
    db_exec "DELETE FROM option_trading;"
}

db_reset_commodity_trading() {
    db_exec "DELETE FROM commodity_trading_audit;"
    db_exec "DELETE FROM commodity_trading;"
}

db_reset_repo_agreement() {
    db_exec "DELETE FROM repo_agreement_audit;"
    db_exec "DELETE FROM repo_agreement;"
}

db_reset_securities_lending() {
    db_exec "DELETE FROM securities_lending_audit;"
    db_exec "DELETE FROM securities_lending;"
}

db_reset_margin_trading() {
    db_exec "DELETE FROM margin_trading_audit;"
    db_exec "DELETE FROM margin_trading;"
}

db_reset_margin() {
    db_exec "DELETE FROM margin_audit;"
    db_exec "DELETE FROM margin;"
}

db_reset_structured_product() {
    db_exec "DELETE FROM structured_product_audit;"
    db_exec "DELETE FROM structured_product;"
}

db_reset_syndicated_loan() {
    db_exec "DELETE FROM syndicated_loan_audit;"
    db_exec "DELETE FROM syndicated_loan;"
}

db_reset_insurance_policy() {
    db_exec "DELETE FROM insurance_policy_audit;"
    db_exec "DELETE FROM insurance_policy;"
}

db_reset_reinsurance_contract() {
    db_exec "DELETE FROM reinsurance_contract_audit;"
    db_exec "DELETE FROM reinsurance_contract;"
}

db_reset_actuarial_calc() {
    db_exec "DELETE FROM actuarial_calc_audit;"
    db_exec "DELETE FROM actuarial_calc;"
}

db_reset_claims_management() {
    db_exec "DELETE FROM claims_management_audit;"
    db_exec "DELETE FROM claims_management;"
}

db_reset_policy_administration() {
    db_exec "DELETE FROM policy_administration_audit;"
    db_exec "DELETE FROM policy_administration;"
}

db_reset_beneficiary_registry() {
    db_exec "DELETE FROM beneficiary_registry_audit;"
    db_exec "DELETE FROM beneficiary_registry;"
}

db_reset_guarantee_issuing() {
    db_exec "DELETE FROM guarantee_issuing_audit;"
    db_exec "DELETE FROM guarantee_issuing;"
}

db_reset_credit_bureau() {
    db_exec "DELETE FROM credit_bureau_audit;"
    db_exec "DELETE FROM credit_bureau;"
}

db_reset_debt_collection() {
    db_exec "DELETE FROM debt_collection_audit;"
    db_exec "DELETE FROM debt_collection;"
}

db_reset_debt_recovery() {
    db_exec "DELETE FROM debt_recovery_audit;"
    db_exec "DELETE FROM debt_recovery;"
}

db_reset_legal_case() {
    db_exec "DELETE FROM legal_case_audit;"
    db_exec "DELETE FROM legal_case;"
}

db_reset_collateral_repossession() {
    db_exec "DELETE FROM collateral_repossession_audit;"
    db_exec "DELETE FROM collateral_repossession;"
}

db_reset_foreclosure() {
    db_exec "DELETE FROM foreclosure_audit;"
    db_exec "DELETE FROM foreclosure;"
}

db_reset_write_off() {
    db_exec "DELETE FROM write_off_audit;"
    db_exec "DELETE FROM write_off;"
}

db_reset_provisioning() {
    db_exec "DELETE FROM provisioning_audit;"
    db_exec "DELETE FROM provisioning;"
}

db_reset_loss_reserve() {
    db_exec "DELETE FROM loss_reserve_audit;"
    db_exec "DELETE FROM loss_reserve;"
}

db_reset_risk_model() {
    db_exec "DELETE FROM risk_model_audit;"
    db_exec "DELETE FROM risk_model;"
}

db_reset_stress_test() {
    db_exec "DELETE FROM stress_test_audit;"
    db_exec "DELETE FROM stress_test;"
}




db_reset_internal_audit() {
    db_exec "DELETE FROM internal_audit_audit;"
    db_exec "DELETE FROM internal_audit;"
}

db_reset_external_audit() {
    db_exec "DELETE FROM external_audit_audit;"
    db_exec "DELETE FROM external_audit;"
}

db_reset_investigation() {
    db_exec "DELETE FROM investigation_audit;"
    db_exec "DELETE FROM investigation;"
}

db_reset_whistleblowing() {
    db_exec "DELETE FROM whistleblowing_audit;"
    db_exec "DELETE FROM whistleblowing;"
}

db_reset_incident_report() {
    db_exec "DELETE FROM incident_report_audit;"
    db_exec "DELETE FROM incident_report;"
}

db_reset_business_continuity() {
    db_exec "DELETE FROM business_continuity_audit;"
    db_exec "DELETE FROM business_continuity;"
}

db_reset_crisis_management() {
    db_exec "DELETE FROM crisis_management_audit;"
    db_exec "DELETE FROM crisis_management;"
}

db_reset_vendor_management() {
    db_exec "DELETE FROM vendor_management_audit;"
    db_exec "DELETE FROM vendor_management;"
}

db_reset_outsourcing_contract() {
    db_exec "DELETE FROM outsourcing_contract_audit;"
    db_exec "DELETE FROM outsourcing_contract;"
}

db_reset_loyalty_program() {
    db_exec "DELETE FROM loyalty_program_audit;"
    db_exec "DELETE FROM loyalty_program;"
}

db_reset_rewards_management() {
    db_exec "DELETE FROM rewards_management_audit;"
    db_exec "DELETE FROM rewards_management;"
}

db_reset_cashback() {
    db_exec "DELETE FROM cashback_audit;"
    db_exec "DELETE FROM cashback;"
}

db_reset_points_redemption() {
    db_exec "DELETE FROM points_redemption_audit;"
    db_exec "DELETE FROM points_redemption;"
}

db_reset_gift_card() {
    db_exec "DELETE FROM gift_card_audit;"
    db_exec "DELETE FROM gift_card;"
}

db_reset_prepaid_card() {
    db_exec "DELETE FROM prepaid_card_audit;"
    db_exec "DELETE FROM prepaid_card;"
}

db_reset_virtual_card() {
    db_exec "DELETE FROM virtual_card_audit;"
    db_exec "DELETE FROM virtual_card;"
}

db_reset_card_tokenization() {
    db_exec "DELETE FROM card_tokenization_audit;"
    db_exec "DELETE FROM card_tokenization;"
}

db_reset_payment_link() {
    db_exec "DELETE FROM payment_link_audit;"
    db_exec "DELETE FROM payment_link;"
}

db_reset_qr_payment() {
    db_exec "DELETE FROM qr_payment_audit;"
    db_exec "DELETE FROM qr_payment;"
}

db_reset_contactless() {
    db_exec "DELETE FROM contactless_audit;"
    db_exec "DELETE FROM contactless;"
}

db_reset_biometric_auth() {
    db_exec "DELETE FROM biometric_auth_audit;"
    db_exec "DELETE FROM biometric_auth;"
}

db_reset_device_management() {
    db_exec "DELETE FROM device_management_audit;"
    db_exec "DELETE FROM device_management;"
}

db_reset_session_management() {
    db_exec "DELETE FROM session_management_audit;"
    db_exec "DELETE FROM session_management;"
}

db_reset_token_management() {
    db_exec "DELETE FROM token_management_audit;"
    db_exec "DELETE FROM token_management;"
}

db_reset_otp_management() {
    db_exec "DELETE FROM otp_management_audit;"
    db_exec "DELETE FROM otp_management;"
}

db_reset_mfa_management() {
    db_exec "DELETE FROM mfa_management_audit;"
    db_exec "DELETE FROM mfa_management;"
}

db_reset_password_policy() {
    db_exec "DELETE FROM password_policy_audit;"
    db_exec "DELETE FROM password_policy;"
}

db_reset_login_attempt() {
    db_exec "DELETE FROM login_attempt_audit;"
    db_exec "DELETE FROM login_attempt;"
}

db_reset_account_lock() {
    db_exec "DELETE FROM account_lock_audit;"
    db_exec "DELETE FROM account_lock;"
}

db_reset_transaction_limit() {
    db_exec "DELETE FROM transaction_limit_audit;"
    db_exec "DELETE FROM transaction_limit;"
}

db_reset_daily_limit() {
    db_exec "DELETE FROM daily_limit_audit;"
    db_exec "DELETE FROM daily_limit;"
}

db_reset_velocity_check() {
    db_exec "DELETE FROM velocity_check_audit;"
    db_exec "DELETE FROM velocity_check;"
}

db_reset_risk_score() {
    db_exec "DELETE FROM risk_score_audit;"
    db_exec "DELETE FROM risk_score;"
}

db_reset_blacklist() {
    db_exec "DELETE FROM blacklist_audit;"
    db_exec "DELETE FROM blacklist;"
}

db_reset_whitelist() {
    db_exec "DELETE FROM whitelist_audit;"
    db_exec "DELETE FROM whitelist;"
}

db_reset_watchlist() {
    db_exec "DELETE FROM watchlist_audit;"
    db_exec "DELETE FROM watchlist;"
}

db_reset_pep_screening() {
    db_exec "DELETE FROM pep_screening_audit;"
    db_exec "DELETE FROM pep_screening;"
}

db_reset_adverse_media() {
    db_exec "DELETE FROM adverse_media_audit;"
    db_exec "DELETE FROM adverse_media;"
}

db_reset_name_screening() {
    db_exec "DELETE FROM name_screening_audit;"
    db_exec "DELETE FROM name_screening;"
}

db_reset_savings_account() {
    db_exec "DELETE FROM savings_account_audit;"
    db_exec "DELETE FROM savings_account;"
}

db_reset_current_account() {
    db_exec "DELETE FROM current_account_audit;"
    db_exec "DELETE FROM current_account;"
}

db_reset_term_deposit() {
    db_exec "DELETE FROM term_deposit_audit;"
    db_exec "DELETE FROM term_deposit;"
}

db_reset_certificate_deposit() {
    db_exec "DELETE FROM certificate_deposit_audit;"
    db_exec "DELETE FROM certificate_deposit;"
}

db_reset_recurring_deposit() {
    db_exec "DELETE FROM recurring_deposit_audit;"
    db_exec "DELETE FROM recurring_deposit;"
}

db_reset_fixed_deposit() {
    db_exec "DELETE FROM fixed_deposit_audit;"
    db_exec "DELETE FROM fixed_deposit;"
}

db_reset_call_deposit() {
    db_exec "DELETE FROM call_deposit_audit;"
    db_exec "DELETE FROM call_deposit;"
}

db_reset_notice_deposit() {
    db_exec "DELETE FROM notice_deposit_audit;"
    db_exec "DELETE FROM notice_deposit;"
}

db_reset_foreign_currency_deposit() {
    db_exec "DELETE FROM foreign_currency_deposit_audit;"
    db_exec "DELETE FROM foreign_currency_deposit;"
}

db_reset_multi_currency() {
    db_exec "DELETE FROM multi_currency_audit;"
    db_exec "DELETE FROM multi_currency;"
}

db_reset_currency_hedging() {
    db_exec "DELETE FROM currency_hedging_audit;"
    db_exec "DELETE FROM currency_hedging;"
}

db_reset_fx_forward() {
    db_exec "DELETE FROM fx_forward_audit;"
    db_exec "DELETE FROM fx_forward;"
}

db_reset_fx_option() {
    db_exec "DELETE FROM fx_option_audit;"
    db_exec "DELETE FROM fx_option;"
}

db_reset_fx_swap() {
    db_exec "DELETE FROM fx_swap_audit;"
    db_exec "DELETE FROM fx_swap;"
}

db_reset_interest_rate_swap() {
    db_exec "DELETE FROM interest_rate_swap_audit;"
    db_exec "DELETE FROM interest_rate_swap;"
}

db_reset_credit_default_swap() {
    db_exec "DELETE FROM credit_default_swap_audit;"
    db_exec "DELETE FROM credit_default_swap;"
}

db_reset_total_return_swap() {
    db_exec "DELETE FROM total_return_swap_audit;"
    db_exec "DELETE FROM total_return_swap;"
}

db_reset_equity_swap() {
    db_exec "DELETE FROM equity_swap_audit;"
    db_exec "DELETE FROM equity_swap;"
}

db_reset_commodity_swap() {
    db_exec "DELETE FROM commodity_swap_audit;"
    db_exec "DELETE FROM commodity_swap;"
}

db_reset_variance_swap() {
    db_exec "DELETE FROM variance_swap_audit;"
    db_exec "DELETE FROM variance_swap;"
}

db_reset_volatility() {
    db_exec "DELETE FROM volatility_audit;"
    db_exec "DELETE FROM volatility;"
}

db_reset_greeks() {
    db_exec "DELETE FROM greeks_audit;"
    db_exec "DELETE FROM greeks;"
}

db_reset_pricing() {
    db_exec "DELETE FROM pricing_audit;"
    db_exec "DELETE FROM pricing;"
}

db_reset_valuation() {
    db_exec "DELETE FROM valuation_audit;"
    db_exec "DELETE FROM valuation;"
}

db_reset_mark_to_market() {
    db_exec "DELETE FROM mark_to_market_audit;"
    db_exec "DELETE FROM mark_to_market;"
}

db_reset_pnl() {
    db_exec "DELETE FROM pnl_audit;"
    db_exec "DELETE FROM pnl;"
}

db_reset_revenue() {
    db_exec "DELETE FROM revenue_audit;"
    db_exec "DELETE FROM revenue;"
}

db_reset_profit() {
    db_exec "DELETE FROM profit_audit;"
    db_exec "DELETE FROM profit;"
}

db_reset_employee() {
    db_exec "DELETE FROM employee_audit;"
    db_exec "DELETE FROM employee;"
}

db_reset_department() {
    db_exec "DELETE FROM department_audit;"
    db_exec "DELETE FROM department;"
}

db_reset_position() {
    db_exec "DELETE FROM position_audit;"
    db_exec "DELETE FROM position;"
}

db_reset_attendance() {
    db_exec "DELETE FROM attendance_audit;"
    db_exec "DELETE FROM attendance;"
}

db_reset_leave_management() {
    db_exec "DELETE FROM leave_management_audit;"
    db_exec "DELETE FROM leave_management;"
}

db_reset_performance() {
    db_exec "DELETE FROM performance_audit;"
    db_exec "DELETE FROM performance;"
}

db_reset_training() {
    db_exec "DELETE FROM training_audit;"
    db_exec "DELETE FROM training;"
}

db_reset_recruitment() {
    db_exec "DELETE FROM recruitment_audit;"
    db_exec "DELETE FROM recruitment;"
}

db_reset_onboarding() {
    db_exec "DELETE FROM onboarding_audit;"
    db_exec "DELETE FROM onboarding;"
}

db_reset_offboarding() {
    db_exec "DELETE FROM offboarding_audit;"
    db_exec "DELETE FROM offboarding;"
}

db_reset_compensation() {
    db_exec "DELETE FROM compensation_audit;"
    db_exec "DELETE FROM compensation;"
}

db_reset_benefits() {
    db_exec "DELETE FROM benefits_audit;"
    db_exec "DELETE FROM benefits;"
}

db_reset_pension() {
    db_exec "DELETE FROM pension_audit;"
    db_exec "DELETE FROM pension;"
}

db_reset_tax_withholding() {
    db_exec "DELETE FROM tax_withholding_audit;"
    db_exec "DELETE FROM tax_withholding;"
}

db_reset_billing() {
    db_exec "DELETE FROM billing_audit;"
    db_exec "DELETE FROM billing;"
}

db_reset_subscription() {
    db_exec "DELETE FROM subscription_audit;"
    db_exec "DELETE FROM subscription;"
}

db_reset_contract() {
    db_exec "DELETE FROM contract_audit;"
    db_exec "DELETE FROM contract;"
}

db_reset_agreement() {
    db_exec "DELETE FROM agreement_audit;"
    db_exec "DELETE FROM agreement;"
}

db_reset_sla_management() {
    db_exec "DELETE FROM sla_management_audit;"
    db_exec "DELETE FROM sla_management;"
}

db_reset_kpi() {
    db_exec "DELETE FROM kpi_audit;"
    db_exec "DELETE FROM kpi;"
}

db_reset_dashboard_widget() {
    db_exec "DELETE FROM dashboard_widget_audit;"
    db_exec "DELETE FROM dashboard_widget;"
}

db_reset_reporting() {
    db_exec "DELETE FROM reporting_audit;"
    db_exec "DELETE FROM reporting;"
}

db_reset_data_warehouse() {
    db_exec "DELETE FROM data_warehouse_audit;"
    db_exec "DELETE FROM data_warehouse;"
}

db_reset_etl() {
    db_exec "DELETE FROM etl_audit;"
    db_exec "DELETE FROM etl;"
}

db_reset_dq_check() {
    db_exec "DELETE FROM dq_check_audit;"
    db_exec "DELETE FROM dq_check;"
}

db_reset_master_data() {
    db_exec "DELETE FROM master_data_audit;"
    db_exec "DELETE FROM master_data;"
}

db_reset_audit_log() {
    db_exec "DELETE FROM audit_log_audit;"
    db_exec "DELETE FROM audit_log;"
}

db_reset_invoice() {
    db_exec "DELETE FROM invoice_audit;"
    db_exec "DELETE FROM invoice;"
}

db_reset_metric() {
    db_exec "DELETE FROM metric_audit;"
    db_exec "DELETE FROM metric;"
}

db_reset_analytics() {
    db_exec "DELETE FROM analytics_audit;"
    db_exec "DELETE FROM analytics;"
}

db_reset_email() {
    db_exec "DELETE FROM email_audit;"
    db_exec "DELETE FROM email;"
}

db_reset_sms() {
    db_exec "DELETE FROM sms_audit;"
    db_exec "DELETE FROM sms;"
}

db_reset_push_notification() {
    db_exec "DELETE FROM push_notification_audit;"
    db_exec "DELETE FROM push_notification;"
}

db_reset_in_app_message() {
    db_exec "DELETE FROM in_app_message_audit;"
    db_exec "DELETE FROM in_app_message;"
}

db_reset_webhook() {
    db_exec "DELETE FROM webhook_audit;"
    db_exec "DELETE FROM webhook;"
}

db_reset_api_gateway() {
    db_exec "DELETE FROM api_gateway_audit;"
    db_exec "DELETE FROM api_gateway;"
}

db_reset_message_queue() {
    db_exec "DELETE FROM message_queue_audit;"
    db_exec "DELETE FROM message_queue;"
}

db_reset_event_bus() {
    db_exec "DELETE FROM event_bus_audit;"
    db_exec "DELETE FROM event_bus;"
}

db_reset_service_mesh() {
    db_exec "DELETE FROM service_mesh_audit;"
    db_exec "DELETE FROM service_mesh;"
}

db_reset_load_balancer() {
    db_exec "DELETE FROM load_balancer_audit;"
    db_exec "DELETE FROM load_balancer;"
}

db_reset_cache() {
    db_exec "DELETE FROM cache_audit;"
    db_exec "DELETE FROM cache;"
}

db_reset_session_store() {
    db_exec "DELETE FROM session_store_audit;"
    db_exec "DELETE FROM session_store;"
}

db_reset_config() {
    db_exec "DELETE FROM config_audit;"
    db_exec "DELETE FROM config;"
}

db_reset_feature_flag() {
    db_exec "DELETE FROM feature_flag_audit;"
    db_exec "DELETE FROM feature_flag;"
}

db_reset_ab_testing() {
    db_exec "DELETE FROM ab_testing_audit;"
    db_exec "DELETE FROM ab_testing;"
}

db_reset_experiment() {
    db_exec "DELETE FROM experiment_audit;"
    db_exec "DELETE FROM experiment;"
}

db_reset_personalization() {
    db_exec "DELETE FROM personalization_audit;"
    db_exec "DELETE FROM personalization;"
}

db_reset_recommendation() {
    db_exec "DELETE FROM recommendation_audit;"
    db_exec "DELETE FROM recommendation;"
}

db_reset_search() {
    db_exec "DELETE FROM search_audit;"
    db_exec "DELETE FROM search;"
}

db_reset_indexing() {
    db_exec "DELETE FROM indexing_audit;"
    db_exec "DELETE FROM indexing;"
}

db_reset_logging() {
    db_exec "DELETE FROM logging_audit;"
    db_exec "DELETE FROM logging;"
}

db_reset_monitoring() {
    db_exec "DELETE FROM monitoring_audit;"
    db_exec "DELETE FROM monitoring;"
}

db_reset_alerting() {
    db_exec "DELETE FROM alerting_audit;"
    db_exec "DELETE FROM alerting;"
}

db_reset_tracing() {
    db_exec "DELETE FROM tracing_audit;"
    db_exec "DELETE FROM tracing;"
}

db_reset_metrics() {
    db_exec "DELETE FROM metrics_audit;"
    db_exec "DELETE FROM metrics;"
}

db_reset_health_check() {
    db_exec "DELETE FROM health_check_audit;"
    db_exec "DELETE FROM health_check;"
}

db_reset_circuit_breaker() {
    db_exec "DELETE FROM circuit_breaker_audit;"
    db_exec "DELETE FROM circuit_breaker;"
}

db_reset_rate_limiter() {
    db_exec "DELETE FROM rate_limiter_audit;"
    db_exec "DELETE FROM rate_limiter;"
}

db_reset_retry() {
    db_exec "DELETE FROM retry_audit;"
    db_exec "DELETE FROM retry;"
}

db_reset_timeout() {
    db_exec "DELETE FROM timeout_audit;"
    db_exec "DELETE FROM timeout;"
}

db_reset_bond() {
    db_exec "DELETE FROM bond_audit;"
    db_exec "DELETE FROM bond;"
}

db_reset_equity() {
    db_exec "DELETE FROM equity_audit;"
    db_exec "DELETE FROM equity;"
}

db_reset_derivative() {
    db_exec "DELETE FROM derivative_audit;"
    db_exec "DELETE FROM derivative;"
}

db_reset_warrant() {
    db_exec "DELETE FROM warrant_audit;"
    db_exec "DELETE FROM warrant;"
}

db_reset_convertible() {
    db_exec "DELETE FROM convertible_audit;"
    db_exec "DELETE FROM convertible;"
}

db_reset_structured() {
    db_exec "DELETE FROM structured_audit;"
    db_exec "DELETE FROM structured;"
}

db_reset_asset_backed() {
    db_exec "DELETE FROM asset_backed_audit;"
    db_exec "DELETE FROM asset_backed;"
}

db_reset_mortgage_backed() {
    db_exec "DELETE FROM mortgage_backed_audit;"
    db_exec "DELETE FROM mortgage_backed;"
}

db_reset_collateralized() {
    db_exec "DELETE FROM collateralized_audit;"
    db_exec "DELETE FROM collateralized;"
}

db_reset_tranche() {
    db_exec "DELETE FROM tranche_audit;"
    db_exec "DELETE FROM tranche;"
}

db_reset_securitization() {
    db_exec "DELETE FROM securitization_audit;"
    db_exec "DELETE FROM securitization;"
}

db_reset_special_purpose() {
    db_exec "DELETE FROM special_purpose_audit;"
    db_exec "DELETE FROM special_purpose;"
}

db_reset_vehicle() {
    db_exec "DELETE FROM vehicle_audit;"
    db_exec "DELETE FROM vehicle;"
}

db_reset_trust() {
    db_exec "DELETE FROM trust_audit;"
    db_exec "DELETE FROM trust;"
}

db_reset_fund() {
    db_exec "DELETE FROM fund_audit;"
    db_exec "DELETE FROM fund;"
}

db_reset_etf() {
    db_exec "DELETE FROM etf_audit;"
    db_exec "DELETE FROM etf;"
}

db_reset_mutual_fund() {
    db_exec "DELETE FROM mutual_fund_audit;"
    db_exec "DELETE FROM mutual_fund;"
}

db_reset_hedge_fund() {
    db_exec "DELETE FROM hedge_fund_audit;"
    db_exec "DELETE FROM hedge_fund;"
}

db_reset_private_equity() {
    db_exec "DELETE FROM private_equity_audit;"
    db_exec "DELETE FROM private_equity;"
}

db_reset_venture_capital() {
    db_exec "DELETE FROM venture_capital_audit;"
    db_exec "DELETE FROM venture_capital;"
}

db_reset_real_estate() {
    db_exec "DELETE FROM real_estate_audit;"
    db_exec "DELETE FROM real_estate;"
}

db_reset_infrastructure() {
    db_exec "DELETE FROM infrastructure_audit;"
    db_exec "DELETE FROM infrastructure;"
}

db_reset_private_debt() {
    db_exec "DELETE FROM private_debt_audit;"
    db_exec "DELETE FROM private_debt;"
}

db_reset_direct_lending() {
    db_exec "DELETE FROM direct_lending_audit;"
    db_exec "DELETE FROM direct_lending;"
}

db_reset_mezzanine() {
    db_exec "DELETE FROM mezzanine_audit;"
    db_exec "DELETE FROM mezzanine;"
}

db_reset_distressed() {
    db_exec "DELETE FROM distressed_audit;"
    db_exec "DELETE FROM distressed;"
}

db_reset_warrant_issuing() {
    db_exec "DELETE FROM warrant_issuing_audit;"
    db_exec "DELETE FROM warrant_issuing;"
}

db_reset_convertible_bond() {
    db_exec "DELETE FROM convertible_bond_audit;"
    db_exec "DELETE FROM convertible_bond;"
}

db_reset_structured_note() {
    db_exec "DELETE FROM structured_note_audit;"
    db_exec "DELETE FROM structured_note;"
}

db_reset_asset_backed_security() {
    db_exec "DELETE FROM asset_backed_security_audit;"
    db_exec "DELETE FROM asset_backed_security;"
}

db_reset_aml_check() {
    db_exec "DELETE FROM aml_check_audit;"
    db_exec "DELETE FROM aml_check;"
}

db_reset_kyc_check() {
    db_exec "DELETE FROM kyc_check_audit;"
    db_exec "DELETE FROM kyc_check;"
}

db_reset_sanctions_check() {
    db_exec "DELETE FROM sanctions_check_audit;"
    db_exec "DELETE FROM sanctions_check;"
}

db_reset_fraud_check() {
    db_exec "DELETE FROM fraud_check_audit;"
    db_exec "DELETE FROM fraud_check;"
}

db_reset_transaction() {
    db_exec "DELETE FROM transaction_audit;"
    db_exec "DELETE FROM transaction;"
}

db_reset_payment_processing() {
    db_exec "DELETE FROM payment_processing_audit;"
    db_exec "DELETE FROM payment_processing;"
}

db_reset_transfer() {
    db_exec "DELETE FROM transfer_audit;"
    db_exec "DELETE FROM transfer;"
}


db_reset_withdrawal() {
    db_exec "DELETE FROM withdrawal_audit;"
    db_exec "DELETE FROM withdrawal;"
}

db_reset_balance() {
    db_exec "DELETE FROM balance_audit;"
    db_exec "DELETE FROM balance;"
}

db_reset_account_statement() {
    db_exec "DELETE FROM account_statement_audit;"
    db_exec "DELETE FROM account_statement;"
}

db_reset_reconciliation() {
    db_exec "DELETE FROM reconciliation_audit;"
    db_exec "DELETE FROM reconciliation;"
}

db_reset_clearing() {
    db_exec "DELETE FROM clearing_audit;"
    db_exec "DELETE FROM clearing;"
}


db_reset_netting() {
    db_exec "DELETE FROM netting_audit;"
    db_exec "DELETE FROM netting;"
}

db_reset_nostro() {
    db_exec "DELETE FROM nostro_audit;"
    db_exec "DELETE FROM nostro;"
}

db_reset_vostro() {
    db_exec "DELETE FROM vostro_audit;"
    db_exec "DELETE FROM vostro;"
}

db_reset_suspense() {
    db_exec "DELETE FROM suspense_audit;"
    db_exec "DELETE FROM suspense;"
}

db_reset_gl_master() {
    db_exec "DELETE FROM gl_master_audit;"
    db_exec "DELETE FROM gl_master;"
}


db_reset_journal() {
    db_exec "DELETE FROM journal_audit;"
    db_exec "DELETE FROM journal;"
}

db_reset_trial_balance() {
    db_exec "DELETE FROM trial_balance_audit;"
    db_exec "DELETE FROM trial_balance;"
}

db_reset_balance_sheet() {
    db_exec "DELETE FROM balance_sheet_audit;"
    db_exec "DELETE FROM balance_sheet;"
}

db_reset_income_statement() {
    db_exec "DELETE FROM income_statement_audit;"
    db_exec "DELETE FROM income_statement;"
}

db_reset_cash_flow() {
    db_exec "DELETE FROM cash_flow_audit;"
    db_exec "DELETE FROM cash_flow;"
}

db_reset_equity_account() {
    db_exec "DELETE FROM equity_account_audit;"
    db_exec "DELETE FROM equity_account;"
}


db_reset_liability() {
    db_exec "DELETE FROM liability_audit;"
    db_exec "DELETE FROM liability;"
}

db_reset_capital() {
    db_exec "DELETE FROM capital_audit;"
    db_exec "DELETE FROM capital;"
}

db_reset_reserve() {
    db_exec "DELETE FROM reserve_audit;"
    db_exec "DELETE FROM reserve;"
}

db_reset_budgeting() {
    db_exec "DELETE FROM budgeting_audit;"
    db_exec "DELETE FROM budgeting;"
}

db_reset_forecast() {
    db_exec "DELETE FROM forecast_audit;"
    db_exec "DELETE FROM forecast;"
}

db_reset_variance() {
    db_exec "DELETE FROM variance_audit;"
    db_exec "DELETE FROM variance;"
}

db_reset_scenario() {
    db_exec "DELETE FROM scenario_audit;"
    db_exec "DELETE FROM scenario;"
}

db_reset_simulation() {
    db_exec "DELETE FROM simulation_audit;"
    db_exec "DELETE FROM simulation;"
}

db_reset_optimization() {
    db_exec "DELETE FROM optimization_audit;"
    db_exec "DELETE FROM optimization;"
}

db_reset_allocation() {
    db_exec "DELETE FROM allocation_audit;"
    db_exec "DELETE FROM allocation;"
}

db_reset_distribution() {
    db_exec "DELETE FROM distribution_audit;"
    db_exec "DELETE FROM distribution;"
}

db_reset_consolidation_mgmt() {
    db_exec "DELETE FROM consolidation_mgmt_audit;"
    db_exec "DELETE FROM consolidation_mgmt;"
}

db_reset_elimination() {
    db_exec "DELETE FROM elimination_audit;"
    db_exec "DELETE FROM elimination;"
}

db_reset_intercompany() {
    db_exec "DELETE FROM intercompany_audit;"
    db_exec "DELETE FROM intercompany;"
}

db_reset_transfer_pricing() {
    db_exec "DELETE FROM transfer_pricing_audit;"
    db_exec "DELETE FROM transfer_pricing;"
}

db_reset_cost_center_mgmt() {
    db_exec "DELETE FROM cost_center_mgmt_audit;"
    db_exec "DELETE FROM cost_center_mgmt;"
}

db_reset_profit_center() {
    db_exec "DELETE FROM profit_center_audit;"
    db_exec "DELETE FROM profit_center;"
}

db_reset_investment() {
    db_exec "DELETE FROM investment_audit;"
    db_exec "DELETE FROM investment;"
}

db_reset_portfolio() {
    db_exec "DELETE FROM portfolio_audit;"
    db_exec "DELETE FROM portfolio;"
}

db_reset_asset_allocation() {
    db_exec "DELETE FROM asset_allocation_audit;"
    db_exec "DELETE FROM asset_allocation;"
}

db_reset_rebalancing() {
    db_exec "DELETE FROM rebalancing_audit;"
    db_exec "DELETE FROM rebalancing;"
}

db_reset_benchmark() {
    db_exec "DELETE FROM benchmark_audit;"
    db_exec "DELETE FROM benchmark;"
}

db_reset_index_mgmt() {
    db_exec "DELETE FROM index_mgmt_audit;"
    db_exec "DELETE FROM index_mgmt;"
}

db_reset_market_data() {
    db_exec "DELETE FROM market_data_audit;"
    db_exec "DELETE FROM market_data;"
}

db_reset_price_feed() {
    db_exec "DELETE FROM price_feed_audit;"
    db_exec "DELETE FROM price_feed;"
}

db_reset_quote() {
    db_exec "DELETE FROM quote_audit;"
    db_exec "DELETE FROM quote;"
}

db_reset_order_mgmt() {
    db_exec "DELETE FROM order_mgmt_audit;"
    db_exec "DELETE FROM order_mgmt;"
}

db_reset_execution() {
    db_exec "DELETE FROM execution_audit;"
    db_exec "DELETE FROM execution;"
}

db_reset_fill() {
    db_exec "DELETE FROM fill_audit;"
    db_exec "DELETE FROM fill;"
}

db_reset_position_mgmt() {
    db_exec "DELETE FROM position_mgmt_audit;"
    db_exec "DELETE FROM position_mgmt;"
}

db_reset_exposure() {
    db_exec "DELETE FROM exposure_audit;"
    db_exec "DELETE FROM exposure;"
}

db_reset_hedge() {
    db_exec "DELETE FROM hedge_audit;"
    db_exec "DELETE FROM hedge;"
}


db_reset_customer_profile() {
    db_exec "DELETE FROM customer_profile_audit;"
    db_exec "DELETE FROM customer_profile;"
}

db_reset_account_detail() {
    db_exec "DELETE FROM account_detail_audit;"
    db_exec "DELETE FROM account_detail;"
}

db_reset_product_item() {
    db_exec "DELETE FROM product_item_audit;"
    db_exec "DELETE FROM product_item;"
}

db_reset_loan_account() {
    db_exec "DELETE FROM loan_account_audit;"
    db_exec "DELETE FROM loan_account;"
}

db_reset_deposit_book() {
    db_exec "DELETE FROM deposit_book_audit;"
    db_exec "DELETE FROM deposit_book;"
}

db_reset_payment_item() {
    db_exec "DELETE FROM payment_item_audit;"
    db_exec "DELETE FROM payment_item;"
}

db_reset_transfer_item() {
    db_exec "DELETE FROM transfer_item_audit;"
    db_exec "DELETE FROM transfer_item;"
}

db_reset_card_item() {
    db_exec "DELETE FROM card_item_audit;"
    db_exec "DELETE FROM card_item;"
}

db_reset_transaction_item() {
    db_exec "DELETE FROM transaction_item_audit;"
    db_exec "DELETE FROM transaction_item;"
}

db_reset_balance_item() {
    db_exec "DELETE FROM balance_item_audit;"
    db_exec "DELETE FROM balance_item;"
}

db_reset_statement_item() {
    db_exec "DELETE FROM statement_item_audit;"
    db_exec "DELETE FROM statement_item;"
}

db_reset_interest_item() {
    db_exec "DELETE FROM interest_item_audit;"
    db_exec "DELETE FROM interest_item;"
}

db_reset_fee_item() {
    db_exec "DELETE FROM fee_item_audit;"
    db_exec "DELETE FROM fee_item;"
}

db_reset_charge_item() {
    db_exec "DELETE FROM charge_item_audit;"
    db_exec "DELETE FROM charge_item;"
}

db_reset_penalty_item() {
    db_exec "DELETE FROM penalty_item_audit;"
    db_exec "DELETE FROM penalty_item;"
}

db_reset_tax_item() {
    db_exec "DELETE FROM tax_item_audit;"
    db_exec "DELETE FROM tax_item;"
}

db_reset_commission_item() {
    db_exec "DELETE FROM commission_item_audit;"
    db_exec "DELETE FROM commission_item;"
}

db_reset_discount_item() {
    db_exec "DELETE FROM discount_item_audit;"
    db_exec "DELETE FROM discount_item;"
}

db_reset_rebate_item() {
    db_exec "DELETE FROM rebate_item_audit;"
    db_exec "DELETE FROM rebate_item;"
}

db_reset_refund_item() {
    db_exec "DELETE FROM refund_item_audit;"
    db_exec "DELETE FROM refund_item;"
}

db_reset_reversal_item() {
    db_exec "DELETE FROM reversal_item_audit;"
    db_exec "DELETE FROM reversal_item;"
}

db_reset_adjustment_item() {
    db_exec "DELETE FROM adjustment_item_audit;"
    db_exec "DELETE FROM adjustment_item;"
}

db_reset_correction_item() {
    db_exec "DELETE FROM correction_item_audit;"
    db_exec "DELETE FROM correction_item;"
}

db_reset_cancellation_item() {
    db_exec "DELETE FROM cancellation_item_audit;"
    db_exec "DELETE FROM cancellation_item;"
}

db_reset_suspension_item() {
    db_exec "DELETE FROM suspension_item_audit;"
    db_exec "DELETE FROM suspension_item;"
}

db_reset_termination_item() {
    db_exec "DELETE FROM termination_item_audit;"
    db_exec "DELETE FROM termination_item;"
}

db_reset_activation_item() {
    db_exec "DELETE FROM activation_item_audit;"
    db_exec "DELETE FROM activation_item;"
}

db_reset_deactivation_item() {
    db_exec "DELETE FROM deactivation_item_audit;"
    db_exec "DELETE FROM deactivation_item;"
}

db_reset_closure_item() {
    db_exec "DELETE FROM closure_item_audit;"
    db_exec "DELETE FROM closure_item;"
}

db_reset_reopening_item() {
    db_exec "DELETE FROM reopening_item_audit;"
    db_exec "DELETE FROM reopening_item;"
}

db_reset_mortgage() {
    db_exec "DELETE FROM mortgage_audit;"
    db_exec "DELETE FROM mortgage;"
}

db_reset_auto_loan() {
    db_exec "DELETE FROM auto_loan_audit;"
    db_exec "DELETE FROM auto_loan;"
}

db_reset_personal_loan() {
    db_exec "DELETE FROM personal_loan_audit;"
    db_exec "DELETE FROM personal_loan;"
}

db_reset_business_loan() {
    db_exec "DELETE FROM business_loan_audit;"
    db_exec "DELETE FROM business_loan;"
}

db_reset_credit_line() {
    db_exec "DELETE FROM credit_line_audit;"
    db_exec "DELETE FROM credit_line;"
}

db_reset_overdraft() {
    db_exec "DELETE FROM overdraft_audit;"
    db_exec "DELETE FROM overdraft;"
}

db_reset_factoring() {
    db_exec "DELETE FROM factoring_audit;"
    db_exec "DELETE FROM factoring;"
}

db_reset_leasing() {
    db_exec "DELETE FROM leasing_audit;"
    db_exec "DELETE FROM leasing;"
}

db_reset_hire_purchase() {
    db_exec "DELETE FROM hire_purchase_audit;"
    db_exec "DELETE FROM hire_purchase;"
}

db_reset_pawn() {
    db_exec "DELETE FROM pawn_audit;"
    db_exec "DELETE FROM pawn;"
}

db_reset_microfinance() {
    db_exec "DELETE FROM microfinance_audit;"
    db_exec "DELETE FROM microfinance;"
}

db_reset_peer_to_peer() {
    db_exec "DELETE FROM peer_to_peer_audit;"
    db_exec "DELETE FROM peer_to_peer;"
}

db_reset_crowdfunding() {
    db_exec "DELETE FROM crowdfunding_audit;"
    db_exec "DELETE FROM crowdfunding;"
}

db_reset_invoice_discounting() {
    db_exec "DELETE FROM invoice_discounting_audit;"
    db_exec "DELETE FROM invoice_discounting;"
}

db_reset_supply_chain() {
    db_exec "DELETE FROM supply_chain_audit;"
    db_exec "DELETE FROM supply_chain;"
}

db_reset_trade_credit() {
    db_exec "DELETE FROM trade_credit_audit;"
    db_exec "DELETE FROM trade_credit;"
}

db_reset_export_finance() {
    db_exec "DELETE FROM export_finance_audit;"
    db_exec "DELETE FROM export_finance;"
}

db_reset_import_finance() {
    db_exec "DELETE FROM import_finance_audit;"
    db_exec "DELETE FROM import_finance;"
}

db_reset_documentary_credit() {
    db_exec "DELETE FROM documentary_credit_audit;"
    db_exec "DELETE FROM documentary_credit;"
}

db_reset_bankers_acceptance() {
    db_exec "DELETE FROM bankers_acceptance_audit;"
    db_exec "DELETE FROM bankers_acceptance;"
}

db_reset_promissory_note() {
    db_exec "DELETE FROM promissory_note_audit;"
    db_exec "DELETE FROM promissory_note;"
}

db_reset_bill_of_exchange() {
    db_exec "DELETE FROM bill_of_exchange_audit;"
    db_exec "DELETE FROM bill_of_exchange;"
}

db_reset_letter_of_guarantee() {
    db_exec "DELETE FROM letter_of_guarantee_audit;"
    db_exec "DELETE FROM letter_of_guarantee;"
}

db_reset_performance_bond() {
    db_exec "DELETE FROM performance_bond_audit;"
    db_exec "DELETE FROM performance_bond;"
}

db_reset_advance_payment() {
    db_exec "DELETE FROM advance_payment_audit;"
    db_exec "DELETE FROM advance_payment;"
}

db_reset_retention_money() {
    db_exec "DELETE FROM retention_money_audit;"
    db_exec "DELETE FROM retention_money;"
}

db_reset_milestone_payment() {
    db_exec "DELETE FROM milestone_payment_audit;"
    db_exec "DELETE FROM milestone_payment;"
}

db_reset_final_payment() {
    db_exec "DELETE FROM final_payment_audit;"
    db_exec "DELETE FROM final_payment;"
}

db_reset_warranty() {
    db_exec "DELETE FROM warranty_audit;"
    db_exec "DELETE FROM warranty;"
}

db_reset_credit_insurance() {
    db_exec "DELETE FROM credit_insurance_audit;"
    db_exec "DELETE FROM credit_insurance;"
}

db_reset_compliance_check() {
    db_exec "DELETE FROM compliance_check_audit;"
    db_exec "DELETE FROM compliance_check;"
}

db_reset_regulatory_filing() {
    db_exec "DELETE FROM regulatory_filing_audit;"
    db_exec "DELETE FROM regulatory_filing;"
}

db_reset_audit_finding() {
    db_exec "DELETE FROM audit_finding_audit;"
    db_exec "DELETE FROM audit_finding;"
}

db_reset_risk_assessment() {
    db_exec "DELETE FROM risk_assessment_audit;"
    db_exec "DELETE FROM risk_assessment;"
}

db_reset_control_test() {
    db_exec "DELETE FROM control_test_audit;"
    db_exec "DELETE FROM control_test;"
}

db_reset_policy_review() {
    db_exec "DELETE FROM policy_review_audit;"
    db_exec "DELETE FROM policy_review;"
}

db_reset_procedure_review() {
    db_exec "DELETE FROM procedure_review_audit;"
    db_exec "DELETE FROM procedure_review;"
}

db_reset_training_record() {
    db_exec "DELETE FROM training_record_audit;"
    db_exec "DELETE FROM training_record;"
}

db_reset_certification() {
    db_exec "DELETE FROM certification_audit;"
    db_exec "DELETE FROM certification;"
}

db_reset_license() {
    db_exec "DELETE FROM license_audit;"
    db_exec "DELETE FROM license;"
}

db_reset_permit() {
    db_exec "DELETE FROM permit_audit;"
    db_exec "DELETE FROM permit;"
}

db_reset_registration() {
    db_exec "DELETE FROM registration_audit;"
    db_exec "DELETE FROM registration;"
}

db_reset_filing() {
    db_exec "DELETE FROM filing_audit;"
    db_exec "DELETE FROM filing;"
}

db_reset_submission() {
    db_exec "DELETE FROM submission_audit;"
    db_exec "DELETE FROM submission;"
}

db_reset_approval() {
    db_exec "DELETE FROM approval_audit;"
    db_exec "DELETE FROM approval;"
}

db_reset_authorization() {
    db_exec "DELETE FROM authorization_audit;"
    db_exec "DELETE FROM authorization;"
}

db_reset_delegation() {
    db_exec "DELETE FROM delegation_audit;"
    db_exec "DELETE FROM delegation;"
}

db_reset_escalation() {
    db_exec "DELETE FROM escalation_audit;"
    db_exec "DELETE FROM escalation;"
}

db_reset_notification_mgmt() {
    db_exec "DELETE FROM notification_mgmt_audit;"
    db_exec "DELETE FROM notification_mgmt;"
}

db_reset_alert_mgmt() {
    db_exec "DELETE FROM alert_mgmt_audit;"
    db_exec "DELETE FROM alert_mgmt;"
}

db_reset_incident_mgmt() {
    db_exec "DELETE FROM incident_mgmt_audit;"
    db_exec "DELETE FROM incident_mgmt;"
}

db_reset_problem() {
    db_exec "DELETE FROM problem_audit;"
    db_exec "DELETE FROM problem;"
}

db_reset_change_mgmt() {
    db_exec "DELETE FROM change_mgmt_audit;"
    db_exec "DELETE FROM change_mgmt;"
}

db_reset_release_mgmt() {
    db_exec "DELETE FROM release_mgmt_audit;"
    db_exec "DELETE FROM release_mgmt;"
}

db_reset_deployment() {
    db_exec "DELETE FROM deployment_audit;"
    db_exec "DELETE FROM deployment;"
}

db_reset_rollback() {
    db_exec "DELETE FROM rollback_audit;"
    db_exec "DELETE FROM rollback;"
}

db_reset_hotfix() {
    db_exec "DELETE FROM hotfix_audit;"
    db_exec "DELETE FROM hotfix;"
}

db_reset_patch() {
    db_exec "DELETE FROM patch_audit;"
    db_exec "DELETE FROM patch;"
}

db_reset_upgrade() {
    db_exec "DELETE FROM upgrade_audit;"
    db_exec "DELETE FROM upgrade;"
}

db_reset_migration() {
    db_exec "DELETE FROM migration_audit;"
    db_exec "DELETE FROM migration;"
}

db_reset_life_insurance() {
    db_exec "DELETE FROM life_insurance_audit;"
    db_exec "DELETE FROM life_insurance;"
}

db_reset_health_insurance() {
    db_exec "DELETE FROM health_insurance_audit;"
    db_exec "DELETE FROM health_insurance;"
}

db_reset_property_insurance() {
    db_exec "DELETE FROM property_insurance_audit;"
    db_exec "DELETE FROM property_insurance;"
}

db_reset_casualty_insurance() {
    db_exec "DELETE FROM casualty_insurance_audit;"
    db_exec "DELETE FROM casualty_insurance;"
}

db_reset_auto_insurance() {
    db_exec "DELETE FROM auto_insurance_audit;"
    db_exec "DELETE FROM auto_insurance;"
}

db_reset_home_insurance() {
    db_exec "DELETE FROM home_insurance_audit;"
    db_exec "DELETE FROM home_insurance;"
}

db_reset_travel_insurance() {
    db_exec "DELETE FROM travel_insurance_audit;"
    db_exec "DELETE FROM travel_insurance;"
}

db_reset_marine_insurance() {
    db_exec "DELETE FROM marine_insurance_audit;"
    db_exec "DELETE FROM marine_insurance;"
}

db_reset_fire_insurance() {
    db_exec "DELETE FROM fire_insurance_audit;"
    db_exec "DELETE FROM fire_insurance;"
}

db_reset_theft_insurance() {
    db_exec "DELETE FROM theft_insurance_audit;"
    db_exec "DELETE FROM theft_insurance;"
}

db_reset_liability_insurance() {
    db_exec "DELETE FROM liability_insurance_audit;"
    db_exec "DELETE FROM liability_insurance;"
}

db_reset_professional_indemnity() {
    db_exec "DELETE FROM professional_indemnity_audit;"
    db_exec "DELETE FROM professional_indemnity;"
}

db_reset_directors_liability() {
    db_exec "DELETE FROM directors_liability_audit;"
    db_exec "DELETE FROM directors_liability;"
}

db_reset_product_liability() {
    db_exec "DELETE FROM product_liability_audit;"
    db_exec "DELETE FROM product_liability;"
}

db_reset_public_liability() {
    db_exec "DELETE FROM public_liability_audit;"
    db_exec "DELETE FROM public_liability;"
}

db_reset_employer_liability() {
    db_exec "DELETE FROM employer_liability_audit;"
    db_exec "DELETE FROM employer_liability;"
}

db_reset_cyber_insurance() {
    db_exec "DELETE FROM cyber_insurance_audit;"
    db_exec "DELETE FROM cyber_insurance;"
}

db_reset_kidnap_ransom() {
    db_exec "DELETE FROM kidnap_ransom_audit;"
    db_exec "DELETE FROM kidnap_ransom;"
}

db_reset_political_risk() {
    db_exec "DELETE FROM political_risk_audit;"
    db_exec "DELETE FROM political_risk;"
}

db_reset_credit_insurance2() {
    db_exec "DELETE FROM credit_insurance2_audit;"
    db_exec "DELETE FROM credit_insurance2;"
}

db_reset_surety() {
    db_exec "DELETE FROM surety_audit;"
    db_exec "DELETE FROM surety;"
}

db_reset_guarantee() {
    db_exec "DELETE FROM guarantee_audit;"
    db_exec "DELETE FROM guarantee;"
}

db_reset_bond_insurance() {
    db_exec "DELETE FROM bond_insurance_audit;"
    db_exec "DELETE FROM bond_insurance;"
}

db_reset_fidelity() {
    db_exec "DELETE FROM fidelity_audit;"
    db_exec "DELETE FROM fidelity;"
}

db_reset_crime() {
    db_exec "DELETE FROM crime_audit;"
    db_exec "DELETE FROM crime;"
}

db_reset_errors_omissions() {
    db_exec "DELETE FROM errors_omissions_audit;"
    db_exec "DELETE FROM errors_omissions;"
}

db_reset_professional_risk() {
    db_exec "DELETE FROM professional_risk_audit;"
    db_exec "DELETE FROM professional_risk;"
}

db_reset_management_liability() {
    db_exec "DELETE FROM management_liability_audit;"
    db_exec "DELETE FROM management_liability;"
}

db_reset_employment_practices() {
    db_exec "DELETE FROM employment_practices_audit;"
    db_exec "DELETE FROM employment_practices;"
}

db_reset_fiduciary() {
    db_exec "DELETE FROM fiduciary_audit;"
    db_exec "DELETE FROM fiduciary;"
}

db_reset_vendor_mgmt() {
    db_exec "DELETE FROM vendor_mgmt_audit;"
    db_exec "DELETE FROM vendor_mgmt;"
}

db_reset_supplier() {
    db_exec "DELETE FROM supplier_audit;"
    db_exec "DELETE FROM supplier;"
}

db_reset_procurement_mgmt() {
    db_exec "DELETE FROM procurement_mgmt_audit;"
    db_exec "DELETE FROM procurement_mgmt;"
}

db_reset_purchasing() {
    db_exec "DELETE FROM purchasing_audit;"
    db_exec "DELETE FROM purchasing;"
}

db_reset_inventory() {
    db_exec "DELETE FROM inventory_audit;"
    db_exec "DELETE FROM inventory;"
}

db_reset_stock() {
    db_exec "DELETE FROM stock_audit;"
    db_exec "DELETE FROM stock;"
}

db_reset_warehouse() {
    db_exec "DELETE FROM warehouse_audit;"
    db_exec "DELETE FROM warehouse;"
}

db_reset_logistics() {
    db_exec "DELETE FROM logistics_audit;"
    db_exec "DELETE FROM logistics;"
}

db_reset_shipping() {
    db_exec "DELETE FROM shipping_audit;"
    db_exec "DELETE FROM shipping;"
}

db_reset_delivery() {
    db_exec "DELETE FROM delivery_audit;"
    db_exec "DELETE FROM delivery;"
}

db_reset_tracking() {
    db_exec "DELETE FROM tracking_audit;"
    db_exec "DELETE FROM tracking;"
}

db_reset_fulfillment() {
    db_exec "DELETE FROM fulfillment_audit;"
    db_exec "DELETE FROM fulfillment;"
}

db_reset_order_mgmt2() {
    db_exec "DELETE FROM order_mgmt2_audit;"
    db_exec "DELETE FROM order_mgmt2;"
}

db_reset_invoice_mgmt() {
    db_exec "DELETE FROM invoice_mgmt_audit;"
    db_exec "DELETE FROM invoice_mgmt;"
}

db_reset_billing_mgmt() {
    db_exec "DELETE FROM billing_mgmt_audit;"
    db_exec "DELETE FROM billing_mgmt;"
}

db_reset_payment_mgmt() {
    db_exec "DELETE FROM payment_mgmt_audit;"
    db_exec "DELETE FROM payment_mgmt;"
}

db_reset_collection_mgmt() {
    db_exec "DELETE FROM collection_mgmt_audit;"
    db_exec "DELETE FROM collection_mgmt;"
}

db_reset_receivable() {
    db_exec "DELETE FROM receivable_audit;"
    db_exec "DELETE FROM receivable;"
}

db_reset_payable() {
    db_exec "DELETE FROM payable_audit;"
    db_exec "DELETE FROM payable;"
}

db_reset_expense() {
    db_exec "DELETE FROM expense_audit;"
    db_exec "DELETE FROM expense;"
}

db_reset_budget_mgmt() {
    db_exec "DELETE FROM budget_mgmt_audit;"
    db_exec "DELETE FROM budget_mgmt;"
}

db_reset_forecast_mgmt() {
    db_exec "DELETE FROM forecast_mgmt_audit;"
    db_exec "DELETE FROM forecast_mgmt;"
}

db_reset_planning() {
    db_exec "DELETE FROM planning_audit;"
    db_exec "DELETE FROM planning;"
}

db_reset_strategy() {
    db_exec "DELETE FROM strategy_audit;"
    db_exec "DELETE FROM strategy;"
}

db_reset_analysis() {
    db_exec "DELETE FROM analysis_audit;"
    db_exec "DELETE FROM analysis;"
}

db_reset_research() {
    db_exec "DELETE FROM research_audit;"
    db_exec "DELETE FROM research;"
}

db_reset_development() {
    db_exec "DELETE FROM development_audit;"
    db_exec "DELETE FROM development;"
}

db_reset_testing() {
    db_exec "DELETE FROM testing_audit;"
    db_exec "DELETE FROM testing;"
}

db_reset_quality() {
    db_exec "DELETE FROM quality_audit;"
    db_exec "DELETE FROM quality;"
}

db_reset_audit_mgmt() {
    db_exec "DELETE FROM audit_mgmt_audit;"
    db_exec "DELETE FROM audit_mgmt;"
}

db_reset_core_banking() {
    db_exec "DELETE FROM core_banking_audit;"
    db_exec "DELETE FROM core_banking;"
}

db_reset_retail_banking() {
    db_exec "DELETE FROM retail_banking_audit;"
    db_exec "DELETE FROM retail_banking;"
}

db_reset_corporate_banking() {
    db_exec "DELETE FROM corporate_banking_audit;"
    db_exec "DELETE FROM corporate_banking;"
}

db_reset_investment_banking() {
    db_exec "DELETE FROM investment_banking_audit;"
    db_exec "DELETE FROM investment_banking;"
}

db_reset_private_banking() {
    db_exec "DELETE FROM private_banking_audit;"
    db_exec "DELETE FROM private_banking;"
}

db_reset_wholesale_banking() {
    db_exec "DELETE FROM wholesale_banking_audit;"
    db_exec "DELETE FROM wholesale_banking;"
}

db_reset_digital_banking2() {
    db_exec "DELETE FROM digital_banking2_audit;"
    db_exec "DELETE FROM digital_banking2;"
}

db_reset_mobile_banking() {
    db_exec "DELETE FROM mobile_banking_audit;"
    db_exec "DELETE FROM mobile_banking;"
}

db_reset_internet_banking2() {
    db_exec "DELETE FROM internet_banking2_audit;"
    db_exec "DELETE FROM internet_banking2;"
}

db_reset_branch_banking() {
    db_exec "DELETE FROM branch_banking_audit;"
    db_exec "DELETE FROM branch_banking;"
}

db_reset_central_banking() {
    db_exec "DELETE FROM central_banking_audit;"
    db_exec "DELETE FROM central_banking;"
}

db_reset_commercial_banking() {
    db_exec "DELETE FROM commercial_banking_audit;"
    db_exec "DELETE FROM commercial_banking;"
}

db_reset_community_banking() {
    db_exec "DELETE FROM community_banking_audit;"
    db_exec "DELETE FROM community_banking;"
}

db_reset_cooperative_banking() {
    db_exec "DELETE FROM cooperative_banking_audit;"
    db_exec "DELETE FROM cooperative_banking;"
}

db_reset_savings_bank() {
    db_exec "DELETE FROM savings_bank_audit;"
    db_exec "DELETE FROM savings_bank;"
}

db_reset_credit_union() {
    db_exec "DELETE FROM credit_union_audit;"
    db_exec "DELETE FROM credit_union;"
}

db_reset_building_society() {
    db_exec "DELETE FROM building_society_audit;"
    db_exec "DELETE FROM building_society;"
}

db_reset_thrift() {
    db_exec "DELETE FROM thrift_audit;"
    db_exec "DELETE FROM thrift;"
}

db_reset_finance_company() {
    db_exec "DELETE FROM finance_company_audit;"
    db_exec "DELETE FROM finance_company;"
}

db_reset_leasing_company() {
    db_exec "DELETE FROM leasing_company_audit;"
    db_exec "DELETE FROM leasing_company;"
}

db_reset_factoring_company() {
    db_exec "DELETE FROM factoring_company_audit;"
    db_exec "DELETE FROM factoring_company;"
}

db_reset_consumer_finance() {
    db_exec "DELETE FROM consumer_finance_audit;"
    db_exec "DELETE FROM consumer_finance;"
}

db_reset_auto_finance() {
    db_exec "DELETE FROM auto_finance_audit;"
    db_exec "DELETE FROM auto_finance;"
}

db_reset_mortgage_bank() {
    db_exec "DELETE FROM mortgage_bank_audit;"
    db_exec "DELETE FROM mortgage_bank;"
}

db_reset_housing_finance() {
    db_exec "DELETE FROM housing_finance_audit;"
    db_exec "DELETE FROM housing_finance;"
}

db_reset_agricultural_finance() {
    db_exec "DELETE FROM agricultural_finance_audit;"
    db_exec "DELETE FROM agricultural_finance;"
}

db_reset_micro_lending() {
    db_exec "DELETE FROM micro_lending_audit;"
    db_exec "DELETE FROM micro_lending;"
}

db_reset_nano_lending() {
    db_exec "DELETE FROM nano_lending_audit;"
    db_exec "DELETE FROM nano_lending;"
}

db_reset_peer_lending() {
    db_exec "DELETE FROM peer_lending_audit;"
    db_exec "DELETE FROM peer_lending;"
}

db_reset_crowd_lending() {
    db_exec "DELETE FROM crowd_lending_audit;"
    db_exec "DELETE FROM crowd_lending;"
}
