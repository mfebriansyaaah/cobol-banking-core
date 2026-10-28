#!/usr/bin/env bash
# Securities lending (Wave6) end-to-end DB tests via the COBOL binary.
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
db_reset_securities_lending

# Create a cost center.
create_out="$(run_cobol "SEL_CREATE|SEL-W6-1|BorrowerA|EQUITY|||admin@test.com")"
assert_match "SEL_CREATE ok" "$create_out" "SUCCESS\|SEL_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM securities_lending WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "SEL_CREATE|SEL-W6-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "SEL_GET ok" "$(run_cobol "SEL_GET|${id}|||||admin@test.com")" "SUCCESS\|SEL_GET\|${id}\|SEL-W6-1"
assert_match "SEL_LIST ok" "$(run_cobol "SEL_LIST|||50|0||admin@test.com")" "SEL-W6-1"

# Allocate.
assert_match "SEL_CALC ok" "$(run_cobol "SEL_CALC|${id}|||||admin@test.com")" "SUCCESS\|SEL_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM securities_lending WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "SEL_DELETE ok" "$(run_cobol "SEL_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|SEL_DELETE"
assert_match "returned persisted" "$(db_query "SELECT status FROM securities_lending WHERE id=${id};")" "^RETURNED$"

# Summary and audit.
assert_match "SEL_SUMMARY ok" "$(run_cobol "SEL_SUMMARY||||||admin@test.com")" "SUCCESS\|SEL_SUMMARY"
assert_match "SEL_AUDIT ok" "$(run_cobol "SEL_AUDIT|50|0||||admin@test.com")" "SUCCESS\|SEL_AUDIT"
assert_match "SEL_VALIDATE ok" "$(run_cobol "SEL_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|SEL_VALID"
assert_match "non-admin refused" "$(run_cobol "SEL_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0