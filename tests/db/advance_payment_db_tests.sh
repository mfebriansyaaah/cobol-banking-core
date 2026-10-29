#!/usr/bin/env bash
# Advance payment (Wave16) end-to-end DB tests via the COBOL binary.
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
db_reset_advance_payment

# Create a cost center.
create_out="$(run_cobol "APYM_CREATE|APYM-W16-1|PayerA|MILESTONE|||admin@test.com")"
assert_match "APYM_CREATE ok" "$create_out" "SUCCESS\|APYM_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM advance_payment WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "APYM_CREATE|APYM-W16-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "APYM_GET ok" "$(run_cobol "APYM_GET|${id}|||||admin@test.com")" "SUCCESS\|APYM_GET\|${id}\|APYM-W16-1"
assert_match "APYM_LIST ok" "$(run_cobol "APYM_LIST|||50|0||admin@test.com")" "APYM-W16-1"

# Allocate.
assert_match "APYM_CALC ok" "$(run_cobol "APYM_CALC|${id}|||||admin@test.com")" "SUCCESS\|APYM_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM advance_payment WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "APYM_DELETE ok" "$(run_cobol "APYM_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|APYM_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM advance_payment WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "APYM_SUMMARY ok" "$(run_cobol "APYM_SUMMARY||||||admin@test.com")" "SUCCESS\|APYM_SUMMARY"
assert_match "APYM_AUDIT ok" "$(run_cobol "APYM_AUDIT|50|0||||admin@test.com")" "SUCCESS\|APYM_AUDIT"
assert_match "APYM_VALIDATE ok" "$(run_cobol "APYM_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|APYM_VALID"
assert_match "non-admin refused" "$(run_cobol "APYM_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0