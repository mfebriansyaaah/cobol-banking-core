#!/usr/bin/env bash
# Bankers acceptance (Wave16) end-to-end DB tests via the COBOL binary.
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
db_reset_bankers_acceptance

# Create a cost center.
create_out="$(run_cobol "BAC_CREATE|BAC-W16-1|DrawerA|TIME|||admin@test.com")"
assert_match "BAC_CREATE ok" "$create_out" "SUCCESS\|BAC_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM bankers_acceptance WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "BAC_CREATE|BAC-W16-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "BAC_GET ok" "$(run_cobol "BAC_GET|${id}|||||admin@test.com")" "SUCCESS\|BAC_GET\|${id}\|BAC-W16-1"
assert_match "BAC_LIST ok" "$(run_cobol "BAC_LIST|||50|0||admin@test.com")" "BAC-W16-1"

# Allocate.
assert_match "BAC_CALC ok" "$(run_cobol "BAC_CALC|${id}|||||admin@test.com")" "SUCCESS\|BAC_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM bankers_acceptance WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "BAC_DELETE ok" "$(run_cobol "BAC_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|BAC_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM bankers_acceptance WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "BAC_SUMMARY ok" "$(run_cobol "BAC_SUMMARY||||||admin@test.com")" "SUCCESS\|BAC_SUMMARY"
assert_match "BAC_AUDIT ok" "$(run_cobol "BAC_AUDIT|50|0||||admin@test.com")" "SUCCESS\|BAC_AUDIT"
assert_match "BAC_VALIDATE ok" "$(run_cobol "BAC_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|BAC_VALID"
assert_match "non-admin refused" "$(run_cobol "BAC_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0