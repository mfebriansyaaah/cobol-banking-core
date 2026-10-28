#!/usr/bin/env bash
# Alerting (Wave11) end-to-end DB tests via the COBOL binary.
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
db_reset_alerting

# Create a cost center.
create_out="$(run_cobol "ALR_CREATE|ALR-W11-1|TargetA|THRESHOLD|||admin@test.com")"
assert_match "ALR_CREATE ok" "$create_out" "SUCCESS\|ALR_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM alerting WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "ALR_CREATE|ALR-W11-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "ALR_GET ok" "$(run_cobol "ALR_GET|${id}|||||admin@test.com")" "SUCCESS\|ALR_GET\|${id}\|ALR-W11-1"
assert_match "ALR_LIST ok" "$(run_cobol "ALR_LIST|||50|0||admin@test.com")" "ALR-W11-1"

# Allocate.
assert_match "ALR_CALC ok" "$(run_cobol "ALR_CALC|${id}|||||admin@test.com")" "SUCCESS\|ALR_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM alerting WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "ALR_DELETE ok" "$(run_cobol "ALR_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|ALR_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM alerting WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "ALR_SUMMARY ok" "$(run_cobol "ALR_SUMMARY||||||admin@test.com")" "SUCCESS\|ALR_SUMMARY"
assert_match "ALR_AUDIT ok" "$(run_cobol "ALR_AUDIT|50|0||||admin@test.com")" "SUCCESS\|ALR_AUDIT"
assert_match "ALR_VALIDATE ok" "$(run_cobol "ALR_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|ALR_VALID"
assert_match "non-admin refused" "$(run_cobol "ALR_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0