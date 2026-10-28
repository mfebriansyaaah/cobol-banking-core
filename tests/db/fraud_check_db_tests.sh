#!/usr/bin/env bash
# Fraud check (Wave13) end-to-end DB tests via the COBOL binary.
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
db_reset_fraud_check

# Create a cost center.
create_out="$(run_cobol "FRDU_CREATE|FRDU-W13-1|EntityA|TRANSACTION|||admin@test.com")"
assert_match "FRDU_CREATE ok" "$create_out" "SUCCESS\|FRDU_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM fraud_check WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "FRDU_CREATE|FRDU-W13-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "FRDU_GET ok" "$(run_cobol "FRDU_GET|${id}|||||admin@test.com")" "SUCCESS\|FRDU_GET\|${id}\|FRDU-W13-1"
assert_match "FRDU_LIST ok" "$(run_cobol "FRDU_LIST|||50|0||admin@test.com")" "FRDU-W13-1"

# Allocate.
assert_match "FRDU_CALC ok" "$(run_cobol "FRDU_CALC|${id}|||||admin@test.com")" "SUCCESS\|FRDU_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM fraud_check WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "FRDU_DELETE ok" "$(run_cobol "FRDU_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|FRDU_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM fraud_check WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "FRDU_SUMMARY ok" "$(run_cobol "FRDU_SUMMARY||||||admin@test.com")" "SUCCESS\|FRDU_SUMMARY"
assert_match "FRDU_AUDIT ok" "$(run_cobol "FRDU_AUDIT|50|0||||admin@test.com")" "SUCCESS\|FRDU_AUDIT"
assert_match "FRDU_VALIDATE ok" "$(run_cobol "FRDU_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|FRDU_VALID"
assert_match "non-admin refused" "$(run_cobol "FRDU_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0