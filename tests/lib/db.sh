# shellcheck shell=bash
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
#
# The runner (tests/run_all.sh db) checks once and exports DB_VERIFIED=1 so
# 518 suites don't each spawn a mysql client (~34ms each). Standalone suite
# runs always check.
require_db() {
    if [ "${DB_VERIFIED:-0}" = "1" ]; then
        return 0
    fi
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
    # Seeded once per runner invocation: run_all.sh db seeds up front and
    # exports DB_SEEDED=1. The seed file is idempotent (INSERT IGNORE +
    # keyed ledger reset) and no suite deletes or rewrites seed rows, so
    # re-seeding per suite is pure overhead (~77ms x 518). Standalone suite
    # runs always seed.
    if [ "${DB_SEEDED:-0}" = "1" ]; then
        :
    else
        mysql_app < "$ROOT/database/seed_test_data.sql" >/dev/null 2>&1
    fi
    # Every DB suite calls db_seed once in its main shell, so it doubles as
    # the hook that starts the persistent COBOL server (see tests/lib/cobol.sh).
    # The server hook needs cobol.sh, but re-sourcing it on every call costs
    # ~6ms x 518. Suites source it themselves before calling db_seed.
    if ! declare -F start_cobol_server >/dev/null 2>&1; then
        # shellcheck disable=SC1091
        . "$ROOT/tests/lib/cobol.sh"
    fi
    if [ "${COBOL_TEST_SERVE:-1}" = "1" ]; then
        start_cobol_server 2>/dev/null || true
    fi
}

# Reset D1 (loan_schedule) rows so tests are deterministic.
db_reset_loan_schedule() {
    db_exec "DELETE FROM loan_schedule_audit; DELETE FROM loan_installment; DELETE FROM loan_schedule; DELETE FROM loan_application WHERE customer_email = 'd1@test.com';"
}

# Reset D2 (deposit) rows so tests are deterministic. deposit_accrual and
# deposit_transaction cascade from deposit_account.
db_reset_deposit() {
    db_exec "DELETE FROM deposit_audit; DELETE FROM deposit_transaction; DELETE FROM deposit_accrual; DELETE FROM deposit_account;"
}

# Reset D3 (card) rows. card_transaction cascades from card_account.
db_reset_card() {
    db_exec "DELETE FROM card_audit; DELETE FROM card_transaction; DELETE FROM card_account;"
}

db_reset_payment_hold() {
    db_exec "DELETE FROM payment_hold_audit; DELETE FROM payment_hold;"
}

# Reset D4 (collections) rows plus the loan fixtures the suite creates.
db_reset_collection() {
    db_exec "DELETE FROM collection_activity; DELETE FROM collection_audit; DELETE FROM collection_case; DELETE i FROM loan_installment i JOIN loan_schedule s ON s.id = i.schedule_id JOIN loan_application l ON l.id = s.loan_id WHERE l.customer_email LIKE 'd4%'; DELETE s FROM loan_schedule s JOIN loan_application l ON l.id = s.loan_id WHERE l.customer_email LIKE 'd4%'; DELETE FROM loan_application WHERE customer_email LIKE 'd4%';"
}

db_reset_payment_clearing() {
    db_exec "DELETE FROM payment_clearing_audit; DELETE FROM payment_clearing;"
}

db_reset_treasury_liquidity() {
    db_exec "DELETE FROM treasury_liquidity_audit; DELETE FROM treasury_liquidity;"
}

db_reset_gl_allocation() {
    db_exec "DELETE FROM gl_allocation_audit; DELETE FROM gl_allocation;"
}

db_reset_backup_drill() {
    db_exec "DELETE FROM backup_drill_audit; DELETE FROM backup_drill;"
}

db_reset_report_builder() {
    db_exec "DELETE FROM report_builder_audit; DELETE FROM report_builder;"
}

db_reset_sanctions_list() {
    db_exec "DELETE FROM sanctions_list_audit; DELETE FROM sanctions_list;"
}

db_reset_cost_center() {
    db_exec "DELETE FROM cost_center_audit; DELETE FROM cost_center;"
}

db_reset_fixed_asset() {
    db_exec "DELETE FROM fixed_asset_disposal;"
    db_exec "DELETE FROM fixed_asset_depreciation;"
    db_exec "DELETE FROM fixed_asset_audit; DELETE FROM fixed_asset;"
}

db_reset_metric_definition() {
    db_exec "DELETE FROM metric_definition_audit; DELETE FROM metric_definition;"
}

