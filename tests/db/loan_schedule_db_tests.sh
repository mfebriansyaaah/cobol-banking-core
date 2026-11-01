#!/usr/bin/env bash
# D1 (loan_schedule) end-to-end DB tests via COBOL binary.
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
db_reset_loan_schedule

# The suite owns its loan fixture: never depend on a seeded id.
db_exec "INSERT INTO loan_application (customer_email, principal, currency, term_months, interest_rate, status, created_by) VALUES ('d1@test.com', 10000, 'USD', 12, 10.0000, 'DISBURSED', 'admin@test.com')"
loan_id="$(db_query "SELECT id FROM loan_application WHERE customer_email='d1@test.com' ORDER BY id DESC LIMIT 1;")"
assert_match "loan fixture present" "$loan_id" "^[0-9]+$"

create_out="$(run_cobol "LSC_CREATE|${loan_id}|12|10.0000|2026-01-01||admin@test.com")"
assert_match "LSC_CREATE ok" "$create_out" "SUCCESS\|LSC_CREATE"

sched_id="$(db_query "SELECT id FROM loan_schedule WHERE loan_id=${loan_id} ORDER BY id DESC LIMIT 1;")"
assert_match "schedule id present" "$sched_id" "^[0-9]+$"

# SCHEDULED generates term_months installments
sched_out="$(run_cobol "LSC_SCHEDULED|${sched_id}|||||admin@test.com")"
assert_match "LSC_SCHEDULED ok" "$sched_out" "SUCCESS\|LSC_SCHEDULED"
assert_match "LSC_SCHEDULED decimal payment" "$sched_out" "^SUCCESS\|LSC_SCHEDULED\|[0-9]+\|[0-9]+\.[0-9]{2}\|[0-9]+\.[0-9]{2}$"
cnt="$(db_query "SELECT COUNT(*) FROM loan_installment WHERE schedule_id=${sched_id};")"
assert_match "installment count=12" "$cnt" "^12$"
st="$(db_query "SELECT status FROM loan_schedule WHERE id=${sched_id};")"
assert_match "status ACTIVE after schedule" "$st" "^ACTIVE$"

# Amortization invariants: principal must equal the loan, interest must be
# non-zero, and no installment may be 100x the monthly payment.
principal_sum="$(db_query "SELECT SUM(principal_due) FROM loan_installment WHERE schedule_id=${sched_id};")"
assert_match "principal total=10000" "$principal_sum" "^10000\.0000$"
interest_sum="$(db_query "SELECT SUM(interest_due) FROM loan_installment WHERE schedule_id=${sched_id};")"
assert_match "interest total positive" "$interest_sum" "^[1-9][0-9]*\.[0-9]{4}$"
max_total="$(db_query "SELECT MAX(total_due) FROM loan_installment WHERE schedule_id=${sched_id};")"
assert_match "no 100x installment" "$max_total" "^[0-9]{1,3}\.[0-9]{4}$"
bad_total="$(db_query "SELECT COUNT(*) FROM loan_installment WHERE schedule_id=${sched_id} AND total_due <> principal_due + interest_due;")"
assert_match "installment rows add up" "$bad_total" "^0$"

calc_out="$(run_cobol "LSC_CALC|10000|10|12||||admin@test.com")"
assert_match "LSC_CALC decimal output" "$calc_out" "^SUCCESS\|LSC_CALC\|[0-9]+\.[0-9]{2}$"

# POST marks installment seq=1 as PAID
post_out="$(run_cobol "LSC_POST|${sched_id}|1|500.00|||admin@test.com")"
assert_match "LSC_POST ok" "$post_out" "SUCCESS\|LSC_POST"
ps="$(db_query "SELECT status FROM loan_installment WHERE schedule_id=${sched_id} AND seq=1;")"
assert_match "installment paid" "$ps" "^PAID$"

# SETTLE closes schedule
settle_out="$(run_cobol "LSC_SETTLE|${sched_id}|||||admin@test.com")"
assert_match "LSC_SETTLE ok" "$settle_out" "SUCCESS\|LSC_SETTLE"
cs="$(db_query "SELECT status FROM loan_schedule WHERE id=${sched_id};")"
assert_match "status CLOSED after settle" "$cs" "^CLOSED$"

# audit rows recorded
ac="$(db_query "SELECT COUNT(*) FROM loan_schedule_audit WHERE schedule_id=${sched_id};")"
# audit may be >= 3 (CREATE, SCHEDULED, POST, SETTLE)
assert_match "audit rows present" "$ac" "^[1-9][0-9]*$"

# Zero-rate schedules must still use real decimals (not blank/raw numerics)
# and must amortize the principal exactly.
db_exec "INSERT INTO loan_application (customer_email, principal, currency, term_months, interest_rate, status, created_by) VALUES ('d1_zero@test.com', 1200, 'USD', 12, 0, 'DISBURSED', 'admin@test.com')"
zero_loan_id="$(db_query "SELECT id FROM loan_application WHERE customer_email='d1_zero@test.com' ORDER BY id DESC LIMIT 1;")"
zero_create="$(run_cobol "LSC_CREATE|${zero_loan_id}|12|0|2026-01-01||admin@test.com")"
assert_match "zero-rate LSC_CREATE ok" "$zero_create" "SUCCESS\|LSC_CREATE"
zero_sched_id="$(db_query "SELECT id FROM loan_schedule WHERE loan_id=${zero_loan_id} ORDER BY id DESC LIMIT 1;")"
zero_out="$(run_cobol "LSC_SCHEDULED|${zero_sched_id}|||||admin@test.com")"
assert_match "zero-rate decimal payment" "$zero_out" "^SUCCESS\|LSC_SCHEDULED\|[0-9]+\|100\.00\|0\.00$"
zero_principal="$(db_query "SELECT SUM(principal_due) FROM loan_installment WHERE schedule_id=${zero_sched_id};")"
assert_match "zero-rate principal total=1200" "$zero_principal" "^1200\.0000$"
zero_interest="$(db_query "SELECT SUM(interest_due) FROM loan_installment WHERE schedule_id=${zero_sched_id};")"
assert_match "zero-rate interest total=0" "$zero_interest" "^0\.0000$"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
