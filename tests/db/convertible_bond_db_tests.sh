#!/usr/bin/env bash
# Convertible bond (Wave12) end-to-end DB tests via the COBOL binary.
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
db_reset_convertible_bond

# Create a cost center.
create_out="$(run_cobol "CVB_CREATE|CVB-W12-1|BondA|CONVERTIBLE|||admin@test.com")"
assert_match "CVB_CREATE ok" "$create_out" "SUCCESS\|CVB_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM convertible_bond WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "CVB_CREATE|CVB-W12-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "CVB_GET ok" "$(run_cobol "CVB_GET|${id}|||||admin@test.com")" "SUCCESS\|CVB_GET\|${id}\|CVB-W12-1"
assert_match "CVB_LIST ok" "$(run_cobol "CVB_LIST|||50|0||admin@test.com")" "CVB-W12-1"

# Allocate.
assert_match "CVB_CALC ok" "$(run_cobol "CVB_CALC|${id}|||||admin@test.com")" "SUCCESS\|CVB_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM convertible_bond WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "CVB_DELETE ok" "$(run_cobol "CVB_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|CVB_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM convertible_bond WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "CVB_SUMMARY ok" "$(run_cobol "CVB_SUMMARY||||||admin@test.com")" "SUCCESS\|CVB_SUMMARY"
assert_match "CVB_AUDIT ok" "$(run_cobol "CVB_AUDIT|50|0||||admin@test.com")" "SUCCESS\|CVB_AUDIT"
assert_match "CVB_VALIDATE ok" "$(run_cobol "CVB_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|CVB_VALID"
assert_match "non-admin refused" "$(run_cobol "CVB_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0