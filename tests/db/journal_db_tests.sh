#!/usr/bin/env bash
# Journal (Wave13) end-to-end DB tests via the COBOL binary.
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
db_reset_journal

# Create a cost center.
create_out="$(run_cobol "JRN_CREATE|JRN-W13-1|AccountA|ENTRY|||admin@test.com")"
assert_match "JRN_CREATE ok" "$create_out" "SUCCESS\|JRN_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM journal WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "JRN_CREATE|JRN-W13-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "JRN_GET ok" "$(run_cobol "JRN_GET|${id}|||||admin@test.com")" "SUCCESS\|JRN_GET\|${id}\|JRN-W13-1"
assert_match "JRN_LIST ok" "$(run_cobol "JRN_LIST|||50|0||admin@test.com")" "JRN-W13-1"

# Allocate.
assert_match "JRN_CALC ok" "$(run_cobol "JRN_CALC|${id}|||||admin@test.com")" "SUCCESS\|JRN_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM journal WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "JRN_DELETE ok" "$(run_cobol "JRN_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|JRN_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM journal WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "JRN_SUMMARY ok" "$(run_cobol "JRN_SUMMARY||||||admin@test.com")" "SUCCESS\|JRN_SUMMARY"
assert_match "JRN_AUDIT ok" "$(run_cobol "JRN_AUDIT|50|0||||admin@test.com")" "SUCCESS\|JRN_AUDIT"
assert_match "JRN_VALIDATE ok" "$(run_cobol "JRN_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|JRN_VALID"
assert_match "non-admin refused" "$(run_cobol "JRN_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0