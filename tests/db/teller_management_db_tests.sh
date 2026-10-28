#!/usr/bin/env bash
# Teller management (Wave6) end-to-end DB tests via the COBOL binary.
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
db_reset_teller_management

# Create a cost center.
create_out="$(run_cobol "TLR_CREATE|TLR-W6-1|TellerA|SENIOR|||admin@test.com")"
assert_match "TLR_CREATE ok" "$create_out" "SUCCESS\|TLR_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM teller_management WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "TLR_CREATE|TLR-W6-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "TLR_GET ok" "$(run_cobol "TLR_GET|${id}|||||admin@test.com")" "SUCCESS\|TLR_GET\|${id}\|TLR-W6-1"
assert_match "TLR_LIST ok" "$(run_cobol "TLR_LIST|||50|0||admin@test.com")" "TLR-W6-1"

# Allocate.
assert_match "TLR_CALC ok" "$(run_cobol "TLR_CALC|${id}|||||admin@test.com")" "SUCCESS\|TLR_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM teller_management WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "TLR_DELETE ok" "$(run_cobol "TLR_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|TLR_DELETE"
assert_match "inactive persisted" "$(db_query "SELECT status FROM teller_management WHERE id=${id};")" "^INACTIVE$"

# Summary and audit.
assert_match "TLR_SUMMARY ok" "$(run_cobol "TLR_SUMMARY||||||admin@test.com")" "SUCCESS\|TLR_SUMMARY"
assert_match "TLR_AUDIT ok" "$(run_cobol "TLR_AUDIT|50|0||||admin@test.com")" "SUCCESS\|TLR_AUDIT"
assert_match "TLR_VALIDATE ok" "$(run_cobol "TLR_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|TLR_VALID"
assert_match "non-admin refused" "$(run_cobol "TLR_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0