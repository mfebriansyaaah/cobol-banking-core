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
