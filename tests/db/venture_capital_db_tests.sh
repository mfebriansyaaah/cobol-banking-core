#!/usr/bin/env bash
# Venture capital (Wave12) end-to-end DB tests via the COBOL binary.
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
db_reset_venture_capital

# Create a cost center.
create_out="$(run_cobol "VCP_CREATE|VCP-W12-1|FundA|EARLY_STAGE|||admin@test.com")"
assert_match "VCP_CREATE ok" "$create_out" "SUCCESS\|VCP_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM venture_capital WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "VCP_CREATE|VCP-W12-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "VCP_GET ok" "$(run_cobol "VCP_GET|${id}|||||admin@test.com")" "SUCCESS\|VCP_GET\|${id}\|VCP-W12-1"
assert_match "VCP_LIST ok" "$(run_cobol "VCP_LIST|||50|0||admin@test.com")" "VCP-W12-1"

# Allocate.
assert_match "VCP_CALC ok" "$(run_cobol "VCP_CALC|${id}|||||admin@test.com")" "SUCCESS\|VCP_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM venture_capital WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "VCP_DELETE ok" "$(run_cobol "VCP_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|VCP_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM venture_capital WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "VCP_SUMMARY ok" "$(run_cobol "VCP_SUMMARY||||||admin@test.com")" "SUCCESS\|VCP_SUMMARY"
assert_match "VCP_AUDIT ok" "$(run_cobol "VCP_AUDIT|50|0||||admin@test.com")" "SUCCESS\|VCP_AUDIT"
assert_match "VCP_VALIDATE ok" "$(run_cobol "VCP_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|VCP_VALID"
assert_match "non-admin refused" "$(run_cobol "VCP_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0