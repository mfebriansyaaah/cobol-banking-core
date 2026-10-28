#!/usr/bin/env bash
# API gateway (Wave11) end-to-end DB tests via the COBOL binary.
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
db_reset_api_gateway

# Create a cost center.
create_out="$(run_cobol "APG_CREATE|APG-W11-1|GatewayA|REST|||admin@test.com")"
assert_match "APG_CREATE ok" "$create_out" "SUCCESS\|APG_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM api_gateway WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "APG_CREATE|APG-W11-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "APG_GET ok" "$(run_cobol "APG_GET|${id}|||||admin@test.com")" "SUCCESS\|APG_GET\|${id}\|APG-W11-1"
assert_match "APG_LIST ok" "$(run_cobol "APG_LIST|||50|0||admin@test.com")" "APG-W11-1"

# Allocate.
assert_match "APG_CALC ok" "$(run_cobol "APG_CALC|${id}|||||admin@test.com")" "SUCCESS\|APG_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM api_gateway WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "APG_DELETE ok" "$(run_cobol "APG_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|APG_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM api_gateway WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "APG_SUMMARY ok" "$(run_cobol "APG_SUMMARY||||||admin@test.com")" "SUCCESS\|APG_SUMMARY"
assert_match "APG_AUDIT ok" "$(run_cobol "APG_AUDIT|50|0||||admin@test.com")" "SUCCESS\|APG_AUDIT"
assert_match "APG_VALIDATE ok" "$(run_cobol "APG_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|APG_VALID"
assert_match "non-admin refused" "$(run_cobol "APG_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0