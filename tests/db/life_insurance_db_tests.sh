#!/usr/bin/env bash
# Life insurance (Wave18) end-to-end DB tests via the COBOL binary.
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
db_reset_life_insurance

# Create a cost center.
create_out="$(run_cobol "LIF_CREATE|LIF-W18-1|PolicyholderA|TERM|||admin@test.com")"
assert_match "LIF_CREATE ok" "$create_out" "SUCCESS\|LIF_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM life_insurance WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "LIF_CREATE|LIF-W18-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "LIF_GET ok" "$(run_cobol "LIF_GET|${id}|||||admin@test.com")" "SUCCESS\|LIF_GET\|${id}\|LIF-W18-1"
assert_match "LIF_LIST ok" "$(run_cobol "LIF_LIST|||50|0||admin@test.com")" "LIF-W18-1"

# Allocate.
assert_match "LIF_CALC ok" "$(run_cobol "LIF_CALC|${id}|||||admin@test.com")" "SUCCESS\|LIF_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM life_insurance WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "LIF_DELETE ok" "$(run_cobol "LIF_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|LIF_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM life_insurance WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "LIF_SUMMARY ok" "$(run_cobol "LIF_SUMMARY||||||admin@test.com")" "SUCCESS\|LIF_SUMMARY"
assert_match "LIF_AUDIT ok" "$(run_cobol "LIF_AUDIT|50|0||||admin@test.com")" "SUCCESS\|LIF_AUDIT"
assert_match "LIF_VALIDATE ok" "$(run_cobol "LIF_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|LIF_VALID"
assert_match "non-admin refused" "$(run_cobol "LIF_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0