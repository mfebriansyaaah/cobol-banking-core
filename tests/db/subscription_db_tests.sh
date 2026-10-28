#!/usr/bin/env bash
# Subscription (Wave10) end-to-end DB tests via the COBOL binary.
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
db_reset_subscription

# Create a cost center.
create_out="$(run_cobol "SUB_CREATE|SUB-W10-1|CustomerA|MONTHLY|||admin@test.com")"
assert_match "SUB_CREATE ok" "$create_out" "SUCCESS\|SUB_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM subscription WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "SUB_CREATE|SUB-W10-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "SUB_GET ok" "$(run_cobol "SUB_GET|${id}|||||admin@test.com")" "SUCCESS\|SUB_GET\|${id}\|SUB-W10-1"
assert_match "SUB_LIST ok" "$(run_cobol "SUB_LIST|||50|0||admin@test.com")" "SUB-W10-1"

# Allocate.
assert_match "SUB_CALC ok" "$(run_cobol "SUB_CALC|${id}|||||admin@test.com")" "SUCCESS\|SUB_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM subscription WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "SUB_DELETE ok" "$(run_cobol "SUB_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|SUB_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM subscription WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "SUB_SUMMARY ok" "$(run_cobol "SUB_SUMMARY||||||admin@test.com")" "SUCCESS\|SUB_SUMMARY"
assert_match "SUB_AUDIT ok" "$(run_cobol "SUB_AUDIT|50|0||||admin@test.com")" "SUCCESS\|SUB_AUDIT"
assert_match "SUB_VALIDATE ok" "$(run_cobol "SUB_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|SUB_VALID"
assert_match "non-admin refused" "$(run_cobol "SUB_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0