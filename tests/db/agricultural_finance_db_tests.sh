#!/usr/bin/env bash
# Agricultural finance (Wave20) end-to-end DB tests via the COBOL binary.
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
db_reset_agricultural_finance

# Create a cost center.
create_out="$(run_cobol "AGF_CREATE|AGF-W20-1|AgriA|CROP|||admin@test.com")"
assert_match "AGF_CREATE ok" "$create_out" "SUCCESS\|AGF_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM agricultural_finance WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "AGF_CREATE|AGF-W20-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "AGF_GET ok" "$(run_cobol "AGF_GET|${id}|||||admin@test.com")" "SUCCESS\|AGF_GET\|${id}\|AGF-W20-1"
assert_match "AGF_LIST ok" "$(run_cobol "AGF_LIST|||50|0||admin@test.com")" "AGF-W20-1"

# Allocate.
assert_match "AGF_CALC ok" "$(run_cobol "AGF_CALC|${id}|||||admin@test.com")" "SUCCESS\|AGF_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM agricultural_finance WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "AGF_DELETE ok" "$(run_cobol "AGF_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|AGF_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM agricultural_finance WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "AGF_SUMMARY ok" "$(run_cobol "AGF_SUMMARY||||||admin@test.com")" "SUCCESS\|AGF_SUMMARY"
assert_match "AGF_AUDIT ok" "$(run_cobol "AGF_AUDIT|50|0||||admin@test.com")" "SUCCESS\|AGF_AUDIT"
assert_match "AGF_VALIDATE ok" "$(run_cobol "AGF_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|AGF_VALID"
assert_match "non-admin refused" "$(run_cobol "AGF_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0