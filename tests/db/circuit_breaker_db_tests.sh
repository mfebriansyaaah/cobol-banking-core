#!/usr/bin/env bash
# Circuit breaker (Wave11) end-to-end DB tests via the COBOL binary.
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
db_reset_circuit_breaker

# Create a cost center.
create_out="$(run_cobol "CBK_CREATE|CBK-W11-1|ServiceA|CLOSED_STATE|||admin@test.com")"
assert_match "CBK_CREATE ok" "$create_out" "SUCCESS\|CBK_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM circuit_breaker WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "CBK_CREATE|CBK-W11-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "CBK_GET ok" "$(run_cobol "CBK_GET|${id}|||||admin@test.com")" "SUCCESS\|CBK_GET\|${id}\|CBK-W11-1"
assert_match "CBK_LIST ok" "$(run_cobol "CBK_LIST|||50|0||admin@test.com")" "CBK-W11-1"

# Allocate.
assert_match "CBK_CALC ok" "$(run_cobol "CBK_CALC|${id}|||||admin@test.com")" "SUCCESS\|CBK_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM circuit_breaker WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "CBK_DELETE ok" "$(run_cobol "CBK_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|CBK_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM circuit_breaker WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "CBK_SUMMARY ok" "$(run_cobol "CBK_SUMMARY||||||admin@test.com")" "SUCCESS\|CBK_SUMMARY"
assert_match "CBK_AUDIT ok" "$(run_cobol "CBK_AUDIT|50|0||||admin@test.com")" "SUCCESS\|CBK_AUDIT"
assert_match "CBK_VALIDATE ok" "$(run_cobol "CBK_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|CBK_VALID"
assert_match "non-admin refused" "$(run_cobol "CBK_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0