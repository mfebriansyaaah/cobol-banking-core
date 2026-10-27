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
