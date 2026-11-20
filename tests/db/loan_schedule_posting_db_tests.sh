#!/usr/bin/env bash
# Loan-schedule posting (PR-5b): schedule -> post installment -> settle.
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
A="admin@test.com"
db_exec "INSERT INTO loan_application (customer_email, principal, currency, term_months, interest_rate, status, created_by) VALUES ('lsc_post@test.com', 10000, 'USD', 12, 10.0000, 'DISBURSED', '${A}')"
loan_id="$(db_query "SELECT id FROM loan_application WHERE customer_email='lsc_post@test.com' ORDER BY id DESC LIMIT 1;")"
run_cobol "LSC_CREATE|${loan_id}|12|10.0000|2026-01-01||${A}" >/dev/null
sched="$(db_query "SELECT id FROM loan_schedule WHERE loan_id=${loan_id} ORDER BY id DESC LIMIT 1;")"

assert_match "scheduled ok" "$(run_cobol "LSC_SCHEDULED|${sched}|||||${A}")" "SUCCESS\|LSC_SCHEDULED"
assert_match "installments created" "$(db_query "SELECT COUNT(*) FROM loan_installment WHERE schedule_id=${sched};")" "^12$"
assert_match "post ok" "$(run_cobol "LSC_POST|${sched}|1|500.00|||${A}")" "SUCCESS\|LSC_POST"
assert_match "installment paid" "$(db_query "SELECT status FROM loan_installment WHERE schedule_id=${sched} AND seq=1;")" "^PAID$"
assert_match "settle ok" "$(run_cobol "LSC_SETTLE|${sched}|||||${A}")" "SUCCESS\|LSC_SETTLE"
assert_match "schedule closed" "$(db_query "SELECT status FROM loan_schedule WHERE id=${sched};")" "^CLOSED$"
assert_match "audit rows" "$(db_query "SELECT COUNT(*) FROM loan_schedule_audit WHERE schedule_id=${sched};")" "^[1-9][0-9]*$"
assert_match "non-admin post refused" "$(run_cobol "LSC_POST|${sched}|2|500.00|||sender@test.com")" "ERROR\|FORBIDDEN"

db_exec "DELETE FROM loan_schedule_audit WHERE schedule_id=${sched};"
db_exec "DELETE FROM loan_installment WHERE schedule_id=${sched};"
db_exec "DELETE FROM loan_schedule WHERE id=${sched};"
db_exec "DELETE FROM loan_application WHERE id=${loan_id};"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
