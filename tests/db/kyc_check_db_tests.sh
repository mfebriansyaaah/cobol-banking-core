#!/usr/bin/env bash
# KYC check (Wave13) end-to-end DB tests via the COBOL binary.
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
db_reset_kyc_check

# Create a cost center.
create_out="$(run_cobol "KYCC_CREATE|KYCC-W13-1|CustomerA|PERIODIC|||admin@test.com")"
assert_match "KYCC_CREATE ok" "$create_out" "SUCCESS\|KYCC_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM kyc_check WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "KYCC_CREATE|KYCC-W13-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "KYCC_GET ok" "$(run_cobol "KYCC_GET|${id}|||||admin@test.com")" "SUCCESS\|KYCC_GET\|${id}\|KYCC-W13-1"
assert_match "KYCC_LIST ok" "$(run_cobol "KYCC_LIST|||50|0||admin@test.com")" "KYCC-W13-1"

# Allocate.
assert_match "KYCC_CALC ok" "$(run_cobol "KYCC_CALC|${id}|||||admin@test.com")" "SUCCESS\|KYCC_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM kyc_check WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "KYCC_DELETE ok" "$(run_cobol "KYCC_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|KYCC_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM kyc_check WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "KYCC_SUMMARY ok" "$(run_cobol "KYCC_SUMMARY||||||admin@test.com")" "SUCCESS\|KYCC_SUMMARY"
assert_match "KYCC_AUDIT ok" "$(run_cobol "KYCC_AUDIT|50|0||||admin@test.com")" "SUCCESS\|KYCC_AUDIT"
assert_match "KYCC_VALIDATE ok" "$(run_cobol "KYCC_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|KYCC_VALID"
assert_match "non-admin refused" "$(run_cobol "KYCC_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0