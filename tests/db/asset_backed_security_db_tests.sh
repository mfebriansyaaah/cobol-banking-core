#!/usr/bin/env bash
# Asset backed security (Wave12) end-to-end DB tests via the COBOL binary.
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
db_reset_asset_backed_security

# Create a cost center.
create_out="$(run_cobol "ASB_CREATE|ASB-W12-1|SecurityA|ABS|||admin@test.com")"
assert_match "ASB_CREATE ok" "$create_out" "SUCCESS\|ASB_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM asset_backed_security WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "ASB_CREATE|ASB-W12-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "ASB_GET ok" "$(run_cobol "ASB_GET|${id}|||||admin@test.com")" "SUCCESS\|ASB_GET\|${id}\|ASB-W12-1"
assert_match "ASB_LIST ok" "$(run_cobol "ASB_LIST|||50|0||admin@test.com")" "ASB-W12-1"

# Allocate.
assert_match "ASB_CALC ok" "$(run_cobol "ASB_CALC|${id}|||||admin@test.com")" "SUCCESS\|ASB_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM asset_backed_security WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "ASB_DELETE ok" "$(run_cobol "ASB_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|ASB_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM asset_backed_security WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "ASB_SUMMARY ok" "$(run_cobol "ASB_SUMMARY||||||admin@test.com")" "SUCCESS\|ASB_SUMMARY"
assert_match "ASB_AUDIT ok" "$(run_cobol "ASB_AUDIT|50|0||||admin@test.com")" "SUCCESS\|ASB_AUDIT"
assert_match "ASB_VALIDATE ok" "$(run_cobol "ASB_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|ASB_VALID"
assert_match "non-admin refused" "$(run_cobol "ASB_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0