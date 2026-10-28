#!/usr/bin/env bash
# A/B testing (Wave11) end-to-end DB tests via the COBOL binary.
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
db_reset_ab_testing

# Create a cost center.
create_out="$(run_cobol "ABT_CREATE|ABT-W11-1|TestA|SPLIT|||admin@test.com")"
assert_match "ABT_CREATE ok" "$create_out" "SUCCESS\|ABT_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM ab_testing WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "ABT_CREATE|ABT-W11-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "ABT_GET ok" "$(run_cobol "ABT_GET|${id}|||||admin@test.com")" "SUCCESS\|ABT_GET\|${id}\|ABT-W11-1"
assert_match "ABT_LIST ok" "$(run_cobol "ABT_LIST|||50|0||admin@test.com")" "ABT-W11-1"

# Allocate.
assert_match "ABT_CALC ok" "$(run_cobol "ABT_CALC|${id}|||||admin@test.com")" "SUCCESS\|ABT_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM ab_testing WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "ABT_DELETE ok" "$(run_cobol "ABT_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|ABT_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM ab_testing WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "ABT_SUMMARY ok" "$(run_cobol "ABT_SUMMARY||||||admin@test.com")" "SUCCESS\|ABT_SUMMARY"
assert_match "ABT_AUDIT ok" "$(run_cobol "ABT_AUDIT|50|0||||admin@test.com")" "SUCCESS\|ABT_AUDIT"
assert_match "ABT_VALIDATE ok" "$(run_cobol "ABT_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|ABT_VALID"
assert_match "non-admin refused" "$(run_cobol "ABT_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0