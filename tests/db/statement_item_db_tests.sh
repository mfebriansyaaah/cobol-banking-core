#!/usr/bin/env bash
# Statement item (Wave15) end-to-end DB tests via the COBOL binary.
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
db_reset_statement_item

# Create a cost center.
create_out="$(run_cobol "ACST_CREATE|ACST-W15-1|AccountA|MONTHLY|||admin@test.com")"
assert_match "ACST_CREATE ok" "$create_out" "SUCCESS\|ACST_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM statement_item WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "ACST_CREATE|ACST-W15-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "ACST_GET ok" "$(run_cobol "ACST_GET|${id}|||||admin@test.com")" "SUCCESS\|ACST_GET\|${id}\|ACST-W15-1"
assert_match "ACST_LIST ok" "$(run_cobol "ACST_LIST|||50|0||admin@test.com")" "ACST-W15-1"

# Allocate.
assert_match "ACST_CALC ok" "$(run_cobol "ACST_CALC|${id}|||||admin@test.com")" "SUCCESS\|ACST_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM statement_item WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "ACST_DELETE ok" "$(run_cobol "ACST_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|ACST_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM statement_item WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "ACST_SUMMARY ok" "$(run_cobol "ACST_SUMMARY||||||admin@test.com")" "SUCCESS\|ACST_SUMMARY"
assert_match "ACST_AUDIT ok" "$(run_cobol "ACST_AUDIT|50|0||||admin@test.com")" "SUCCESS\|ACST_AUDIT"
assert_match "ACST_VALIDATE ok" "$(run_cobol "ACST_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|ACST_VALID"
assert_match "non-admin refused" "$(run_cobol "ACST_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0