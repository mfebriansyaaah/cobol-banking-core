#!/usr/bin/env bash
# Registration (Wave17) end-to-end DB tests via the COBOL binary.
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
db_reset_registration

# Create a cost center.
create_out="$(run_cobol "REGN_CREATE|REGN-W17-1|EntityA|BUSINESS|||admin@test.com")"
assert_match "REGN_CREATE ok" "$create_out" "SUCCESS\|REGN_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM registration WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "REGN_CREATE|REGN-W17-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "REGN_GET ok" "$(run_cobol "REGN_GET|${id}|||||admin@test.com")" "SUCCESS\|REGN_GET\|${id}\|REGN-W17-1"
assert_match "REGN_LIST ok" "$(run_cobol "REGN_LIST|||50|0||admin@test.com")" "REGN-W17-1"

# Allocate.
assert_match "REGN_CALC ok" "$(run_cobol "REGN_CALC|${id}|||||admin@test.com")" "SUCCESS\|REGN_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM registration WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "REGN_DELETE ok" "$(run_cobol "REGN_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|REGN_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM registration WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "REGN_SUMMARY ok" "$(run_cobol "REGN_SUMMARY||||||admin@test.com")" "SUCCESS\|REGN_SUMMARY"
assert_match "REGN_AUDIT ok" "$(run_cobol "REGN_AUDIT|50|0||||admin@test.com")" "SUCCESS\|REGN_AUDIT"
assert_match "REGN_VALIDATE ok" "$(run_cobol "REGN_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|REGN_VALID"
assert_match "non-admin refused" "$(run_cobol "REGN_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0