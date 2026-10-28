#!/usr/bin/env bash
# Benefits (Wave10) end-to-end DB tests via the COBOL binary.
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
db_reset_benefits

# Create a cost center.
create_out="$(run_cobol "BEN_CREATE|BEN-W10-1|EmployeeA|HEALTH|||admin@test.com")"
assert_match "BEN_CREATE ok" "$create_out" "SUCCESS\|BEN_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM benefits WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "BEN_CREATE|BEN-W10-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "BEN_GET ok" "$(run_cobol "BEN_GET|${id}|||||admin@test.com")" "SUCCESS\|BEN_GET\|${id}\|BEN-W10-1"
assert_match "BEN_LIST ok" "$(run_cobol "BEN_LIST|||50|0||admin@test.com")" "BEN-W10-1"

# Allocate.
assert_match "BEN_CALC ok" "$(run_cobol "BEN_CALC|${id}|||||admin@test.com")" "SUCCESS\|BEN_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM benefits WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "BEN_DELETE ok" "$(run_cobol "BEN_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|BEN_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM benefits WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "BEN_SUMMARY ok" "$(run_cobol "BEN_SUMMARY||||||admin@test.com")" "SUCCESS\|BEN_SUMMARY"
assert_match "BEN_AUDIT ok" "$(run_cobol "BEN_AUDIT|50|0||||admin@test.com")" "SUCCESS\|BEN_AUDIT"
assert_match "BEN_VALIDATE ok" "$(run_cobol "BEN_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|BEN_VALID"
assert_match "non-admin refused" "$(run_cobol "BEN_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0