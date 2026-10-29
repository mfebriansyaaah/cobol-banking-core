#!/usr/bin/env bash
# Filing (Wave17) end-to-end DB tests via the COBOL binary.
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
db_reset_filing

# Create a cost center.
create_out="$(run_cobol "FIL2_CREATE|FIL2-W17-1|FilingA|REGULATORY|||admin@test.com")"
assert_match "FIL2_CREATE ok" "$create_out" "SUCCESS\|FIL2_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM filing WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "FIL2_CREATE|FIL2-W17-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "FIL2_GET ok" "$(run_cobol "FIL2_GET|${id}|||||admin@test.com")" "SUCCESS\|FIL2_GET\|${id}\|FIL2-W17-1"
assert_match "FIL2_LIST ok" "$(run_cobol "FIL2_LIST|||50|0||admin@test.com")" "FIL2-W17-1"

# Allocate.
assert_match "FIL2_CALC ok" "$(run_cobol "FIL2_CALC|${id}|||||admin@test.com")" "SUCCESS\|FIL2_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM filing WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "FIL2_DELETE ok" "$(run_cobol "FIL2_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|FIL2_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM filing WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "FIL2_SUMMARY ok" "$(run_cobol "FIL2_SUMMARY||||||admin@test.com")" "SUCCESS\|FIL2_SUMMARY"
assert_match "FIL2_AUDIT ok" "$(run_cobol "FIL2_AUDIT|50|0||||admin@test.com")" "SUCCESS\|FIL2_AUDIT"
assert_match "FIL2_VALIDATE ok" "$(run_cobol "FIL2_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|FIL2_VALID"
assert_match "non-admin refused" "$(run_cobol "FIL2_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0