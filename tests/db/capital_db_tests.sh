#!/usr/bin/env bash
# Capital (Wave13) end-to-end DB tests via the COBOL binary.
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
db_reset_capital

# Create a cost center.
create_out="$(run_cobol "CPTL_CREATE|CPTL-W13-1|EntityA|TIER1|||admin@test.com")"
assert_match "CPTL_CREATE ok" "$create_out" "SUCCESS\|CPTL_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM capital WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "CPTL_CREATE|CPTL-W13-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "CPTL_GET ok" "$(run_cobol "CPTL_GET|${id}|||||admin@test.com")" "SUCCESS\|CPTL_GET\|${id}\|CPTL-W13-1"
assert_match "CPTL_LIST ok" "$(run_cobol "CPTL_LIST|||50|0||admin@test.com")" "CPTL-W13-1"

# Allocate.
assert_match "CPTL_CALC ok" "$(run_cobol "CPTL_CALC|${id}|||||admin@test.com")" "SUCCESS\|CPTL_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM capital WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "CPTL_DELETE ok" "$(run_cobol "CPTL_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|CPTL_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM capital WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "CPTL_SUMMARY ok" "$(run_cobol "CPTL_SUMMARY||||||admin@test.com")" "SUCCESS\|CPTL_SUMMARY"
assert_match "CPTL_AUDIT ok" "$(run_cobol "CPTL_AUDIT|50|0||||admin@test.com")" "SUCCESS\|CPTL_AUDIT"
assert_match "CPTL_VALIDATE ok" "$(run_cobol "CPTL_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|CPTL_VALID"
assert_match "non-admin refused" "$(run_cobol "CPTL_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0