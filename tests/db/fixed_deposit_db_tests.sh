#!/usr/bin/env bash
# Fixed deposit (Wave9) end-to-end DB tests via the COBOL binary.
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
db_reset_fixed_deposit

# Create a cost center.
create_out="$(run_cobol "FDP_CREATE|FDP-W9-1|DepositorA|FD|||admin@test.com")"
assert_match "FDP_CREATE ok" "$create_out" "SUCCESS\|FDP_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM fixed_deposit WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "FDP_CREATE|FDP-W9-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "FDP_GET ok" "$(run_cobol "FDP_GET|${id}|||||admin@test.com")" "SUCCESS\|FDP_GET\|${id}\|FDP-W9-1"
assert_match "FDP_LIST ok" "$(run_cobol "FDP_LIST|||50|0||admin@test.com")" "FDP-W9-1"

# Allocate.
assert_match "FDP_CALC ok" "$(run_cobol "FDP_CALC|${id}|||||admin@test.com")" "SUCCESS\|FDP_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM fixed_deposit WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "FDP_DELETE ok" "$(run_cobol "FDP_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|FDP_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM fixed_deposit WHERE id=${id};")" "^MATURED$"

# Summary and audit.
assert_match "FDP_SUMMARY ok" "$(run_cobol "FDP_SUMMARY||||||admin@test.com")" "SUCCESS\|FDP_SUMMARY"
assert_match "FDP_AUDIT ok" "$(run_cobol "FDP_AUDIT|50|0||||admin@test.com")" "SUCCESS\|FDP_AUDIT"
assert_match "FDP_VALIDATE ok" "$(run_cobol "FDP_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|FDP_VALID"
assert_match "non-admin refused" "$(run_cobol "FDP_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0