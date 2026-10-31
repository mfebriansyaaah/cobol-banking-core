#!/usr/bin/env bash
# Integration tests across domains: loan -> collection -> payment -> treasury.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/tests/lib/db.sh"
# shellcheck disable=SC1091
. "$ROOT/tests/lib/cobol.sh"
require_db

T_PASS=0; T_FAIL=0; T_TOTAL=0
# shellcheck disable=SC1091
. "$ROOT/tests/lib/assert.sh"

db_seed
echo "=== Cross-domain integration: loan -> collection -> payment ==="

# Fixed refs (INTCOL1/INTPAY1/INTTRL1) and the INTTEST loan rows must not fail
# a re-run: clean previous-run leftovers upfront and again at the end.
cleanup_int_refs() {
    db_exec "DELETE FROM collection_audit WHERE case_id IN (SELECT id FROM collection_case WHERE case_ref='INTCOL1');"
    db_exec "DELETE FROM collection_activity WHERE case_id IN (SELECT id FROM collection_case WHERE case_ref='INTCOL1');"
    db_exec "DELETE FROM collection_case WHERE case_ref='INTCOL1';"
    db_exec "DELETE FROM payment_clearing_audit WHERE clearing_id IN (SELECT id FROM payment_clearing WHERE clearing_ref='INTPAY1');"
    db_exec "DELETE FROM payment_clearing WHERE clearing_ref='INTPAY1';"
    db_exec "DELETE FROM treasury_liquidity_audit WHERE liq_id IN (SELECT id FROM treasury_liquidity WHERE liq_ref='INTTRL1');"
    db_exec "DELETE FROM treasury_liquidity WHERE liq_ref='INTTRL1';"
    db_exec "DELETE i FROM loan_installment i JOIN loan_schedule s ON s.id=i.schedule_id JOIN loan_application l ON l.id=s.loan_id WHERE l.customer_email='inttest@test.com';"
    db_exec "DELETE s FROM loan_schedule s JOIN loan_application l ON l.id=s.loan_id WHERE l.customer_email='inttest@test.com';"
    db_exec "DELETE FROM loan_application WHERE customer_email='inttest@test.com';"
}
cleanup_int_refs

# Create a loan schedule (via SQL seed)
ADMIN="inttest@test.com"
db_exec "INSERT INTO users (email, password_hash, full_name, dob, status, role) VALUES ('$ADMIN', CONCAT('SHA256_',SHA2('secret123',256)), 'IntTest', '1990-01-01', 'VERIFIED', 'SUPER_ADMIN') ON DUPLICATE KEY UPDATE role='SUPER_ADMIN', status='VERIFIED';"
db_exec "INSERT INTO loan_application (customer_email, principal, currency, term_months, interest_rate, status, created_by) VALUES ('$ADMIN', 5000, 'USD', 12, 5.0000, 'DISBURSED', '$ADMIN');"
LOAN_ID=$(db_query "SELECT id FROM loan_application WHERE customer_email='$ADMIN' ORDER BY id DESC LIMIT 1;")
db_exec "INSERT INTO loan_schedule (loan_id, term_months, interest_rate, start_date, status, created_by) VALUES ($LOAN_ID, 12, 5.0000, CURDATE(), 'ACTIVE', '$ADMIN');"
SCHED_ID=$(db_query "SELECT id FROM loan_schedule WHERE loan_id=$LOAN_ID ORDER BY id DESC LIMIT 1;")
db_exec "INSERT INTO loan_installment (schedule_id, seq, due_date, principal_due, interest_due, total_due, status, paid_amount) VALUES ($SCHED_ID, 1, DATE_SUB(CURDATE(), INTERVAL 10 DAY), 400, 20, 420, 'DUE', 0);"

# Collection: open a collection case
COL_OUT=$(run_cobol "COL_OPEN|INTCOL1|$LOAN_ID||HIGH||$ADMIN")
assert_match "collection open" "$COL_OUT" "SUCCESS\|COL_OPEN"

# Payment: create a payment
PAY_OUT=$(run_cobol "PMC_CREATE|INTPAY1|100.00|USD|||$ADMIN")
assert_match "payment create" "$PAY_OUT" "SUCCESS\|PMC_CREATE"

# Treasury: create allocation
TRL_OUT=$(run_cobol "TRL_CREATE|INTTRL1|1000.00|USD|||$ADMIN")
assert_match "treasury create" "$TRL_OUT" "SUCCESS\|TRL_CREATE"

cleanup_int_refs

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0