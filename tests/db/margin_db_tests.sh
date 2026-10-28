#!/usr/bin/env bash
# Margin (Wave9) end-to-end DB tests via the COBOL binary.
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
db_reset_margin

# Create a cost center.
create_out="$(run_cobol "MRG_CREATE|MRG-W9-1|EntityA|GROSS|||admin@test.com")"
assert_match "MRG_CREATE ok" "$create_out" "SUCCESS\|MRG_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM margin WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "MRG_CREATE|MRG-W9-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "MRG_GET ok" "$(run_cobol "MRG_GET|${id}|||||admin@test.com")" "SUCCESS\|MRG_GET\|${id}\|MRG-W9-1"
assert_match "MRG_LIST ok" "$(run_cobol "MRG_LIST|||50|0||admin@test.com")" "MRG-W9-1"

# Allocate.
assert_match "MRG_CALC ok" "$(run_cobol "MRG_CALC|${id}|||||admin@test.com")" "SUCCESS\|MRG_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM margin WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "MRG_DELETE ok" "$(run_cobol "MRG_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|MRG_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM margin WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "MRG_SUMMARY ok" "$(run_cobol "MRG_SUMMARY||||||admin@test.com")" "SUCCESS\|MRG_SUMMARY"
assert_match "MRG_AUDIT ok" "$(run_cobol "MRG_AUDIT|50|0||||admin@test.com")" "SUCCESS\|MRG_AUDIT"
assert_match "MRG_VALIDATE ok" "$(run_cobol "MRG_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|MRG_VALID"
assert_match "non-admin refused" "$(run_cobol "MRG_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0