#!/usr/bin/env bash
# D1 (loan_schedule) end-to-end DB tests via COBOL binary.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/tests/lib/db.sh"
# shellcheck disable=SC1091
. "$ROOT/tests/lib/cobol.sh"
if ! db_available; then echo "SKIP: DB unavailable"; exit 0; fi

T_PASS=0; T_FAIL=0; T_TOTAL=0
# shellcheck disable=SC1091
. "$ROOT/tests/lib/assert.sh"

db_seed
db_reset_loan_schedule

# Create a schedule (loan_id=53 exists in seed)
create_out="$(run_cobol "LSC_CREATE|53|12|10.0000|2026-01-01||admin@test.com")"
assert_match "LSC_CREATE ok" "$create_out" "SUCCESS\|LSC_CREATE"

sched_id="$(db_query "SELECT id FROM loan_schedule WHERE loan_id=53 ORDER BY id DESC LIMIT 1;")"
assert_match "schedule id present" "$sched_id" "^[0-9]+$"

# SCHEDULED generates term_months installments
sched_out="$(run_cobol "LSC_SCHEDULED|${sched_id}|||||admin@test.com")"
assert_match "LSC_SCHEDULED ok" "$sched_out" "SUCCESS\|LSC_SCHEDULED"
cnt="$(db_query "SELECT COUNT(*) FROM loan_installment WHERE schedule_id=${sched_id};")"
assert_match "installment count=12" "$cnt" "^12$"
st="$(db_query "SELECT status FROM loan_schedule WHERE id=${sched_id};")"
assert_match "status ACTIVE after schedule" "$st" "^ACTIVE$"

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

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