db_reset_product_catalog() {
    db_exec "DELETE FROM product_catalog_audit; DELETE FROM product_catalog;"
}

db_reset_collateral() {
    db_exec "DELETE FROM collateral_allocation; DELETE FROM collateral_pledge; DELETE FROM collateral_valuation; DELETE FROM collateral_audit; DELETE FROM collateral;"
}

db_reset_standing_order() {
    db_exec "DELETE FROM standing_order_audit; DELETE FROM standing_order;"
}

db_reset_remittance() {
    db_exec "DELETE FROM remittance_audit; DELETE FROM remittance;"
}

db_reset_workflow_approval() {
    db_exec "DELETE FROM workflow_approval_audit; DELETE FROM workflow_approval;"
}

db_reset_trade_finance() {
    db_exec "DELETE FROM trade_finance_audit; DELETE FROM trade_finance;"
}

db_reset_merchant() {
    db_exec "DELETE FROM merchant_transaction;"
    db_exec "DELETE FROM merchant_fee_profile;"
    db_exec "DELETE FROM merchant_audit; DELETE FROM merchant;"
}

db_reset_loan() {
    db_exec "DELETE FROM loan_repayment; DELETE FROM loan_audit; DELETE FROM loan; DELETE FROM loan_application;"
}


db_reset_account() {
    db_exec "DELETE FROM account_audit; DELETE FROM account;"
}

db_reset_treasury_deal() {
    db_exec "DELETE FROM treasury_deal_audit; DELETE FROM treasury_deal;"
}

db_reset_treasury_position() {
    db_exec "DELETE FROM treasury_audit; DELETE FROM treasury_position;"
}

db_reset_collateral_mgmt() {
    db_exec "DELETE FROM collateral_mgmt_audit; DELETE FROM collateral_mgmt;"
}

db_reset_standing_instruction() {
    db_exec "DELETE FROM standing_instruction_audit; DELETE FROM standing_instruction;"
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
    db_exec "DELETE FROM asset_management_audit; DELETE FROM asset_management;"
}

db_reset_portfolio_management() {
    db_exec "DELETE FROM portfolio_management_audit; DELETE FROM portfolio_management;"
}

db_reset_letter_of_credit() {
    db_exec "DELETE FROM letter_of_credit_audit; DELETE FROM letter_of_credit;"
}

db_reset_bank_guarantee() {
    db_exec "DELETE FROM bank_guarantee_audit; DELETE FROM bank_guarantee;"
}

db_reset_supply_chain_finance() {
    db_exec "DELETE FROM supply_chain_finance_audit; DELETE FROM supply_chain_finance;"
}

db_reset_payroll_processing() {
    db_exec "DELETE FROM payroll_payment;"
    db_exec "DELETE FROM payroll_item;"
    db_exec "DELETE FROM payroll_employee;"
    db_exec "DELETE FROM payroll_audit;"
    db_exec "DELETE FROM payroll_processing_audit; DELETE FROM payroll_processing;"
}

db_reset_wealth_management() {
    db_exec "DELETE FROM wealth_management_audit; DELETE FROM wealth_management;"
}

db_reset_merchant_settlement() {
    db_exec "DELETE FROM merchant_settlement_item;"
    db_exec "DELETE FROM merchant_settlement_audit; DELETE FROM merchant_settlement;"
}

db_reset_payment_gateway() {
    db_exec "DELETE FROM payment_gateway_audit; DELETE FROM payment_gateway;"
}

db_reset_mobile_wallet() {
    db_exec "DELETE FROM mobile_wallet_audit; DELETE FROM mobile_wallet;"
}

db_reset_rate_management() {
    db_exec "DELETE FROM rate_management_audit; DELETE FROM rate_management;"
}

db_reset_tax_management() {
    db_exec "DELETE FROM tax_audit;"
    db_exec "DELETE FROM tax_withholding_entry;"
    db_exec "DELETE FROM tax_report_run;"
    db_exec "DELETE FROM tax_management_audit; DELETE FROM tax_management;"
}

db_reset_adt_log() {
    db_exec "DELETE FROM adt_log_audit; DELETE FROM adt_log;"
}

db_reset_system_config() {
    db_exec "DELETE FROM system_config_audit; DELETE FROM system_config;"
}

db_reset_user_activity() {
    db_exec "DELETE FROM user_activity_audit; DELETE FROM user_activity;"
}

db_reset_role_management() {
    db_exec "DELETE FROM role_management_audit; DELETE FROM role_management;"
}

