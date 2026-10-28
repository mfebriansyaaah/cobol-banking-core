#!/usr/bin/env bash
# Insurance policy (Wave7) end-to-end DB tests via the COBOL binary.
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
db_reset_insurance_policy

# Create a cost center.
create_out="$(run_cobol "ISP_CREATE|ISP-W7-1|PolicyA|LIFE|||admin@test.com")"
assert_match "ISP_CREATE ok" "$create_out" "SUCCESS\|ISP_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM insurance_policy WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "ISP_CREATE|ISP-W7-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "ISP_GET ok" "$(run_cobol "ISP_GET|${id}|||||admin@test.com")" "SUCCESS\|ISP_GET\|${id}\|ISP-W7-1"
assert_match "ISP_LIST ok" "$(run_cobol "ISP_LIST|||50|0||admin@test.com")" "ISP-W7-1"

# Allocate.
assert_match "ISP_CALC ok" "$(run_cobol "ISP_CALC|${id}|||||admin@test.com")" "SUCCESS\|ISP_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM insurance_policy WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "ISP_DELETE ok" "$(run_cobol "ISP_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|ISP_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM insurance_policy WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "ISP_SUMMARY ok" "$(run_cobol "ISP_SUMMARY||||||admin@test.com")" "SUCCESS\|ISP_SUMMARY"
assert_match "ISP_AUDIT ok" "$(run_cobol "ISP_AUDIT|50|0||||admin@test.com")" "SUCCESS\|ISP_AUDIT"
assert_match "ISP_VALIDATE ok" "$(run_cobol "ISP_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|ISP_VALID"
assert_match "non-admin refused" "$(run_cobol "ISP_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0