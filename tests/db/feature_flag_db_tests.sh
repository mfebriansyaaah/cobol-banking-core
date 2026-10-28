#!/usr/bin/env bash
# Feature flag (Wave11) end-to-end DB tests via the COBOL binary.
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
db_reset_feature_flag

# Create a cost center.
create_out="$(run_cobol "FFL_CREATE|FFL-W11-1|FlagA|BOOLEAN|||admin@test.com")"
assert_match "FFL_CREATE ok" "$create_out" "SUCCESS\|FFL_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM feature_flag WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "FFL_CREATE|FFL-W11-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "FFL_GET ok" "$(run_cobol "FFL_GET|${id}|||||admin@test.com")" "SUCCESS\|FFL_GET\|${id}\|FFL-W11-1"
assert_match "FFL_LIST ok" "$(run_cobol "FFL_LIST|||50|0||admin@test.com")" "FFL-W11-1"

# Allocate.
assert_match "FFL_CALC ok" "$(run_cobol "FFL_CALC|${id}|||||admin@test.com")" "SUCCESS\|FFL_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM feature_flag WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "FFL_DELETE ok" "$(run_cobol "FFL_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|FFL_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM feature_flag WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "FFL_SUMMARY ok" "$(run_cobol "FFL_SUMMARY||||||admin@test.com")" "SUCCESS\|FFL_SUMMARY"
assert_match "FFL_AUDIT ok" "$(run_cobol "FFL_AUDIT|50|0||||admin@test.com")" "SUCCESS\|FFL_AUDIT"
assert_match "FFL_VALIDATE ok" "$(run_cobol "FFL_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|FFL_VALID"
assert_match "non-admin refused" "$(run_cobol "FFL_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0