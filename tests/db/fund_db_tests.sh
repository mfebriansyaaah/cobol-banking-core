#!/usr/bin/env bash
# Fund (Wave12) end-to-end DB tests via the COBOL binary.
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
db_reset_fund

# Create a cost center.
create_out="$(run_cobol "FND_CREATE|FND-W12-1|FundA|MUTUAL|||admin@test.com")"
assert_match "FND_CREATE ok" "$create_out" "SUCCESS\|FND_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM fund WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "FND_CREATE|FND-W12-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "FND_GET ok" "$(run_cobol "FND_GET|${id}|||||admin@test.com")" "SUCCESS\|FND_GET\|${id}\|FND-W12-1"
assert_match "FND_LIST ok" "$(run_cobol "FND_LIST|||50|0||admin@test.com")" "FND-W12-1"

# Allocate.
assert_match "FND_CALC ok" "$(run_cobol "FND_CALC|${id}|||||admin@test.com")" "SUCCESS\|FND_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM fund WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "FND_DELETE ok" "$(run_cobol "FND_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|FND_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM fund WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "FND_SUMMARY ok" "$(run_cobol "FND_SUMMARY||||||admin@test.com")" "SUCCESS\|FND_SUMMARY"
assert_match "FND_AUDIT ok" "$(run_cobol "FND_AUDIT|50|0||||admin@test.com")" "SUCCESS\|FND_AUDIT"
assert_match "FND_VALIDATE ok" "$(run_cobol "FND_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|FND_VALID"
assert_match "non-admin refused" "$(run_cobol "FND_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0