#!/usr/bin/env bash
# Core banking (Wave20) end-to-end DB tests via the COBOL binary.
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
db_reset_core_banking

# Create a cost center.
create_out="$(run_cobol "CBKG_CREATE|CBKG-W20-1|BankA|RETAIL|||admin@test.com")"
assert_match "CBKG_CREATE ok" "$create_out" "SUCCESS\|CBKG_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM core_banking WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "CBKG_CREATE|CBKG-W20-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "CBKG_GET ok" "$(run_cobol "CBKG_GET|${id}|||||admin@test.com")" "SUCCESS\|CBKG_GET\|${id}\|CBKG-W20-1"
assert_match "CBKG_LIST ok" "$(run_cobol "CBKG_LIST|||50|0||admin@test.com")" "CBKG-W20-1"

# Allocate.
assert_match "CBKG_CALC ok" "$(run_cobol "CBKG_CALC|${id}|||||admin@test.com")" "SUCCESS\|CBKG_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM core_banking WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "CBKG_DELETE ok" "$(run_cobol "CBKG_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|CBKG_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM core_banking WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "CBKG_SUMMARY ok" "$(run_cobol "CBKG_SUMMARY||||||admin@test.com")" "SUCCESS\|CBKG_SUMMARY"
assert_match "CBKG_AUDIT ok" "$(run_cobol "CBKG_AUDIT|50|0||||admin@test.com")" "SUCCESS\|CBKG_AUDIT"
assert_match "CBKG_VALIDATE ok" "$(run_cobol "CBKG_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|CBKG_VALID"
assert_match "non-admin refused" "$(run_cobol "CBKG_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0