#!/usr/bin/env bash
# Reconciliation (Wave13) end-to-end DB tests via the COBOL binary.
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
db_reset_reconciliation

# Create a cost center.
create_out="$(run_cobol "RECN_CREATE|RECN-W13-1|EntityA|DAILY|||admin@test.com")"
assert_match "RECN_CREATE ok" "$create_out" "SUCCESS\|RECN_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM reconciliation WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "RECN_CREATE|RECN-W13-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "RECN_GET ok" "$(run_cobol "RECN_GET|${id}|||||admin@test.com")" "SUCCESS\|RECN_GET\|${id}\|RECN-W13-1"
assert_match "RECN_LIST ok" "$(run_cobol "RECN_LIST|||50|0||admin@test.com")" "RECN-W13-1"

# Allocate.
assert_match "RECN_CALC ok" "$(run_cobol "RECN_CALC|${id}|||||admin@test.com")" "SUCCESS\|RECN_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM reconciliation WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "RECN_DELETE ok" "$(run_cobol "RECN_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|RECN_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM reconciliation WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "RECN_SUMMARY ok" "$(run_cobol "RECN_SUMMARY||||||admin@test.com")" "SUCCESS\|RECN_SUMMARY"
assert_match "RECN_AUDIT ok" "$(run_cobol "RECN_AUDIT|50|0||||admin@test.com")" "SUCCESS\|RECN_AUDIT"
assert_match "RECN_VALIDATE ok" "$(run_cobol "RECN_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|RECN_VALID"
assert_match "non-admin refused" "$(run_cobol "RECN_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0