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

db_reset_regulatory_report() {
    db_exec "DELETE FROM regulatory_report_audit;"
    db_exec "DELETE FROM regulatory_report;"
}

db_reset_compliance_audit() {
    db_exec "DELETE FROM compliance_audit_audit;"
    db_exec "DELETE FROM compliance_audit;"
}

db_reset_tax_report() {
    db_exec "DELETE FROM tax_report_audit;"
    db_exec "DELETE FROM tax_report;"
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
