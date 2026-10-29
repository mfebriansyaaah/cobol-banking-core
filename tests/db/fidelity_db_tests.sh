#!/usr/bin/env bash
# Fidelity (Wave18) end-to-end DB tests via the COBOL binary.
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
db_reset_fidelity

# Create a cost center.
create_out="$(run_cobol "FDL_CREATE|FDL-W18-1|InsuredA|EMPLOYEE|||admin@test.com")"
assert_match "FDL_CREATE ok" "$create_out" "SUCCESS\|FDL_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM fidelity WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "FDL_CREATE|FDL-W18-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "FDL_GET ok" "$(run_cobol "FDL_GET|${id}|||||admin@test.com")" "SUCCESS\|FDL_GET\|${id}\|FDL-W18-1"
assert_match "FDL_LIST ok" "$(run_cobol "FDL_LIST|||50|0||admin@test.com")" "FDL-W18-1"

# Allocate.
assert_match "FDL_CALC ok" "$(run_cobol "FDL_CALC|${id}|||||admin@test.com")" "SUCCESS\|FDL_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM fidelity WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "FDL_DELETE ok" "$(run_cobol "FDL_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|FDL_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM fidelity WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "FDL_SUMMARY ok" "$(run_cobol "FDL_SUMMARY||||||admin@test.com")" "SUCCESS\|FDL_SUMMARY"
assert_match "FDL_AUDIT ok" "$(run_cobol "FDL_AUDIT|50|0||||admin@test.com")" "SUCCESS\|FDL_AUDIT"
assert_match "FDL_VALIDATE ok" "$(run_cobol "FDL_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|FDL_VALID"
assert_match "non-admin refused" "$(run_cobol "FDL_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0