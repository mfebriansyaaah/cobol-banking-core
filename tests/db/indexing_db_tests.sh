#!/usr/bin/env bash
# Indexing (Wave11) end-to-end DB tests via the COBOL binary.
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
db_reset_indexing

# Create a cost center.
create_out="$(run_cobol "IDX_CREATE|IDX-W11-1|IndexA|INVERTED|||admin@test.com")"
assert_match "IDX_CREATE ok" "$create_out" "SUCCESS\|IDX_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM indexing WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "IDX_CREATE|IDX-W11-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "IDX_GET ok" "$(run_cobol "IDX_GET|${id}|||||admin@test.com")" "SUCCESS\|IDX_GET\|${id}\|IDX-W11-1"
assert_match "IDX_LIST ok" "$(run_cobol "IDX_LIST|||50|0||admin@test.com")" "IDX-W11-1"

# Allocate.
assert_match "IDX_CALC ok" "$(run_cobol "IDX_CALC|${id}|||||admin@test.com")" "SUCCESS\|IDX_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM indexing WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "IDX_DELETE ok" "$(run_cobol "IDX_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|IDX_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM indexing WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "IDX_SUMMARY ok" "$(run_cobol "IDX_SUMMARY||||||admin@test.com")" "SUCCESS\|IDX_SUMMARY"
assert_match "IDX_AUDIT ok" "$(run_cobol "IDX_AUDIT|50|0||||admin@test.com")" "SUCCESS\|IDX_AUDIT"
assert_match "IDX_VALIDATE ok" "$(run_cobol "IDX_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|IDX_VALID"
assert_match "non-admin refused" "$(run_cobol "IDX_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0