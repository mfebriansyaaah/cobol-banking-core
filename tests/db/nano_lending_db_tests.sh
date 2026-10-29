#!/usr/bin/env bash
# Nano lending (Wave20) end-to-end DB tests via the COBOL binary.
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
db_reset_nano_lending

# Create a cost center.
create_out="$(run_cobol "NCL_CREATE|NCL-W20-1|NanoA|INDIVIDUAL|||admin@test.com")"
assert_match "NCL_CREATE ok" "$create_out" "SUCCESS\|NCL_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM nano_lending WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "NCL_CREATE|NCL-W20-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "NCL_GET ok" "$(run_cobol "NCL_GET|${id}|||||admin@test.com")" "SUCCESS\|NCL_GET\|${id}\|NCL-W20-1"
assert_match "NCL_LIST ok" "$(run_cobol "NCL_LIST|||50|0||admin@test.com")" "NCL-W20-1"

# Allocate.
assert_match "NCL_CALC ok" "$(run_cobol "NCL_CALC|${id}|||||admin@test.com")" "SUCCESS\|NCL_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM nano_lending WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "NCL_DELETE ok" "$(run_cobol "NCL_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|NCL_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM nano_lending WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "NCL_SUMMARY ok" "$(run_cobol "NCL_SUMMARY||||||admin@test.com")" "SUCCESS\|NCL_SUMMARY"
assert_match "NCL_AUDIT ok" "$(run_cobol "NCL_AUDIT|50|0||||admin@test.com")" "SUCCESS\|NCL_AUDIT"
assert_match "NCL_VALIDATE ok" "$(run_cobol "NCL_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|NCL_VALID"
assert_match "non-admin refused" "$(run_cobol "NCL_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0