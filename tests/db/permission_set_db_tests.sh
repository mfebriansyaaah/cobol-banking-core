#!/usr/bin/env bash
# Permission set (Wave5) end-to-end DB tests via the COBOL binary.
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
db_reset_permission_set

# Create a cost center.
create_out="$(run_cobol "PMS_CREATE|PMS-W5-1|PermA|CREATE|||admin@test.com")"
assert_match "PMS_CREATE ok" "$create_out" "SUCCESS\|PMS_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM permission_set WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "PMS_CREATE|PMS-W5-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "PMS_GET ok" "$(run_cobol "PMS_GET|${id}|||||admin@test.com")" "SUCCESS\|PMS_GET\|${id}\|PMS-W5-1"
assert_match "PMS_LIST ok" "$(run_cobol "PMS_LIST|||50|0||admin@test.com")" "PMS-W5-1"

# Allocate.
assert_match "PMS_CALC ok" "$(run_cobol "PMS_CALC|${id}|||||admin@test.com")" "SUCCESS\|PMS_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT grant_count FROM permission_set WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "PMS_DELETE ok" "$(run_cobol "PMS_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|PMS_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM permission_set WHERE id=${id};")" "^REVOKED$"

# Summary and audit.
assert_match "PMS_SUMMARY ok" "$(run_cobol "PMS_SUMMARY||||||admin@test.com")" "SUCCESS\|PMS_SUMMARY"
assert_match "PMS_AUDIT ok" "$(run_cobol "PMS_AUDIT|50|0||||admin@test.com")" "SUCCESS\|PMS_AUDIT"
assert_match "PMS_VALIDATE ok" "$(run_cobol "PMS_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|PMS_VALID"
assert_match "non-admin refused" "$(run_cobol "PMS_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0