#!/usr/bin/env bash
# Write off (Wave7) end-to-end DB tests via the COBOL binary.
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
db_reset_write_off

# Create a cost center.
create_out="$(run_cobol "WOF_CREATE|WOF-W7-1|AccountA|BAD_DEBT|||admin@test.com")"
assert_match "WOF_CREATE ok" "$create_out" "SUCCESS\|WOF_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM write_off WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "WOF_CREATE|WOF-W7-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "WOF_GET ok" "$(run_cobol "WOF_GET|${id}|||||admin@test.com")" "SUCCESS\|WOF_GET\|${id}\|WOF-W7-1"
assert_match "WOF_LIST ok" "$(run_cobol "WOF_LIST|||50|0||admin@test.com")" "WOF-W7-1"

# Allocate.
assert_match "WOF_CALC ok" "$(run_cobol "WOF_CALC|${id}|||||admin@test.com")" "SUCCESS\|WOF_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM write_off WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "WOF_DELETE ok" "$(run_cobol "WOF_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|WOF_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM write_off WHERE id=${id};")" "^WRITTEN_OFF$"

# Summary and audit.
assert_match "WOF_SUMMARY ok" "$(run_cobol "WOF_SUMMARY||||||admin@test.com")" "SUCCESS\|WOF_SUMMARY"
assert_match "WOF_AUDIT ok" "$(run_cobol "WOF_AUDIT|50|0||||admin@test.com")" "SUCCESS\|WOF_AUDIT"
assert_match "WOF_VALIDATE ok" "$(run_cobol "WOF_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|WOF_VALID"
assert_match "non-admin refused" "$(run_cobol "WOF_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0