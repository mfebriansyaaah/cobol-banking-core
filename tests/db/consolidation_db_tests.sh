#!/usr/bin/env bash
# Consolidation (D16) end-to-end DB tests via the COBOL binary.
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
db_reset_consolidation

# Create a cost center.
create_out="$(run_cobol "CNS_CREATE|CNS-D16-1|EntityA|GRP|||admin@test.com")"
assert_match "CNS_CREATE ok" "$create_out" "SUCCESS\|CNS_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM consolidation WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "CNS_CREATE|CNS-D16-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "CNS_GET ok" "$(run_cobol "CNS_GET|${id}|||||admin@test.com")" "SUCCESS\|CNS_GET\|${id}\|CNS-D16-1"
assert_match "CNS_LIST ok" "$(run_cobol "CNS_LIST|||50|0||admin@test.com")" "CNS-D16-1"

# Allocate.
assert_match "CNS_CALC ok" "$(run_cobol "CNS_CALC|${id}|||||admin@test.com")" "SUCCESS\|CNS_CALC\|1"
assert_match "posted persisted" "$(db_query "SELECT posted_amount FROM consolidation WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "CNS_DELETE ok" "$(run_cobol "CNS_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|CNS_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM consolidation WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "CNS_SUMMARY ok" "$(run_cobol "CNS_SUMMARY||||||admin@test.com")" "SUCCESS\|CNS_SUMMARY"
assert_match "CNS_AUDIT ok" "$(run_cobol "CNS_AUDIT|50|0||||admin@test.com")" "SUCCESS\|CNS_AUDIT"
assert_match "CNS_VALIDATE ok" "$(run_cobol "CNS_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|CNS_VALID"
assert_match "non-admin refused" "$(run_cobol "CNS_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0