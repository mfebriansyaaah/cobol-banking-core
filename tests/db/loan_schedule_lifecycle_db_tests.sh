#!/usr/bin/env bash
# Loan-schedule lifecycle (PR-5b): approve/hold/release/close + audit.
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
db_exec "INSERT INTO loan_application (customer_email, principal, currency, term_months, interest_rate, status, created_by) VALUES ('lsc_life@test.com', 12000, 'USD', 12, 8.0000, 'DISBURSED', '${A}')"
loan_id="$(db_query "SELECT id FROM loan_application WHERE customer_email='lsc_life@test.com' ORDER BY id DESC LIMIT 1;")"
assert_match "loan fixture" "$loan_id" "^[0-9]+$"
create_out="$(run_cobol "LSC_CREATE|${loan_id}|12|8.0000|2026-01-01||${A}")"
assert_match "create ok" "$create_out" "SUCCESS\|LSC_CREATE"
sched="$(db_query "SELECT id FROM loan_schedule WHERE loan_id=${loan_id} ORDER BY id DESC LIMIT 1;")"
assert_match "schedule id" "$sched" "^[0-9]+$"
assert_match "initial draft" "$(db_query "SELECT status FROM loan_schedule WHERE id=${sched};")" "^DRAFT$"

assert_match "approve ok" "$(run_cobol "LSC_APPROVE|${sched}|approved||||${A}")" "SUCCESS\|LSC_APPROVE"
assert_match "active persisted" "$(db_query "SELECT status FROM loan_schedule WHERE id=${sched};")" "^ACTIVE$"
assert_match "hold ok" "$(run_cobol "LSC_HOLD|${sched}|risk review||||${A}")" "SUCCESS\|LSC_HOLD"
assert_match "hold persisted" "$(db_query "SELECT status FROM loan_schedule WHERE id=${sched};")" "^ON_HOLD$"
assert_match "release ok" "$(run_cobol "LSC_RELEASE|${sched}|cleared||||${A}")" "SUCCESS\|LSC_RELEASE"
assert_match "released persisted" "$(db_query "SELECT status FROM loan_schedule WHERE id=${sched};")" "^ACTIVE$"
assert_match "close ok" "$(run_cobol "LSC_CLOSE|${sched}|done||||${A}")" "SUCCESS\|LSC_CLOSE"
assert_match "closed persisted" "$(db_query "SELECT status FROM loan_schedule WHERE id=${sched};")" "^CLOSED$"
assert_match "audit rows" "$(db_query "SELECT COUNT(*) FROM loan_schedule_audit WHERE schedule_id=${sched};")" "^[4-9]$|^[1-9][0-9]+$"
assert_match "non-admin approve refused" "$(run_cobol "LSC_APPROVE|${sched}|x||||sender@test.com")" "ERROR\|FORBIDDEN"

db_exec "DELETE FROM loan_schedule_audit WHERE schedule_id=${sched};"
db_exec "DELETE FROM loan_installment WHERE schedule_id=${sched};"
db_exec "DELETE FROM loan_schedule WHERE id=${sched};"
db_exec "DELETE FROM loan_application WHERE id=${loan_id};"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
