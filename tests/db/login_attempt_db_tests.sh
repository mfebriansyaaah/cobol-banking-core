#!/usr/bin/env bash
# Login attempt (Wave8) end-to-end DB tests via the COBOL binary.
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
db_reset_login_attempt

# Create a cost center.
create_out="$(run_cobol "LGA_CREATE|LGA-W8-1|UserA|FAILED|||admin@test.com")"
assert_match "LGA_CREATE ok" "$create_out" "SUCCESS\|LGA_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM login_attempt WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "LGA_CREATE|LGA-W8-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "LGA_GET ok" "$(run_cobol "LGA_GET|${id}|||||admin@test.com")" "SUCCESS\|LGA_GET\|${id}\|LGA-W8-1"
assert_match "LGA_LIST ok" "$(run_cobol "LGA_LIST|||50|0||admin@test.com")" "LGA-W8-1"

# Allocate.
assert_match "LGA_CALC ok" "$(run_cobol "LGA_CALC|${id}|||||admin@test.com")" "SUCCESS\|LGA_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM login_attempt WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "LGA_DELETE ok" "$(run_cobol "LGA_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|LGA_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM login_attempt WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "LGA_SUMMARY ok" "$(run_cobol "LGA_SUMMARY||||||admin@test.com")" "SUCCESS\|LGA_SUMMARY"
assert_match "LGA_AUDIT ok" "$(run_cobol "LGA_AUDIT|50|0||||admin@test.com")" "SUCCESS\|LGA_AUDIT"
assert_match "LGA_VALIDATE ok" "$(run_cobol "LGA_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|LGA_VALID"
assert_match "non-admin refused" "$(run_cobol "LGA_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0