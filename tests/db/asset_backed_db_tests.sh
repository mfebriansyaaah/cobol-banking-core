#!/usr/bin/env bash
# Asset backed (Wave12) end-to-end DB tests via the COBOL binary.
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
db_reset_asset_backed

# Create a cost center.
create_out="$(run_cobol "ABS_CREATE|ABS-W12-1|AssetA|MBS|||admin@test.com")"
assert_match "ABS_CREATE ok" "$create_out" "SUCCESS\|ABS_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM asset_backed WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "ABS_CREATE|ABS-W12-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "ABS_GET ok" "$(run_cobol "ABS_GET|${id}|||||admin@test.com")" "SUCCESS\|ABS_GET\|${id}\|ABS-W12-1"
assert_match "ABS_LIST ok" "$(run_cobol "ABS_LIST|||50|0||admin@test.com")" "ABS-W12-1"

# Allocate.
assert_match "ABS_CALC ok" "$(run_cobol "ABS_CALC|${id}|||||admin@test.com")" "SUCCESS\|ABS_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM asset_backed WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "ABS_DELETE ok" "$(run_cobol "ABS_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|ABS_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM asset_backed WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "ABS_SUMMARY ok" "$(run_cobol "ABS_SUMMARY||||||admin@test.com")" "SUCCESS\|ABS_SUMMARY"
assert_match "ABS_AUDIT ok" "$(run_cobol "ABS_AUDIT|50|0||||admin@test.com")" "SUCCESS\|ABS_AUDIT"
assert_match "ABS_VALIDATE ok" "$(run_cobol "ABS_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|ABS_VALID"
assert_match "non-admin refused" "$(run_cobol "ABS_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0