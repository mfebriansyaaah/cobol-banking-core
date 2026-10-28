#!/usr/bin/env bash
# Simulation (Wave14) end-to-end DB tests via the COBOL binary.
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
db_reset_simulation

# Create a cost center.
create_out="$(run_cobol "SIM_CREATE|SIM-W14-1|SimA|MONTE_CARLO|||admin@test.com")"
assert_match "SIM_CREATE ok" "$create_out" "SUCCESS\|SIM_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM simulation WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "SIM_CREATE|SIM-W14-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "SIM_GET ok" "$(run_cobol "SIM_GET|${id}|||||admin@test.com")" "SUCCESS\|SIM_GET\|${id}\|SIM-W14-1"
assert_match "SIM_LIST ok" "$(run_cobol "SIM_LIST|||50|0||admin@test.com")" "SIM-W14-1"

# Allocate.
assert_match "SIM_CALC ok" "$(run_cobol "SIM_CALC|${id}|||||admin@test.com")" "SUCCESS\|SIM_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM simulation WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "SIM_DELETE ok" "$(run_cobol "SIM_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|SIM_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM simulation WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "SIM_SUMMARY ok" "$(run_cobol "SIM_SUMMARY||||||admin@test.com")" "SUCCESS\|SIM_SUMMARY"
assert_match "SIM_AUDIT ok" "$(run_cobol "SIM_AUDIT|50|0||||admin@test.com")" "SUCCESS\|SIM_AUDIT"
assert_match "SIM_VALIDATE ok" "$(run_cobol "SIM_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|SIM_VALID"
assert_match "non-admin refused" "$(run_cobol "SIM_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0