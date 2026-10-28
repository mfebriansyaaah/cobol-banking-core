#!/usr/bin/env bash
# Contract (Wave10) end-to-end DB tests via the COBOL binary.
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
db_reset_contract

# Create a cost center.
create_out="$(run_cobol "CON_CREATE|CON-W10-1|PartyA|SERVICE|||admin@test.com")"
assert_match "CON_CREATE ok" "$create_out" "SUCCESS\|CON_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM contract WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "CON_CREATE|CON-W10-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "CON_GET ok" "$(run_cobol "CON_GET|${id}|||||admin@test.com")" "SUCCESS\|CON_GET\|${id}\|CON-W10-1"
assert_match "CON_LIST ok" "$(run_cobol "CON_LIST|||50|0||admin@test.com")" "CON-W10-1"

# Allocate.
assert_match "CON_CALC ok" "$(run_cobol "CON_CALC|${id}|||||admin@test.com")" "SUCCESS\|CON_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM contract WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "CON_DELETE ok" "$(run_cobol "CON_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|CON_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM contract WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "CON_SUMMARY ok" "$(run_cobol "CON_SUMMARY||||||admin@test.com")" "SUCCESS\|CON_SUMMARY"
assert_match "CON_AUDIT ok" "$(run_cobol "CON_AUDIT|50|0||||admin@test.com")" "SUCCESS\|CON_AUDIT"
assert_match "CON_VALIDATE ok" "$(run_cobol "CON_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|CON_VALID"
assert_match "non-admin refused" "$(run_cobol "CON_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0