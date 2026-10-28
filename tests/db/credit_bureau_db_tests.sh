#!/usr/bin/env bash
# Credit bureau (Wave7) end-to-end DB tests via the COBOL binary.
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
db_reset_credit_bureau

# Create a cost center.
create_out="$(run_cobol "CBU_CREATE|CBU-W7-1|BureauA|REPORT|||admin@test.com")"
assert_match "CBU_CREATE ok" "$create_out" "SUCCESS\|CBU_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM credit_bureau WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "CBU_CREATE|CBU-W7-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "CBU_GET ok" "$(run_cobol "CBU_GET|${id}|||||admin@test.com")" "SUCCESS\|CBU_GET\|${id}\|CBU-W7-1"
assert_match "CBU_LIST ok" "$(run_cobol "CBU_LIST|||50|0||admin@test.com")" "CBU-W7-1"

# Allocate.
assert_match "CBU_CALC ok" "$(run_cobol "CBU_CALC|${id}|||||admin@test.com")" "SUCCESS\|CBU_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM credit_bureau WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "CBU_DELETE ok" "$(run_cobol "CBU_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|CBU_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM credit_bureau WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "CBU_SUMMARY ok" "$(run_cobol "CBU_SUMMARY||||||admin@test.com")" "SUCCESS\|CBU_SUMMARY"
assert_match "CBU_AUDIT ok" "$(run_cobol "CBU_AUDIT|50|0||||admin@test.com")" "SUCCESS\|CBU_AUDIT"
assert_match "CBU_VALIDATE ok" "$(run_cobol "CBU_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|CBU_VALID"
assert_match "non-admin refused" "$(run_cobol "CBU_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0