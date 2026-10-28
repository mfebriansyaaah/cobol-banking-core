#!/usr/bin/env bash
# Index mgmt (Wave14) end-to-end DB tests via the COBOL binary.
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
db_reset_index_mgmt

# Create a cost center.
create_out="$(run_cobol "IDXX_CREATE|IDXX-W14-1|IndexA|COMPOSITE|||admin@test.com")"
assert_match "IDXX_CREATE ok" "$create_out" "SUCCESS\|IDXX_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM index_mgmt WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "IDXX_CREATE|IDXX-W14-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "IDXX_GET ok" "$(run_cobol "IDXX_GET|${id}|||||admin@test.com")" "SUCCESS\|IDXX_GET\|${id}\|IDXX-W14-1"
assert_match "IDXX_LIST ok" "$(run_cobol "IDXX_LIST|||50|0||admin@test.com")" "IDXX-W14-1"

# Allocate.
assert_match "IDXX_CALC ok" "$(run_cobol "IDXX_CALC|${id}|||||admin@test.com")" "SUCCESS\|IDXX_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM index_mgmt WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "IDXX_DELETE ok" "$(run_cobol "IDXX_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|IDXX_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM index_mgmt WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "IDXX_SUMMARY ok" "$(run_cobol "IDXX_SUMMARY||||||admin@test.com")" "SUCCESS\|IDXX_SUMMARY"
assert_match "IDXX_AUDIT ok" "$(run_cobol "IDXX_AUDIT|50|0||||admin@test.com")" "SUCCESS\|IDXX_AUDIT"
assert_match "IDXX_VALIDATE ok" "$(run_cobol "IDXX_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|IDXX_VALID"
assert_match "non-admin refused" "$(run_cobol "IDXX_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0