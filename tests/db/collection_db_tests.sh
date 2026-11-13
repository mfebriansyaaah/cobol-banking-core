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

# Concurrent pays against one case serialize on the guarded credit:
# exactly one wins, the loser sees INVALID_AMOUNT (not DB_ERROR), and
# recovery lands at exactly the overdue amount with a single activity.
inst_case="$(printf '%s' "$inst_out" | awk -F'|' '{print $3}')"
BIN="$PWD/cobol/bin/main_logic"
Y1="$(mktemp -d /tmp/cobol-test.XXXXXX)"; Y2="$(mktemp -d /tmp/cobol-test.XXXXXX)"
printf 'COL_PAY|%s|110.00||||admin@test.com\n' "$inst_case" >"$Y1/input.txt"
printf 'COL_PAY|%s|110.00||||admin@test.com\n' "$inst_case" >"$Y2/input.txt"
(cd "$Y1" && timeout 30s "$BIN" >/dev/null 2>&1) &
V1=$!
(cd "$Y2" && timeout 30s "$BIN" >/dev/null 2>&1) &
V2=$!
wait $V1; wait $V2
YA="$(tr -d ' \n' <"$Y1/output.txt")"; YB="$(tr -d ' \n' <"$Y2/output.txt")"
rm -rf "$Y1" "$Y2"
assert_match "exactly one pay winner" "$(printf '%s\n%s\n' "$YA" "$YB" | grep -c "SUCCESS|COL_PAY")" "^1$"
assert_match "race loser over-recovery refused" "$(printf '%s\n%s\n' "$YA" "$YB")" "ERROR\|INVALID_AMOUNT"
assert_match "recovery capped at overdue" "$(db_query "SELECT CONCAT(recovered_amount, '|', status) FROM collection_case WHERE id=${inst_case};")" "^110.0000\|CLOSED$"
assert_match "single payment recorded" "$(db_query "SELECT COUNT(*) FROM collection_activity WHERE case_id=${inst_case} AND activity_type='PAYMENT';")" "^1$"

