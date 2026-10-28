#!/usr/bin/env bash
# Treasury deal (Wave3) end-to-end DB tests via the COBOL binary.
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
db_reset_treasury_deal

# Create a cost center.
create_out="$(run_cobol "TSD_CREATE|TSD-W3-1|CounterpartyA|IR|||admin@test.com")"
assert_match "TSD_CREATE ok" "$create_out" "SUCCESS\|TSD_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM treasury_deal WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "TSD_CREATE|TSD-W3-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "TSD_GET ok" "$(run_cobol "TSD_GET|${id}|||||admin@test.com")" "SUCCESS\|TSD_GET\|${id}\|TSD-W3-1"
assert_match "TSD_LIST ok" "$(run_cobol "TSD_LIST|||50|0||admin@test.com")" "TSD-W3-1"

# Allocate.
assert_match "TSD_CALC ok" "$(run_cobol "TSD_CALC|${id}|||||admin@test.com")" "SUCCESS\|TSD_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT mtm_value FROM treasury_deal WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "TSD_DELETE ok" "$(run_cobol "TSD_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|TSD_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM treasury_deal WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "TSD_SUMMARY ok" "$(run_cobol "TSD_SUMMARY||||||admin@test.com")" "SUCCESS\|TSD_SUMMARY"
assert_match "TSD_AUDIT ok" "$(run_cobol "TSD_AUDIT|50|0||||admin@test.com")" "SUCCESS\|TSD_AUDIT"
assert_match "TSD_VALIDATE ok" "$(run_cobol "TSD_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|TSD_VALID"
assert_match "non-admin refused" "$(run_cobol "TSD_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0