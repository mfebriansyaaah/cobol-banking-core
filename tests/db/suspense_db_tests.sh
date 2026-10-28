#!/usr/bin/env bash
# Suspense (Wave13) end-to-end DB tests via the COBOL binary.
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
db_reset_suspense

# Create a cost center.
create_out="$(run_cobol "SUS_CREATE|SUS-W13-1|AccountA|UNMATCHED|||admin@test.com")"
assert_match "SUS_CREATE ok" "$create_out" "SUCCESS\|SUS_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM suspense WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "SUS_CREATE|SUS-W13-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "SUS_GET ok" "$(run_cobol "SUS_GET|${id}|||||admin@test.com")" "SUCCESS\|SUS_GET\|${id}\|SUS-W13-1"
assert_match "SUS_LIST ok" "$(run_cobol "SUS_LIST|||50|0||admin@test.com")" "SUS-W13-1"

# Allocate.
assert_match "SUS_CALC ok" "$(run_cobol "SUS_CALC|${id}|||||admin@test.com")" "SUCCESS\|SUS_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM suspense WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "SUS_DELETE ok" "$(run_cobol "SUS_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|SUS_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM suspense WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "SUS_SUMMARY ok" "$(run_cobol "SUS_SUMMARY||||||admin@test.com")" "SUCCESS\|SUS_SUMMARY"
assert_match "SUS_AUDIT ok" "$(run_cobol "SUS_AUDIT|50|0||||admin@test.com")" "SUCCESS\|SUS_AUDIT"
assert_match "SUS_VALIDATE ok" "$(run_cobol "SUS_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|SUS_VALID"
assert_match "non-admin refused" "$(run_cobol "SUS_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0