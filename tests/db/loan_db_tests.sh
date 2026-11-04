#!/usr/bin/env bash
# loan (Wave2) end-to-end DB tests via the COBOL binary.
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
db_reset_loan

# Create a cost center.
create_out="$(run_cobol "LOAN_CREATE|LSC-W2-1|John Doe|MORTGAGE|||admin@test.com")"
assert_match "LOAN_CREATE ok" "$create_out" "SUCCESS\|LOAN_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM loan WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "LOAN_CREATE|LSC-W2-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "LOAN_GET ok" "$(run_cobol "LOAN_GET|${id}|||||admin@test.com")" "SUCCESS\|LOAN_GET\|${id}\|LSC-W2-1"
assert_match "LOAN_LIST ok" "$(run_cobol "LOAN_LIST|||50|0||admin@test.com")" "LSC-W2-1"

# Allocate.
assert_match "LOAN_CALC ok" "$(run_cobol "LOAN_CALC|${id}|||||admin@test.com")" "SUCCESS\|LOAN_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT disbursed_amount FROM loan WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "LOAN_DELETE ok" "$(run_cobol "LOAN_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|LOAN_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM loan WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "LOAN_SUMMARY ok" "$(run_cobol "LOAN_SUMMARY||||||admin@test.com")" "SUCCESS\|LOAN_SUMMARY"
assert_match "LOAN_AUDIT ok" "$(run_cobol "LOAN_AUDIT|50|0||||admin@test.com")" "SUCCESS\|LOAN_AUDIT"
assert_match "LOAN_VALIDATE ok" "$(run_cobol "LOAN_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|LOAN_VALID"
assert_match "non-admin refused" "$(run_cobol "LOAN_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

# Loan lifecycle (APPLY -> APPROVE -> DISBURSE -> REPAY, plus REJECT path).
apply_out="$(run_cobol "LOAN_APPLY|borrower@test.com|10000.00|USD|12|5.5|admin@test.com")"
assert_match "LOAN_APPLY ok" "$apply_out" "SUCCESS\|LOAN_APPLY\|[0-9]+"
app_id="$(printf '%s' "$apply_out" | awk -F'|' '{print $3}')"
assert_match "application pending" "$(db_query "SELECT status FROM loan_application WHERE id=${app_id};")" "^PENDING$"
assert_match "LOAN_APPROVE ok" "$(run_cobol "LOAN_APPROVE|${app_id}|5.5|looks-good|||admin@test.com")" "SUCCESS\|LOAN_APPROVE"
assert_match "application approved" "$(db_query "SELECT status FROM loan_application WHERE id=${app_id};")" "^APPROVED$"
assert_match "LOAN_DISBURSE ok" "$(run_cobol "LOAN_DISBURSE|${app_id}|||||admin@test.com")" "SUCCESS\|LOAN_DISBURSE"
assert_match "application disbursed" "$(db_query "SELECT status FROM loan_application WHERE id=${app_id};")" "^DISBURSED$"
assert_match "LOAN_REPAY ok" "$(run_cobol "LOAN_REPAY|${app_id}|500.00||||admin@test.com")" "SUCCESS\|LOAN_REPAY"
assert_match "repayment recorded" "$(db_query "SELECT COUNT(*) FROM loan_repayment WHERE loan_id=${app_id};")" "^1$"
apply2_out="$(run_cobol "LOAN_APPLY|rejectme@test.com|2000.00|USD|6|4.0|admin@test.com")"
app2_id="$(printf '%s' "$apply2_out" | awk -F'|' '{print $3}')"
assert_match "LOAN_REJECT ok" "$(run_cobol "LOAN_REJECT|${app2_id}|not-eligible||||admin@test.com")" "SUCCESS\|LOAN_REJECT"
assert_match "application rejected" "$(db_query "SELECT status FROM loan_application WHERE id=${app2_id};")" "^REJECTED$"
assert_match "approve missing id" "$(run_cobol "LOAN_APPROVE||||||admin@test.com")" "ERROR\|INVALID_INPUT"
assert_match "non-admin apply refused" "$(run_cobol "LOAN_APPLY|borrower@test.com|10000.00|USD|12|5.5|sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0