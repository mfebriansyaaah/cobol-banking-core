#!/usr/bin/env bash
# Session management (Wave8) end-to-end DB tests via the COBOL binary.
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
db_reset_session_management

# Create a cost center.
create_out="$(run_cobol "SSM_CREATE|SSM-W8-1|UserA|WEB|||admin@test.com")"
assert_match "SSM_CREATE ok" "$create_out" "SUCCESS\|SSM_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM session_management WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "SSM_CREATE|SSM-W8-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "SSM_GET ok" "$(run_cobol "SSM_GET|${id}|||||admin@test.com")" "SUCCESS\|SSM_GET\|${id}\|SSM-W8-1"
assert_match "SSM_LIST ok" "$(run_cobol "SSM_LIST|||50|0||admin@test.com")" "SSM-W8-1"

# Allocate.
assert_match "SSM_CALC ok" "$(run_cobol "SSM_CALC|${id}|||||admin@test.com")" "SUCCESS\|SSM_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM session_management WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "SSM_DELETE ok" "$(run_cobol "SSM_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|SSM_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM session_management WHERE id=${id};")" "^EXPIRED$"

# Summary and audit.
assert_match "SSM_SUMMARY ok" "$(run_cobol "SSM_SUMMARY||||||admin@test.com")" "SUCCESS\|SSM_SUMMARY"
assert_match "SSM_AUDIT ok" "$(run_cobol "SSM_AUDIT|50|0||||admin@test.com")" "SUCCESS\|SSM_AUDIT"
assert_match "SSM_VALIDATE ok" "$(run_cobol "SSM_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|SSM_VALID"
assert_match "non-admin refused" "$(run_cobol "SSM_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0