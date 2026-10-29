#!/usr/bin/env bash
# Auto finance (Wave20) end-to-end DB tests via the COBOL binary.
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
db_reset_auto_finance

# Create a cost center.
create_out="$(run_cobol "ATF_CREATE|ATF-W20-1|AutoA|VEHICLE|||admin@test.com")"
assert_match "ATF_CREATE ok" "$create_out" "SUCCESS\|ATF_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM auto_finance WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "ATF_CREATE|ATF-W20-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "ATF_GET ok" "$(run_cobol "ATF_GET|${id}|||||admin@test.com")" "SUCCESS\|ATF_GET\|${id}\|ATF-W20-1"
assert_match "ATF_LIST ok" "$(run_cobol "ATF_LIST|||50|0||admin@test.com")" "ATF-W20-1"

# Allocate.
assert_match "ATF_CALC ok" "$(run_cobol "ATF_CALC|${id}|||||admin@test.com")" "SUCCESS\|ATF_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM auto_finance WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "ATF_DELETE ok" "$(run_cobol "ATF_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|ATF_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM auto_finance WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "ATF_SUMMARY ok" "$(run_cobol "ATF_SUMMARY||||||admin@test.com")" "SUCCESS\|ATF_SUMMARY"
assert_match "ATF_AUDIT ok" "$(run_cobol "ATF_AUDIT|50|0||||admin@test.com")" "SUCCESS\|ATF_AUDIT"
assert_match "ATF_VALIDATE ok" "$(run_cobol "ATF_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|ATF_VALID"
assert_match "non-admin refused" "$(run_cobol "ATF_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0