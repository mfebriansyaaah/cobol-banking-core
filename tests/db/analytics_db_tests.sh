#!/usr/bin/env bash
# Analytics (Wave10) end-to-end DB tests via the COBOL binary.
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
db_reset_analytics

# Create a cost center.
create_out="$(run_cobol "ANL_CREATE|ANL-W10-1|EntityA|DESCRIPTIVE|||admin@test.com")"
assert_match "ANL_CREATE ok" "$create_out" "SUCCESS\|ANL_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM analytics WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "ANL_CREATE|ANL-W10-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "ANL_GET ok" "$(run_cobol "ANL_GET|${id}|||||admin@test.com")" "SUCCESS\|ANL_GET\|${id}\|ANL-W10-1"
assert_match "ANL_LIST ok" "$(run_cobol "ANL_LIST|||50|0||admin@test.com")" "ANL-W10-1"

# Allocate.
assert_match "ANL_CALC ok" "$(run_cobol "ANL_CALC|${id}|||||admin@test.com")" "SUCCESS\|ANL_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM analytics WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "ANL_DELETE ok" "$(run_cobol "ANL_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|ANL_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM analytics WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "ANL_SUMMARY ok" "$(run_cobol "ANL_SUMMARY||||||admin@test.com")" "SUCCESS\|ANL_SUMMARY"
assert_match "ANL_AUDIT ok" "$(run_cobol "ANL_AUDIT|50|0||||admin@test.com")" "SUCCESS\|ANL_AUDIT"
assert_match "ANL_VALIDATE ok" "$(run_cobol "ANL_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|ANL_VALID"
assert_match "non-admin refused" "$(run_cobol "ANL_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0