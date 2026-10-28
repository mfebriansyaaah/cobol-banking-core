#!/usr/bin/env bash
# Recurring deposit (Wave9) end-to-end DB tests via the COBOL binary.
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
db_reset_recurring_deposit

# Create a cost center.
create_out="$(run_cobol "RDP_CREATE|RDP-W9-1|DepositorA|RD|||admin@test.com")"
assert_match "RDP_CREATE ok" "$create_out" "SUCCESS\|RDP_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM recurring_deposit WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "RDP_CREATE|RDP-W9-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "RDP_GET ok" "$(run_cobol "RDP_GET|${id}|||||admin@test.com")" "SUCCESS\|RDP_GET\|${id}\|RDP-W9-1"
assert_match "RDP_LIST ok" "$(run_cobol "RDP_LIST|||50|0||admin@test.com")" "RDP-W9-1"

# Allocate.
assert_match "RDP_CALC ok" "$(run_cobol "RDP_CALC|${id}|||||admin@test.com")" "SUCCESS\|RDP_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM recurring_deposit WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "RDP_DELETE ok" "$(run_cobol "RDP_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|RDP_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM recurring_deposit WHERE id=${id};")" "^MATURED$"

# Summary and audit.
assert_match "RDP_SUMMARY ok" "$(run_cobol "RDP_SUMMARY||||||admin@test.com")" "SUCCESS\|RDP_SUMMARY"
assert_match "RDP_AUDIT ok" "$(run_cobol "RDP_AUDIT|50|0||||admin@test.com")" "SUCCESS\|RDP_AUDIT"
assert_match "RDP_VALIDATE ok" "$(run_cobol "RDP_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|RDP_VALID"
assert_match "non-admin refused" "$(run_cobol "RDP_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0