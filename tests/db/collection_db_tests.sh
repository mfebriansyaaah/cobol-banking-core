#!/usr/bin/env bash
# D4 (collections) end-to-end DB tests via the COBOL binary.
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
db_reset_collection

# Fixture: a disbursed loan with two overdue installments (210 total) and one
# future installment, plus a clean loan for the no-overdue path.
db_exec "INSERT INTO loan_application (customer_email, principal, currency, term_months, interest_rate, status, created_by) VALUES ('d4@test.com', 1200, 'USD', 6, 5.0000, 'DISBURSED', 'admin@test.com')"
loan_id="$(db_query "SELECT id FROM loan_application WHERE customer_email='d4@test.com' ORDER BY id DESC LIMIT 1;")"
db_exec "INSERT INTO loan_schedule (loan_id, term_months, interest_rate, start_date, status, created_by) VALUES (${loan_id}, 6, 5.0000, DATE_SUB(CURDATE(), INTERVAL 90 DAY), 'ACTIVE', 'admin@test.com')"
sched_id="$(db_query "SELECT id FROM loan_schedule WHERE loan_id=${loan_id} ORDER BY id DESC LIMIT 1;")"
db_exec "INSERT INTO loan_installment (schedule_id, seq, due_date, principal_due, interest_due, total_due, status, paid_amount) VALUES (${sched_id}, 1, DATE_SUB(CURDATE(), INTERVAL 70 DAY), 100, 10, 110, 'DUE', 0), (${sched_id}, 2, DATE_SUB(CURDATE(), INTERVAL 40 DAY), 100, 10, 110, 'DUE', 10), (${sched_id}, 3, DATE_ADD(CURDATE(), INTERVAL 10 DAY), 100, 10, 110, 'PENDING', 0)"
inst1="$(db_query "SELECT id FROM loan_installment WHERE schedule_id=${sched_id} AND seq=1;")"

db_exec "INSERT INTO loan_application (customer_email, principal, currency, term_months, interest_rate, status, created_by) VALUES ('d4clear@test.com', 500, 'USD', 3, 5.0000, 'DISBURSED', 'admin@test.com')"
clear_loan="$(db_query "SELECT id FROM loan_application WHERE customer_email='d4clear@test.com' ORDER BY id DESC LIMIT 1;")"
db_exec "INSERT INTO loan_schedule (loan_id, term_months, interest_rate, start_date, status, created_by) VALUES (${clear_loan}, 3, 5.0000, CURDATE(), 'ACTIVE', 'admin@test.com')"
clear_sched="$(db_query "SELECT id FROM loan_schedule WHERE loan_id=${clear_loan} ORDER BY id DESC LIMIT 1;")"
db_exec "INSERT INTO loan_installment (schedule_id, seq, due_date, principal_due, interest_due, total_due, status) VALUES (${clear_sched}, 1, DATE_ADD(CURDATE(), INTERVAL 20 DAY), 100, 5, 105, 'PENDING')"

# Validation previews the overdue amount, currency and oldest due date.
val_out="$(run_cobol "COL_VALIDATE|${loan_id}|||||admin@test.com")"
assert_match "COL_VALIDATE ok" "$val_out" "SUCCESS\|COL_VALID\|210.0000\|USD\|"
assert_match "COL_VALIDATE no overdue" "$(run_cobol "COL_VALIDATE|${clear_loan}|||||admin@test.com")" "ERROR\|NO_OVERDUE"
assert_match "COL_VALIDATE missing loan" "$(run_cobol "COL_VALIDATE|999999|||||admin@test.com")" "ERROR\|NOT_FOUND"