db_reset_permission_set() {
    db_exec "DELETE FROM permission_set_audit; DELETE FROM permission_set;"
}

db_reset_organization_unit() {
    db_exec "DELETE FROM organization_unit_audit; DELETE FROM organization_unit;"
}

db_reset_tokenization() {
    db_exec "DELETE FROM tokenization_audit; DELETE FROM tokenization;"
}

db_reset_smart_contract() {
    db_exec "DELETE FROM smart_contract_audit; DELETE FROM smart_contract;"
}

db_reset_nft_management() {
    db_exec "DELETE FROM nft_management_audit; DELETE FROM nft_management;"
}

db_reset_open_banking() {
    db_exec "DELETE FROM open_banking_audit; DELETE FROM open_banking;"
}

db_reset_pisp_management() {
    db_exec "DELETE FROM pisp_management_audit; DELETE FROM pisp_management;"
}

db_reset_dispute_management() {
    db_exec "DELETE FROM dispute_management_audit; DELETE FROM dispute_management;"
}

db_reset_chargeback() {
    db_exec "DELETE FROM chargeback_audit; DELETE FROM chargeback;"
}

db_reset_refund_processing() {
    db_exec "DELETE FROM refund_processing_audit; DELETE FROM refund_processing;"
}

db_reset_vault_management() {
    db_exec "DELETE FROM vault_management_audit; DELETE FROM vault_management;"
}

db_reset_teller_management() {
    db_exec "DELETE FROM teller_management_audit; DELETE FROM teller_management;"
}

db_reset_swap_contract() {
    db_exec "DELETE FROM swap_contract_audit; DELETE FROM swap_contract;"
}

db_reset_option_trading() {
    db_exec "DELETE FROM option_trading_audit; DELETE FROM option_trading;"
}

db_reset_repo_agreement() {
    db_exec "DELETE FROM repo_agreement_audit; DELETE FROM repo_agreement;"
}

db_reset_securities_lending() {
    db_exec "DELETE FROM securities_lending_audit; DELETE FROM securities_lending;"
}

db_reset_structured_product() {
    db_exec "DELETE FROM structured_product_audit; DELETE FROM structured_product;"
}

db_reset_syndicated_loan() {
    db_exec "DELETE FROM syndicated_loan_audit; DELETE FROM syndicated_loan;"
}

db_reset_reinsurance_contract() {
    db_exec "DELETE FROM reinsurance_contract_audit; DELETE FROM reinsurance_contract;"
}

db_reset_policy_administration() {
    db_exec "DELETE FROM policy_administration_audit; DELETE FROM policy_administration;"
}

db_reset_collateral_repossession() {
    db_exec "DELETE FROM collateral_repossession_audit; DELETE FROM collateral_repossession;"
}

db_reset_write_off() {
    db_exec "DELETE FROM write_off_audit; DELETE FROM write_off;"
}

db_reset_provisioning() {
    db_exec "DELETE FROM provisioning_audit; DELETE FROM provisioning;"
}

db_reset_risk_model() {
    db_exec "DELETE FROM risk_model_audit; DELETE FROM risk_model;"
}

db_reset_stress_test() {
    db_exec "DELETE FROM stress_test_audit; DELETE FROM stress_test;"
}




db_reset_whistleblowing() {
    db_exec "DELETE FROM whistleblowing_audit; DELETE FROM whistleblowing;"
}

db_reset_vendor_management() {
    db_exec "DELETE FROM vendor_management_audit; DELETE FROM vendor_management;"
}

db_reset_outsourcing_contract() {
    db_exec "DELETE FROM outsourcing_contract_audit; DELETE FROM outsourcing_contract;"
}

db_reset_loyalty_program() {
    db_exec "DELETE FROM loyalty_program_audit; DELETE FROM loyalty_program;"
}

db_reset_loyalty_domain() {
    db_exec "DELETE FROM loyalty_audit;"
    db_exec "DELETE FROM loyalty_redemption;"
    db_exec "DELETE FROM loyalty_points_ledger;"
    db_exec "DELETE FROM loyalty_member;"
    db_exec "DELETE FROM loyalty_campaign;"
    db_exec "DELETE FROM loyalty_program_audit; DELETE FROM loyalty_program;"
}

db_reset_rewards_management() {
    db_exec "DELETE FROM rewards_management_audit; DELETE FROM rewards_management;"
}

