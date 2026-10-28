#!/usr/bin/env bash
# Digital asset (Wave6) end-to-end DB tests via the COBOL binary.
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
db_reset_digital_asset

# Create a cost center.
create_out="$(run_cobol "DAS_CREATE|DAS-W6-1|AssetA|TOKEN|||admin@test.com")"
assert_match "DAS_CREATE ok" "$create_out" "SUCCESS\|DAS_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM digital_asset WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "DAS_CREATE|DAS-W6-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "DAS_GET ok" "$(run_cobol "DAS_GET|${id}|||||admin@test.com")" "SUCCESS\|DAS_GET\|${id}\|DAS-W6-1"
assert_match "DAS_LIST ok" "$(run_cobol "DAS_LIST|||50|0||admin@test.com")" "DAS-W6-1"

# Allocate.
assert_match "DAS_CALC ok" "$(run_cobol "DAS_CALC|${id}|||||admin@test.com")" "SUCCESS\|DAS_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM digital_asset WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "DAS_DELETE ok" "$(run_cobol "DAS_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|DAS_DELETE"
assert_match "burned persisted" "$(db_query "SELECT status FROM digital_asset WHERE id=${id};")" "^BURNED$"

# Summary and audit.
assert_match "DAS_SUMMARY ok" "$(run_cobol "DAS_SUMMARY||||||admin@test.com")" "SUCCESS\|DAS_SUMMARY"
assert_match "DAS_AUDIT ok" "$(run_cobol "DAS_AUDIT|50|0||||admin@test.com")" "SUCCESS\|DAS_AUDIT"
assert_match "DAS_VALIDATE ok" "$(run_cobol "DAS_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|DAS_VALID"
assert_match "non-admin refused" "$(run_cobol "DAS_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0