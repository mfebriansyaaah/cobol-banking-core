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

db_reset_velocity() {
    db_exec "DELETE FROM fee_audit WHERE action IN ('PROFILE_CREATE', 'VELOCITY_RECORD'); DELETE FROM velocity_counter; DELETE FROM velocity_profile;"
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

db_reset_cost_center() {
    db_exec "DELETE FROM cost_center_audit; DELETE FROM cost_center;"
}

db_reset_fixed_asset() {
    db_exec "DELETE FROM fixed_asset_disposal;"
    db_exec "DELETE FROM fixed_asset_depreciation;"
    db_exec "DELETE FROM fixed_asset_audit; DELETE FROM fixed_asset;"
}

db_reset_collateral() {
    db_exec "DELETE FROM collateral_allocation; DELETE FROM collateral_pledge; DELETE FROM collateral_valuation; DELETE FROM collateral_audit; DELETE FROM collateral;"
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

db_reset_collateral_mgmt() {
    db_exec "DELETE FROM collateral_mgmt_audit; DELETE FROM collateral_mgmt;"
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

db_reset_letter_of_credit() {
    db_exec "DELETE FROM letter_of_credit_audit; DELETE FROM letter_of_credit;"
}

db_reset_bank_guarantee() {
    db_exec "DELETE FROM bank_guarantee_audit; DELETE FROM bank_guarantee;"
}

db_reset_payroll_processing() {
    db_exec "DELETE FROM payroll_payment;"
    db_exec "DELETE FROM payroll_item;"
    db_exec "DELETE FROM payroll_employee;"
    db_exec "DELETE FROM payroll_audit;"
    db_exec "DELETE FROM payroll_processing_audit; DELETE FROM payroll_processing;"
}

db_reset_merchant_settlement() {
    db_exec "DELETE FROM merchant_settlement_item;"
    db_exec "DELETE FROM merchant_settlement_audit; DELETE FROM merchant_settlement;"
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

db_reset_dispute_management() {
    db_exec "DELETE FROM dispute_management_audit; DELETE FROM dispute_management;"
}

db_reset_chargeback() {
    db_exec "DELETE FROM chargeback_audit; DELETE FROM chargeback;"
}

db_reset_collateral_repossession() {
    db_exec "DELETE FROM collateral_repossession_audit; DELETE FROM collateral_repossession;"
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

db_reset_tax_withholding() {
    db_exec "DELETE FROM tax_withholding_audit; DELETE FROM tax_withholding;"
}

db_reset_collateralized() {
    db_exec "DELETE FROM collateralized_audit; DELETE FROM collateralized;"
}






db_reset_tax_item() {
    db_exec "DELETE FROM tax_item_audit; DELETE FROM tax_item;"
}

db_reset_factoring() {
    db_exec "DELETE FROM factoring_audit; DELETE FROM factoring;"
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

