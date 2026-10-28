#!/usr/bin/env bash
# GL master (Wave13) end-to-end DB tests via the COBOL binary.
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
db_reset_gl_master

# Create a cost center.
create_out="$(run_cobol "GLM_CREATE|GLM-W13-1|AccountA|ASSET|||admin@test.com")"
assert_match "GLM_CREATE ok" "$create_out" "SUCCESS\|GLM_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM gl_master WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "GLM_CREATE|GLM-W13-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "GLM_GET ok" "$(run_cobol "GLM_GET|${id}|||||admin@test.com")" "SUCCESS\|GLM_GET\|${id}\|GLM-W13-1"
assert_match "GLM_LIST ok" "$(run_cobol "GLM_LIST|||50|0||admin@test.com")" "GLM-W13-1"

# Allocate.
assert_match "GLM_CALC ok" "$(run_cobol "GLM_CALC|${id}|||||admin@test.com")" "SUCCESS\|GLM_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM gl_master WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "GLM_DELETE ok" "$(run_cobol "GLM_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|GLM_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM gl_master WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "GLM_SUMMARY ok" "$(run_cobol "GLM_SUMMARY||||||admin@test.com")" "SUCCESS\|GLM_SUMMARY"
assert_match "GLM_AUDIT ok" "$(run_cobol "GLM_AUDIT|50|0||||admin@test.com")" "SUCCESS\|GLM_AUDIT"
assert_match "GLM_VALIDATE ok" "$(run_cobol "GLM_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|GLM_VALID"
assert_match "non-admin refused" "$(run_cobol "GLM_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0