#!/usr/bin/env bash
# Investment (Wave14) end-to-end DB tests via the COBOL binary.
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
db_reset_investment

# Create a cost center.
create_out="$(run_cobol "INVS_CREATE|INVS-W14-1|InvA|EQUITY|||admin@test.com")"
assert_match "INVS_CREATE ok" "$create_out" "SUCCESS\|INVS_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM investment WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "INVS_CREATE|INVS-W14-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "INVS_GET ok" "$(run_cobol "INVS_GET|${id}|||||admin@test.com")" "SUCCESS\|INVS_GET\|${id}\|INVS-W14-1"
assert_match "INVS_LIST ok" "$(run_cobol "INVS_LIST|||50|0||admin@test.com")" "INVS-W14-1"

# Allocate.
assert_match "INVS_CALC ok" "$(run_cobol "INVS_CALC|${id}|||||admin@test.com")" "SUCCESS\|INVS_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM investment WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "INVS_DELETE ok" "$(run_cobol "INVS_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|INVS_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM investment WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "INVS_SUMMARY ok" "$(run_cobol "INVS_SUMMARY||||||admin@test.com")" "SUCCESS\|INVS_SUMMARY"
assert_match "INVS_AUDIT ok" "$(run_cobol "INVS_AUDIT|50|0||||admin@test.com")" "SUCCESS\|INVS_AUDIT"
assert_match "INVS_VALIDATE ok" "$(run_cobol "INVS_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|INVS_VALID"
assert_match "non-admin refused" "$(run_cobol "INVS_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0