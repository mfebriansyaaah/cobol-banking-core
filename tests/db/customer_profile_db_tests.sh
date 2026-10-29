#!/usr/bin/env bash
# Customer profile (Wave15) end-to-end DB tests via the COBOL binary.
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
db_reset_customer_profile

# Create a cost center.
create_out="$(run_cobol "CSTMR_CREATE|CSTMR-W15-1|CustomerA|INDIVIDUAL|||admin@test.com")"
assert_match "CSTMR_CREATE ok" "$create_out" "SUCCESS\|CSTMR_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM customer_profile WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "CSTMR_CREATE|CSTMR-W15-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "CSTMR_GET ok" "$(run_cobol "CSTMR_GET|${id}|||||admin@test.com")" "SUCCESS\|CSTMR_GET\|${id}\|CSTMR-W15-1"
assert_match "CSTMR_LIST ok" "$(run_cobol "CSTMR_LIST|||50|0||admin@test.com")" "CSTMR-W15-1"

# Allocate.
assert_match "CSTMR_CALC ok" "$(run_cobol "CSTMR_CALC|${id}|||||admin@test.com")" "SUCCESS\|CSTMR_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM customer_profile WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "CSTMR_DELETE ok" "$(run_cobol "CSTMR_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|CSTMR_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM customer_profile WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "CSTMR_SUMMARY ok" "$(run_cobol "CSTMR_SUMMARY||||||admin@test.com")" "SUCCESS\|CSTMR_SUMMARY"
assert_match "CSTMR_AUDIT ok" "$(run_cobol "CSTMR_AUDIT|50|0||||admin@test.com")" "SUCCESS\|CSTMR_AUDIT"
assert_match "CSTMR_VALIDATE ok" "$(run_cobol "CSTMR_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|CSTMR_VALID"
assert_match "non-admin refused" "$(run_cobol "CSTMR_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0