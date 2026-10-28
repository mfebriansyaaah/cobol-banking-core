#!/usr/bin/env bash
# Mark to market (Wave9) end-to-end DB tests via the COBOL binary.
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
db_reset_mark_to_market

# Create a cost center.
create_out="$(run_cobol "MTM_CREATE|MTM-W9-1|EntityA|MTM|||admin@test.com")"
assert_match "MTM_CREATE ok" "$create_out" "SUCCESS\|MTM_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM mark_to_market WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "MTM_CREATE|MTM-W9-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "MTM_GET ok" "$(run_cobol "MTM_GET|${id}|||||admin@test.com")" "SUCCESS\|MTM_GET\|${id}\|MTM-W9-1"
assert_match "MTM_LIST ok" "$(run_cobol "MTM_LIST|||50|0||admin@test.com")" "MTM-W9-1"

# Allocate.
assert_match "MTM_CALC ok" "$(run_cobol "MTM_CALC|${id}|||||admin@test.com")" "SUCCESS\|MTM_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM mark_to_market WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "MTM_DELETE ok" "$(run_cobol "MTM_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|MTM_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM mark_to_market WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "MTM_SUMMARY ok" "$(run_cobol "MTM_SUMMARY||||||admin@test.com")" "SUCCESS\|MTM_SUMMARY"
assert_match "MTM_AUDIT ok" "$(run_cobol "MTM_AUDIT|50|0||||admin@test.com")" "SUCCESS\|MTM_AUDIT"
assert_match "MTM_VALIDATE ok" "$(run_cobol "MTM_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|MTM_VALID"
assert_match "non-admin refused" "$(run_cobol "MTM_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0