db_reset_cashback() {
    db_exec "DELETE FROM cashback_audit; DELETE FROM cashback;"
}

db_reset_points_redemption() {
    db_exec "DELETE FROM points_redemption_audit; DELETE FROM points_redemption;"
}

db_reset_prepaid_card() {
    db_exec "DELETE FROM prepaid_card_audit; DELETE FROM prepaid_card;"
}

db_reset_virtual_card() {
    db_exec "DELETE FROM virtual_card_audit; DELETE FROM virtual_card;"
}

db_reset_payment_link() {
    db_exec "DELETE FROM payment_link_audit; DELETE FROM payment_link;"
}

db_reset_qr_payment() {
    db_exec "DELETE FROM qr_payment_audit; DELETE FROM qr_payment;"
}

db_reset_session_management() {
    db_exec "DELETE FROM session_management_audit; DELETE FROM session_management;"
}

db_reset_token_management() {
    db_exec "DELETE FROM token_management_audit; DELETE FROM token_management;"
}

db_reset_otp_management() {
    db_exec "DELETE FROM otp_management_audit; DELETE FROM otp_management;"
}

db_reset_mfa_management() {
    db_exec "DELETE FROM mfa_management_audit; DELETE FROM mfa_management;"
}

db_reset_password_policy() {
    db_exec "DELETE FROM password_policy_audit; DELETE FROM password_policy;"
}

db_reset_transaction_limit() {
    db_exec "DELETE FROM transaction_limit_audit; DELETE FROM transaction_limit;"
}

db_reset_velocity_check() {
    db_exec "DELETE FROM velocity_check_audit; DELETE FROM velocity_check;"
}

db_reset_risk_score() {
    db_exec "DELETE FROM risk_score_audit; DELETE FROM risk_score;"
}

db_reset_whitelist() {
    db_exec "DELETE FROM whitelist_audit; DELETE FROM whitelist;"
}

db_reset_watchlist() {
    db_exec "DELETE FROM watchlist_audit; DELETE FROM watchlist;"
}

db_reset_pep_screening() {
    db_exec "DELETE FROM pep_screening_audit; DELETE FROM pep_screening;"
}

db_reset_name_screening() {
    db_exec "DELETE FROM name_screening_audit; DELETE FROM name_screening;"
}

db_reset_savings_account() {
    db_exec "DELETE FROM savings_account_audit; DELETE FROM savings_account;"
}

db_reset_term_deposit() {
    db_exec "DELETE FROM term_deposit_audit; DELETE FROM term_deposit;"
}

db_reset_recurring_deposit() {
    db_exec "DELETE FROM recurring_deposit_audit; DELETE FROM recurring_deposit;"
}

db_reset_notice_deposit() {
    db_exec "DELETE FROM notice_deposit_audit; DELETE FROM notice_deposit;"
}

db_reset_multi_currency() {
    db_exec "DELETE FROM multi_currency_audit; DELETE FROM multi_currency;"
}

db_reset_total_return_swap() {
    db_exec "DELETE FROM total_return_swap_audit; DELETE FROM total_return_swap;"
}

db_reset_variance_swap() {
    db_exec "DELETE FROM variance_swap_audit; DELETE FROM variance_swap;"
}

db_reset_volatility() {
    db_exec "DELETE FROM volatility_audit; DELETE FROM volatility;"
}

db_reset_pricing() {
    db_exec "DELETE FROM pricing_audit; DELETE FROM pricing;"
}

db_reset_valuation() {
    db_exec "DELETE FROM valuation_audit; DELETE FROM valuation;"
}

db_reset_pnl() {
    db_exec "DELETE FROM pnl_audit; DELETE FROM pnl;"
}

db_reset_revenue() {
    db_exec "DELETE FROM revenue_audit; DELETE FROM revenue;"
}

db_reset_profit() {
    db_exec "DELETE FROM profit_audit; DELETE FROM profit;"
}

db_reset_position() {
    db_exec "DELETE FROM position_audit; DELETE FROM position;"
}

db_reset_performance() {
    db_exec "DELETE FROM performance_audit; DELETE FROM performance;"
}

db_reset_training() {
    db_exec "DELETE FROM training_audit; DELETE FROM training;"
}

db_reset_recruitment() {
    db_exec "DELETE FROM recruitment_audit; DELETE FROM recruitment;"
}

db_reset_onboarding() {
    db_exec "DELETE FROM onboarding_audit; DELETE FROM onboarding;"
}

