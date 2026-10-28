#!/usr/bin/env bash
# Provisioning (Wave7) end-to-end DB tests via the COBOL binary.
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
db_reset_provisioning

# Create a cost center.
create_out="$(run_cobol "PRV_CREATE|PRV-W7-1|ProvisionA|GENERAL|||admin@test.com")"
assert_match "PRV_CREATE ok" "$create_out" "SUCCESS\|PRV_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM provisioning WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "PRV_CREATE|PRV-W7-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "PRV_GET ok" "$(run_cobol "PRV_GET|${id}|||||admin@test.com")" "SUCCESS\|PRV_GET\|${id}\|PRV-W7-1"
assert_match "PRV_LIST ok" "$(run_cobol "PRV_LIST|||50|0||admin@test.com")" "PRV-W7-1"

# Allocate.
assert_match "PRV_CALC ok" "$(run_cobol "PRV_CALC|${id}|||||admin@test.com")" "SUCCESS\|PRV_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM provisioning WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "PRV_DELETE ok" "$(run_cobol "PRV_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|PRV_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM provisioning WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "PRV_SUMMARY ok" "$(run_cobol "PRV_SUMMARY||||||admin@test.com")" "SUCCESS\|PRV_SUMMARY"
assert_match "PRV_AUDIT ok" "$(run_cobol "PRV_AUDIT|50|0||||admin@test.com")" "SUCCESS\|PRV_AUDIT"
assert_match "PRV_VALIDATE ok" "$(run_cobol "PRV_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|PRV_VALID"
assert_match "non-admin refused" "$(run_cobol "PRV_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0