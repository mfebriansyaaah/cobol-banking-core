#!/usr/bin/env bash
# Blockchain tracker (Wave6) end-to-end DB tests via the COBOL binary.
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
db_reset_blockchain_tracker

# Create a cost center.
create_out="$(run_cobol "BCT_CREATE|BCT-W6-1|ChainA|ETH|||admin@test.com")"
assert_match "BCT_CREATE ok" "$create_out" "SUCCESS\|BCT_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM blockchain_tracker WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "BCT_CREATE|BCT-W6-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "BCT_GET ok" "$(run_cobol "BCT_GET|${id}|||||admin@test.com")" "SUCCESS\|BCT_GET\|${id}\|BCT-W6-1"
assert_match "BCT_LIST ok" "$(run_cobol "BCT_LIST|||50|0||admin@test.com")" "BCT-W6-1"

# Allocate.
assert_match "BCT_CALC ok" "$(run_cobol "BCT_CALC|${id}|||||admin@test.com")" "SUCCESS\|BCT_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM blockchain_tracker WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "BCT_DELETE ok" "$(run_cobol "BCT_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|BCT_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM blockchain_tracker WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "BCT_SUMMARY ok" "$(run_cobol "BCT_SUMMARY||||||admin@test.com")" "SUCCESS\|BCT_SUMMARY"
assert_match "BCT_AUDIT ok" "$(run_cobol "BCT_AUDIT|50|0||||admin@test.com")" "SUCCESS\|BCT_AUDIT"
assert_match "BCT_VALIDATE ok" "$(run_cobol "BCT_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|BCT_VALID"
assert_match "non-admin refused" "$(run_cobol "BCT_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0