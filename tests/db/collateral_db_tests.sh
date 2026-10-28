#!/usr/bin/env bash
# collateral (Wave1) end-to-end DB tests via the COBOL binary.
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
db_reset_collateral

# Create a cost center.
create_out="$(run_cobol "CLT_CREATE|CLT-W1-1|Property|REALESTATE|||admin@test.com")"
assert_match "CLT_CREATE ok" "$create_out" "SUCCESS\|CLT_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM collateral WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "CLT_CREATE|CLT-W1-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "CLT_GET ok" "$(run_cobol "CLT_GET|${id}|||||admin@test.com")" "SUCCESS\|CLT_GET\|${id}\|CLT-W1-1"
assert_match "CLT_LIST ok" "$(run_cobol "CLT_LIST|||50|0||admin@test.com")" "CLT-W1-1"

# Allocate.
assert_match "CLT_CALC ok" "$(run_cobol "CLT_CALC|${id}|||||admin@test.com")" "SUCCESS\|CLT_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT appraised_value FROM collateral WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "CLT_DELETE ok" "$(run_cobol "CLT_DELETE|${id}|RELEASED||||admin@test.com")" "SUCCESS\|CLT_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM collateral WHERE id=${id};")" "^RELEASED$"

# Summary and audit.
assert_match "CLT_SUMMARY ok" "$(run_cobol "CLT_SUMMARY||||||admin@test.com")" "SUCCESS\|CLT_SUMMARY"
assert_match "CLT_AUDIT ok" "$(run_cobol "CLT_AUDIT|50|0||||admin@test.com")" "SUCCESS\|CLT_AUDIT"
assert_match "CLT_VALIDATE ok" "$(run_cobol "CLT_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|CLT_VALID"
assert_match "non-admin refused" "$(run_cobol "CLT_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0