# Open a case for the whole loan.
open_out="$(run_cobol "COL_OPEN|COL-D4-1|${loan_id}||HIGH||admin@test.com")"
assert_match "COL_OPEN ok" "$open_out" "SUCCESS\|COL_OPEN\|[0-9]+\|210.0000"
case_id="$(printf '%s' "$open_out" | awk -F'|' '{print $3}')"
got="$(db_query "SELECT CONCAT(customer_email, '|', currency, '|', overdue_amount, '|', priority, '|', status, '|', oldest_due_date) FROM collection_case WHERE id=${case_id};")"
assert_match "case snapshot stored" "$got" "^d4@test.com\|USD\|210.0000\|HIGH\|OPEN\|"
assert_match "duplicate case ref" "$(run_cobol "COL_OPEN|COL-D4-1|${loan_id}||NORMAL||admin@test.com")" "ERROR\|DUPLICATE"
assert_match "non-admin refused" "$(run_cobol "COL_GET|${case_id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

# Read paths.
assert_match "COL_GET ok" "$(run_cobol "COL_GET|${case_id}|||||admin@test.com")" "SUCCESS\|COL_GET\|${case_id}\|COL-D4-1\|"
assert_match "COL_LIST ok" "$(run_cobol "COL_LIST|OPEN||50|0||admin@test.com")" "COL-D4-1"
assert_match "COL_LIST filters status" "$(run_cobol "COL_LIST|CLOSED||50|0||admin@test.com")" "SUCCESS\|COL_LIST\|0"

# Assignment, contact and promise.
assert_match "COL_ASSIGN ok" "$(run_cobol "COL_ASSIGN|${case_id}|admin@test.com||||admin@test.com")" "SUCCESS\|COL_ASSIGNED"
assert_match "assigned persisted" "$(db_query "SELECT assigned_to FROM collection_case WHERE id=${case_id};")" "^admin@test.com$"
assert_match "COL_CONTACT ok" "$(run_cobol "COL_CONTACT|${case_id}|CALL|Left a message|||admin@test.com")" "SUCCESS\|COL_CONTACT"
promise_date="$(db_query "SELECT DATE_ADD(CURDATE(), INTERVAL 3 DAY);")"
assert_match "COL_PROMISE ok" "$(run_cobol "COL_PROMISE|${case_id}|${promise_date}|100.00|||admin@test.com")" "SUCCESS\|COL_PROMISE\|${promise_date}\|100.00"
assert_match "promise persisted" "$(db_query "SELECT CONCAT(status, '|', promise_amount) FROM collection_case WHERE id=${case_id};")" "^PROMISE\|100.0000$"
assert_match "past promise rejected" "$(run_cobol "COL_PROMISE|${case_id}|2020-01-01|10.00|||admin@test.com")" "ERROR\|INVALID_DATE"
assert_match "promise above outstanding" "$(run_cobol "COL_PROMISE|${case_id}|${promise_date}|999.00|||admin@test.com")" "ERROR\|INVALID_AMOUNT"

# Recovery: partial payment reopens the case, escalation bumps the level.
assert_match "COL_PAY partial" "$(run_cobol "COL_PAY|${case_id}|50.00||||admin@test.com")" "SUCCESS\|COL_PAY\|50.00\|160.0000"
assert_match "recovery persisted" "$(db_query "SELECT CONCAT(recovered_amount, '|', status) FROM collection_case WHERE id=${case_id};")" "^50.0000\|OPEN$"
assert_match "over-recovery rejected" "$(run_cobol "COL_PAY|${case_id}|999.00||||admin@test.com")" "ERROR\|INVALID_AMOUNT"
assert_match "COL_ESCALATE ok" "$(run_cobol "COL_ESCALATE|${case_id}|Second notice||||admin@test.com")" "SUCCESS\|COL_ESCALATE\|1"
assert_match "escalation persisted" "$(db_query "SELECT CONCAT(status, '|', escalation_level) FROM collection_case WHERE id=${case_id};")" "^ESCALATED\|1$"

# Close and reopen.
assert_match "COL_CLOSE ok" "$(run_cobol "COL_CLOSE|${case_id}|SETTLED||||admin@test.com")" "SUCCESS\|COL_CLOSE"
assert_match "closed persisted" "$(db_query "SELECT status FROM collection_case WHERE id=${case_id};")" "^CLOSED$"
assert_match "COL_REOPEN ok" "$(run_cobol "COL_REOPEN|${case_id}|CUSTOMER_DISPUTE||||admin@test.com")" "SUCCESS\|COL_REOPEN"
assert_match "reopened persisted" "$(db_query "SELECT CONCAT(status, '|', COALESCE(closed_at, 'NULL')) FROM collection_case WHERE id=${case_id};")" "^OPEN\|NULL$"

# Full recovery closes the case automatically.
assert_match "COL_PAY in full" "$(run_cobol "COL_PAY|${case_id}|160.00||||admin@test.com")" "SUCCESS\|COL_PAY\|160.00\|0.0000"
assert_match "paid in full closed" "$(db_query "SELECT CONCAT(status, '|', resolution) FROM collection_case WHERE id=${case_id};")" "^CLOSED\|PAID_IN_FULL$"

# A case can target a single installment instead of all overdue rows.
inst_out="$(run_cobol "COL_OPEN|COL-D4-2|${loan_id}|${inst1}|||admin@test.com")"
assert_match "installment case overdue" "$inst_out" "SUCCESS\|COL_OPEN\|[0-9]+\|110.0000"

# Summary, aging, history and audit.
sum="$(run_cobol "COL_SUMMARY||||||admin@test.com")"
assert_match "COL_SUMMARY ok" "$sum" "SUCCESS\|COL_SUMMARY\|2\|1\|0\|0\|1\|"
aging="$(run_cobol "COL_AGING||||||admin@test.com")"
assert_match "COL_AGING buckets" "$aging" "SUCCESS\|COL_AGING\|[0-9]+:[0-9.]+;.*;.*;.*;"
hist="$(run_cobol "COL_HISTORY|${case_id}|50|0|||admin@test.com")"
assert_match "history has payment" "$hist" "PAYMENT"
assert_match "history has escalation" "$hist" "ESCALATION"
assert_match "COL_AUDIT ok" "$(run_cobol "COL_AUDIT|${case_id}|50|0|||admin@test.com")" "SUCCESS\|COL_AUDIT\|"
ac="$(db_query "SELECT COUNT(*) FROM collection_audit WHERE case_id=${case_id};")"
assert_match "audit rows recorded" "$ac" "^[1-9][0-9]*$"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