db_reset_offboarding() {
    db_exec "DELETE FROM offboarding_audit; DELETE FROM offboarding;"
}

db_reset_pension() {
    db_exec "DELETE FROM pension_audit; DELETE FROM pension;"
}

db_reset_tax_withholding() {
    db_exec "DELETE FROM tax_withholding_audit; DELETE FROM tax_withholding;"
}

db_reset_subscription() {
    db_exec "DELETE FROM subscription_audit; DELETE FROM subscription;"
}

db_reset_sla_management() {
    db_exec "DELETE FROM sla_management_audit; DELETE FROM sla_management;"
}

db_reset_reporting() {
    db_exec "DELETE FROM reporting_audit; DELETE FROM reporting;"
}

db_reset_metric() {
    db_exec "DELETE FROM metric_audit; DELETE FROM metric;"
}

db_reset_sms() {
    db_exec "DELETE FROM sms_audit; DELETE FROM sms;"
}

db_reset_push_notification() {
    db_exec "DELETE FROM push_notification_audit; DELETE FROM push_notification;"
}

db_reset_webhook() {
    db_exec "DELETE FROM webhook_audit; DELETE FROM webhook;"
}

db_reset_service_mesh() {
    db_exec "DELETE FROM service_mesh_audit; DELETE FROM service_mesh;"
}

db_reset_session_store() {
    db_exec "DELETE FROM session_store_audit; DELETE FROM session_store;"
}

db_reset_personalization() {
    db_exec "DELETE FROM personalization_audit; DELETE FROM personalization;"
}

db_reset_recommendation() {
    db_exec "DELETE FROM recommendation_audit; DELETE FROM recommendation;"
}

db_reset_search() {
    db_exec "DELETE FROM search_audit; DELETE FROM search;"
}

db_reset_monitoring() {
    db_exec "DELETE FROM monitoring_audit; DELETE FROM monitoring;"
}

db_reset_tracing() {
    db_exec "DELETE FROM tracing_audit; DELETE FROM tracing;"
}

db_reset_metrics() {
    db_exec "DELETE FROM metrics_audit; DELETE FROM metrics;"
}

db_reset_rate_limiter() {
    db_exec "DELETE FROM rate_limiter_audit; DELETE FROM rate_limiter;"
}

db_reset_retry() {
    db_exec "DELETE FROM retry_audit; DELETE FROM retry;"
}

db_reset_timeout() {
    db_exec "DELETE FROM timeout_audit; DELETE FROM timeout;"
}

db_reset_warrant() {
    db_exec "DELETE FROM warrant_audit; DELETE FROM warrant;"
}

db_reset_structured() {
    db_exec "DELETE FROM structured_audit; DELETE FROM structured;"
}

db_reset_mortgage_backed() {
    db_exec "DELETE FROM mortgage_backed_audit; DELETE FROM mortgage_backed;"
}

db_reset_collateralized() {
    db_exec "DELETE FROM collateralized_audit; DELETE FROM collateralized;"
}

db_reset_tranche() {
    db_exec "DELETE FROM tranche_audit; DELETE FROM tranche;"
}

db_reset_securitization() {
    db_exec "DELETE FROM securitization_audit; DELETE FROM securitization;"
}

db_reset_special_purpose() {
    db_exec "DELETE FROM special_purpose_audit; DELETE FROM special_purpose;"
}

db_reset_vehicle() {
    db_exec "DELETE FROM vehicle_audit; DELETE FROM vehicle;"
}

db_reset_trust() {
    db_exec "DELETE FROM trust_audit; DELETE FROM trust;"
}

db_reset_mutual_fund() {
    db_exec "DELETE FROM mutual_fund_audit; DELETE FROM mutual_fund;"
}

db_reset_private_equity() {
    db_exec "DELETE FROM private_equity_audit; DELETE FROM private_equity;"
}

db_reset_venture_capital() {
    db_exec "DELETE FROM venture_capital_audit; DELETE FROM venture_capital;"
}

db_reset_real_estate() {
    db_exec "DELETE FROM real_estate_audit; DELETE FROM real_estate;"
}

db_reset_private_debt() {
    db_exec "DELETE FROM private_debt_audit; DELETE FROM private_debt;"
}

db_reset_mezzanine() {
    db_exec "DELETE FROM mezzanine_audit; DELETE FROM mezzanine;"
}

db_reset_warrant_issuing() {
    db_exec "DELETE FROM warrant_issuing_audit; DELETE FROM warrant_issuing;"
}