# Keyed pay: same key replays the stored outcome instead of recording
# again; a different amount conflicts; concurrent keys serialize; doomed
# keys stay usable; stale keys are taken over.
db_exec "INSERT INTO loan_application (customer_email, principal, currency, term_months, interest_rate, status, created_by) VALUES ('d4key@test.com', 600, 'USD', 3, 5.0000, 'DISBURSED', 'admin@test.com')"
key_loan="$(db_query "SELECT id FROM loan_application WHERE customer_email='d4key@test.com' ORDER BY id DESC LIMIT 1;")"
db_exec "INSERT INTO loan_schedule (loan_id, term_months, interest_rate, start_date, status, created_by) VALUES (${key_loan}, 3, 5.0000, DATE_SUB(CURDATE(), INTERVAL 60 DAY), 'ACTIVE', 'admin@test.com')"
key_sched="$(db_query "SELECT id FROM loan_schedule WHERE loan_id=${key_loan} ORDER BY id DESC LIMIT 1;")"
db_exec "INSERT INTO loan_installment (schedule_id, seq, due_date, principal_due, interest_due, total_due, status, paid_amount) VALUES (${key_sched}, 1, DATE_SUB(CURDATE(), INTERVAL 30 DAY), 200, 20, 220, 'DUE', 0)"
key_open="$(run_cobol "COL_OPEN|COL-D4-K|${key_loan}||HIGH||admin@test.com")"
key_case="$(printf '%s' "$key_open" | awk -F'|' '{print $3}')"
assert_match "keyed pay ok" "$(run_cobol "COL_PAY|${key_case}|80.00|||K-P1|admin@test.com")" "SUCCESS\|COL_PAY\|80.00\|140.0000"
assert_match "keyed pay replay ok" "$(run_cobol "COL_PAY|${key_case}|80.00|||K-P1|admin@test.com")" "SUCCESS\|COL_PAY\|80.0000\|140.0000"
assert_match "replay recorded once" "$(db_query "SELECT COUNT(*) FROM collection_activity WHERE case_id=${key_case} AND activity_type='PAYMENT';")" "^1$"
assert_match "pay request recorded DONE" "$(db_query "SELECT status FROM collection_pay_request WHERE case_id=${key_case} AND idempotency_key='K-P1';")" "^DONE$"
assert_match "mirror recorded DONE" "$(db_query "SELECT CONCAT(status, '|', amount) FROM idempotency_request WHERE scope='COL_PAY' AND entity_ref='${key_case}' AND idem_key='K-P1';")" "^DONE|80.0000$"
db_exec "UPDATE collection_pay_request SET amount = 1.00 WHERE case_id=${key_case} AND idempotency_key='K-P1';"
assert_match "pay changed amount conflicts" "$(run_cobol "COL_PAY|${key_case}|80.00|||K-P1|admin@test.com")" "ERROR\|IDEMPOTENCY_CONFLICT"
db_exec "UPDATE collection_pay_request SET amount = 80.00 WHERE case_id=${key_case} AND idempotency_key='K-P1';"
Q1="$(mktemp -d /tmp/cobol-test.XXXXXX)"; Q2="$(mktemp -d /tmp/cobol-test.XXXXXX)"
printf 'COL_PAY|%s|60.00|||K-PRACE|admin@test.com\n' "$key_case" >"$Q1/input.txt"
printf 'COL_PAY|%s|60.00|||K-PRACE|admin@test.com\n' "$key_case" >"$Q2/input.txt"
(cd "$Q1" && timeout 30s "$BIN" >/dev/null 2>&1) &
E1=$!
(cd "$Q2" && timeout 30s "$BIN" >/dev/null 2>&1) &
E2=$!
wait $E1; wait $E2
EA="$(tr -d ' \n' <"$Q1/output.txt")"; EB="$(tr -d ' \n' <"$Q2/output.txt")"
rm -rf "$Q1" "$Q2"
assert_match "exactly one keyed winner" "$(printf '%s\n%s\n' "$EA" "$EB" | grep -c "SUCCESS|COL_PAY")" "^1$"
assert_match "keyed loser in progress" "$(printf '%s\n%s\n' "$EA" "$EB")" "ERROR\|PAY_IN_PROGRESS"
assert_match "keyed retry converges" "$(run_cobol "COL_PAY|${key_case}|60.00|||K-PRACE|admin@test.com")" "SUCCESS\|COL_PAY\|60.0000\|80.0000"
assert_match "mirror race converges DONE" "$(db_query "SELECT CONCAT(status, '|', amount) FROM idempotency_request WHERE scope='COL_PAY' AND entity_ref='${key_case}' AND idem_key='K-PRACE';")" "^DONE|60.0000$"
db_exec "INSERT INTO collection_pay_request (case_id, idempotency_key, amount, status, created_at, updated_at) VALUES (${key_case},'K-TAKE',10.00,'PENDING',DATE_SUB(NOW(),INTERVAL 10 MINUTE),DATE_SUB(NOW(),INTERVAL 10 MINUTE));"
assert_match "pay takeover succeeds" "$(run_cobol "COL_PAY|${key_case}|10.00|||K-TAKE|admin@test.com")" "SUCCESS\|COL_PAY\|10.00\|70.0000"
assert_match "taken over and done" "$(db_query "SELECT status FROM collection_pay_request WHERE case_id=${key_case} AND idempotency_key='K-TAKE';")" "^DONE$"
assert_match "mirror taken over and done" "$(db_query "SELECT CONCAT(status, '|', amount) FROM idempotency_request WHERE scope='COL_PAY' AND entity_ref='${key_case}' AND idem_key='K-TAKE';")" "^DONE|10.0000$"
run_cobol "COL_PAY|${key_case}|70.00||||admin@test.com" >/dev/null
assert_match "keyed pay on closed refused" "$(run_cobol "COL_PAY|${key_case}|10.00|||K-DOOM|admin@test.com")" "ERROR\|INVALID_STATUS"
assert_match "doomed key not blocked" "$(run_cobol "COL_PAY|${key_case}|10.00|||K-DOOM|admin@test.com")" "ERROR\|INVALID_STATUS"
assert_match "no pay request residue" "$(db_query "SELECT COUNT(*) FROM collection_pay_request WHERE case_id=${key_case} AND idempotency_key='K-DOOM';")" "^0$"
assert_match "no mirror residue" "$(db_query "SELECT COUNT(*) FROM idempotency_request WHERE scope='COL_PAY' AND entity_ref='${key_case}' AND idem_key='K-DOOM';")" "^0$"

# Summary, aging, history and audit.
sum="$(run_cobol "COL_SUMMARY||||||admin@test.com")"
assert_match "COL_SUMMARY ok" "$sum" "SUCCESS\|COL_SUMMARY\|3\|0\|0\|0\|3\|"
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