db_reset_structured_note() {
    db_exec "DELETE FROM structured_note_audit; DELETE FROM structured_note;"
}

db_reset_sanctions_check() {
    db_exec "DELETE FROM sanctions_check_audit; DELETE FROM sanctions_check;"
}

db_reset_transaction() {
    db_exec "DELETE FROM transaction_audit; DELETE FROM transaction;"
}

db_reset_payment_processing() {
    db_exec "DELETE FROM payment_processing_audit; DELETE FROM payment_processing;"
}

db_reset_transfer() {
    db_exec "DELETE FROM transfer_audit; DELETE FROM transfer;"
}


db_reset_withdrawal() {
    db_exec "DELETE FROM withdrawal_audit; DELETE FROM withdrawal;"
}

db_reset_reconciliation() {
    db_exec "DELETE FROM reconciliation_audit; DELETE FROM reconciliation;"
}


db_reset_netting() {
    db_exec "DELETE FROM netting_audit; DELETE FROM netting;"
}

db_reset_nostro() {
    db_exec "DELETE FROM nostro_audit; DELETE FROM nostro;"
}

db_reset_vostro() {
    db_exec "DELETE FROM vostro_audit; DELETE FROM vostro;"
}

db_reset_suspense() {
    db_exec "DELETE FROM suspense_audit; DELETE FROM suspense;"
}


db_reset_trial_balance() {
    db_exec "DELETE FROM trial_balance_audit; DELETE FROM trial_balance;"
}


db_reset_reserve() {
    db_exec "DELETE FROM reserve_audit; DELETE FROM reserve;"
}

db_reset_variance() {
    db_exec "DELETE FROM variance_audit; DELETE FROM variance;"
}

db_reset_scenario() {
    db_exec "DELETE FROM scenario_audit; DELETE FROM scenario;"
}

db_reset_simulation() {
    db_exec "DELETE FROM simulation_audit; DELETE FROM simulation;"
}

db_reset_optimization() {
    db_exec "DELETE FROM optimization_audit; DELETE FROM optimization;"
}

db_reset_transfer_pricing() {
    db_exec "DELETE FROM transfer_pricing_audit; DELETE FROM transfer_pricing;"
}

db_reset_profit_center() {
    db_exec "DELETE FROM profit_center_audit; DELETE FROM profit_center;"
}

db_reset_portfolio() {
    db_exec "DELETE FROM portfolio_audit; DELETE FROM portfolio;"
}

db_reset_rebalancing() {
    db_exec "DELETE FROM rebalancing_audit; DELETE FROM rebalancing;"
}

db_reset_price_feed() {
    db_exec "DELETE FROM price_feed_audit; DELETE FROM price_feed;"
}

db_reset_quote() {
    db_exec "DELETE FROM quote_audit; DELETE FROM quote;"
}

db_reset_order_mgmt() {
    db_exec "DELETE FROM order_mgmt_audit; DELETE FROM order_mgmt;"
}

db_reset_position_mgmt() {
    db_exec "DELETE FROM position_mgmt_audit; DELETE FROM position_mgmt;"
}


db_reset_product_item() {
    db_exec "DELETE FROM product_item_audit; DELETE FROM product_item;"
}

db_reset_payment_item() {
    db_exec "DELETE FROM payment_item_audit; DELETE FROM payment_item;"
}

db_reset_transfer_item() {
    db_exec "DELETE FROM transfer_item_audit; DELETE FROM transfer_item;"
}

db_reset_transaction_item() {
    db_exec "DELETE FROM transaction_item_audit; DELETE FROM transaction_item;"
}

db_reset_statement_item() {
    db_exec "DELETE FROM statement_item_audit; DELETE FROM statement_item;"
}

db_reset_penalty_item() {
    db_exec "DELETE FROM penalty_item_audit; DELETE FROM penalty_item;"
}

db_reset_tax_item() {
    db_exec "DELETE FROM tax_item_audit; DELETE FROM tax_item;"
}

db_reset_rebate_item() {
    db_exec "DELETE FROM rebate_item_audit; DELETE FROM rebate_item;"
}

db_reset_refund_item() {
    db_exec "DELETE FROM refund_item_audit; DELETE FROM refund_item;"
}

db_reset_reversal_item() {
    db_exec "DELETE FROM reversal_item_audit; DELETE FROM reversal_item;"
}

db_reset_suspension_item() {
    db_exec "DELETE FROM suspension_item_audit; DELETE FROM suspension_item;"
}

db_reset_termination_item() {
    db_exec "DELETE FROM termination_item_audit; DELETE FROM termination_item;"
}

db_reset_reopening_item() {
    db_exec "DELETE FROM reopening_item_audit; DELETE FROM reopening_item;"
}

db_reset_mortgage() {
    db_exec "DELETE FROM mortgage_audit; DELETE FROM mortgage;"
}

db_reset_personal_loan() {
    db_exec "DELETE FROM personal_loan_audit; DELETE FROM personal_loan;"
}

db_reset_overdraft() {
    db_exec "DELETE FROM overdraft_audit; DELETE FROM overdraft;"
}

db_reset_factoring() {
    db_exec "DELETE FROM factoring_audit; DELETE FROM factoring;"
}

db_reset_pawn() {
    db_exec "DELETE FROM pawn_audit; DELETE FROM pawn;"
}

db_reset_microfinance() {
    db_exec "DELETE FROM microfinance_audit; DELETE FROM microfinance;"
}

db_reset_peer_to_peer() {
    db_exec "DELETE FROM peer_to_peer_audit; DELETE FROM peer_to_peer;"
}

db_reset_supply_chain() {
    db_exec "DELETE FROM supply_chain_audit; DELETE FROM supply_chain;"
}

db_reset_trade_credit() {
    db_exec "DELETE FROM trade_credit_audit; DELETE FROM trade_credit;"
}

db_reset_export_finance() {
    db_exec "DELETE FROM export_finance_audit; DELETE FROM export_finance;"
}

db_reset_import_finance() {
    db_exec "DELETE FROM import_finance_audit; DELETE FROM import_finance;"
}

db_reset_documentary_credit() {
    db_exec "DELETE FROM documentary_credit_audit; DELETE FROM documentary_credit;"
}

db_reset_bankers_acceptance() {
    db_exec "DELETE FROM bankers_acceptance_audit; DELETE FROM bankers_acceptance;"
}

db_reset_promissory_note() {
    db_exec "DELETE FROM promissory_note_audit; DELETE FROM promissory_note;"
}

db_reset_performance_bond() {
    db_exec "DELETE FROM performance_bond_audit; DELETE FROM performance_bond;"
}

db_reset_retention_money() {
    db_exec "DELETE FROM retention_money_audit; DELETE FROM retention_money;"
}

db_reset_milestone_payment() {
    db_exec "DELETE FROM milestone_payment_audit; DELETE FROM milestone_payment;"
}

db_reset_warranty() {
    db_exec "DELETE FROM warranty_audit; DELETE FROM warranty;"
}

db_reset_regulatory_filing() {
    db_exec "DELETE FROM regulatory_filing_audit; DELETE FROM regulatory_filing;"
}

db_reset_risk_assessment() {
    db_exec "DELETE FROM risk_assessment_audit; DELETE FROM risk_assessment;"
}

db_reset_policy_review() {
    db_exec "DELETE FROM policy_review_audit; DELETE FROM policy_review;"
}

db_reset_procedure_review() {
    db_exec "DELETE FROM procedure_review_audit; DELETE FROM procedure_review;"
}

db_reset_training_record() {
    db_exec "DELETE FROM training_record_audit; DELETE FROM training_record;"
}

db_reset_permit() {
    db_exec "DELETE FROM permit_audit; DELETE FROM permit;"
}

db_reset_registration() {
    db_exec "DELETE FROM registration_audit; DELETE FROM registration;"
}

db_reset_submission() {
    db_exec "DELETE FROM submission_audit; DELETE FROM submission;"
}

db_reset_notification_mgmt() {
    db_exec "DELETE FROM notification_mgmt_audit; DELETE FROM notification_mgmt;"
}

db_reset_problem() {
    db_exec "DELETE FROM problem_audit; DELETE FROM problem;"
}

db_reset_release_mgmt() {
    db_exec "DELETE FROM release_mgmt_audit; DELETE FROM release_mgmt;"
}

db_reset_rollback() {
    db_exec "DELETE FROM rollback_audit; DELETE FROM rollback;"
}

db_reset_patch() {
    db_exec "DELETE FROM patch_audit; DELETE FROM patch;"
}

db_reset_upgrade() {
    db_exec "DELETE FROM upgrade_audit; DELETE FROM upgrade;"
}

db_reset_migration() {
    db_exec "DELETE FROM migration_audit; DELETE FROM migration;"
}

db_reset_property_insurance() {
    db_exec "DELETE FROM property_insurance_audit; DELETE FROM property_insurance;"
}

db_reset_travel_insurance() {
    db_exec "DELETE FROM travel_insurance_audit; DELETE FROM travel_insurance;"
}

db_reset_theft_insurance() {
    db_exec "DELETE FROM theft_insurance_audit; DELETE FROM theft_insurance;"
}

db_reset_professional_indemnity() {
    db_exec "DELETE FROM professional_indemnity_audit; DELETE FROM professional_indemnity;"
}

db_reset_product_liability() {
    db_exec "DELETE FROM product_liability_audit; DELETE FROM product_liability;"
}

db_reset_public_liability() {
    db_exec "DELETE FROM public_liability_audit; DELETE FROM public_liability;"
}

db_reset_political_risk() {
    db_exec "DELETE FROM political_risk_audit; DELETE FROM political_risk;"
}

db_reset_surety() {
    db_exec "DELETE FROM surety_audit; DELETE FROM surety;"
}

db_reset_professional_risk() {
    db_exec "DELETE FROM professional_risk_audit; DELETE FROM professional_risk;"
}

db_reset_vendor_mgmt() {
    db_exec "DELETE FROM vendor_mgmt_audit; DELETE FROM vendor_mgmt;"
}

db_reset_supplier() {
    db_exec "DELETE FROM supplier_audit; DELETE FROM supplier;"
}

db_reset_procurement_mgmt() {
    db_exec "DELETE FROM procurement_mgmt_audit; DELETE FROM procurement_mgmt;"
}

db_reset_purchasing() {
    db_exec "DELETE FROM purchasing_audit; DELETE FROM purchasing;"
}

db_reset_stock() {
    db_exec "DELETE FROM stock_audit; DELETE FROM stock;"
}

db_reset_warehouse() {
    db_exec "DELETE FROM warehouse_audit; DELETE FROM warehouse;"
}

db_reset_shipping() {
    db_exec "DELETE FROM shipping_audit; DELETE FROM shipping;"
}

db_reset_tracking() {
    db_exec "DELETE FROM tracking_audit; DELETE FROM tracking;"
}

db_reset_order_mgmt2() {
    db_exec "DELETE FROM order_mgmt2_audit; DELETE FROM order_mgmt2;"
}

db_reset_payment_mgmt() {
    db_exec "DELETE FROM payment_mgmt_audit; DELETE FROM payment_mgmt;"
}

db_reset_receivable() {
    db_exec "DELETE FROM receivable_audit; DELETE FROM receivable;"
}

db_reset_payable() {
    db_exec "DELETE FROM payable_audit; DELETE FROM payable;"
}

db_reset_planning() {
    db_exec "DELETE FROM planning_audit; DELETE FROM planning;"
}

db_reset_strategy() {
    db_exec "DELETE FROM strategy_audit; DELETE FROM strategy;"
}

db_reset_research() {
    db_exec "DELETE FROM research_audit; DELETE FROM research;"
}

db_reset_testing() {
    db_exec "DELETE FROM testing_audit; DELETE FROM testing;"
}

db_reset_quality() {
    db_exec "DELETE FROM quality_audit; DELETE FROM quality;"
}

db_reset_retail_banking() {
    db_exec "DELETE FROM retail_banking_audit; DELETE FROM retail_banking;"
}

db_reset_private_banking() {
    db_exec "DELETE FROM private_banking_audit; DELETE FROM private_banking;"
}

db_reset_wholesale_banking() {
    db_exec "DELETE FROM wholesale_banking_audit; DELETE FROM wholesale_banking;"
}

db_reset_mobile_banking() {
    db_exec "DELETE FROM mobile_banking_audit; DELETE FROM mobile_banking;"
}

db_reset_savings_bank() {
    db_exec "DELETE FROM savings_bank_audit; DELETE FROM savings_bank;"
}

db_reset_thrift() {
    db_exec "DELETE FROM thrift_audit; DELETE FROM thrift;"
}

db_reset_mortgage_bank() {
    db_exec "DELETE FROM mortgage_bank_audit; DELETE FROM mortgage_bank;"
}

db_reset_micro_lending() {
    db_exec "DELETE FROM micro_lending_audit; DELETE FROM micro_lending;"
}

db_reset_nano_lending() {
    db_exec "DELETE FROM nano_lending_audit; DELETE FROM nano_lending;"
}

db_reset_peer_lending() {
    db_exec "DELETE FROM peer_lending_audit; DELETE FROM peer_lending;"
}

