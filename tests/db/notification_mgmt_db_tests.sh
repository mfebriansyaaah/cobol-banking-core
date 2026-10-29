#!/usr/bin/env bash
# Notification mgmt (Wave17) end-to-end DB tests via the COBOL binary.
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
db_reset_notification_mgmt

# Create a cost center.
create_out="$(run_cobol "NTFC_CREATE|NTFC-W17-1|RecipientA|EMAIL|||admin@test.com")"
assert_match "NTFC_CREATE ok" "$create_out" "SUCCESS\|NTFC_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM notification_mgmt WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "NTFC_CREATE|NTFC-W17-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "NTFC_GET ok" "$(run_cobol "NTFC_GET|${id}|||||admin@test.com")" "SUCCESS\|NTFC_GET\|${id}\|NTFC-W17-1"
assert_match "NTFC_LIST ok" "$(run_cobol "NTFC_LIST|||50|0||admin@test.com")" "NTFC-W17-1"

# Allocate.
assert_match "NTFC_CALC ok" "$(run_cobol "NTFC_CALC|${id}|||||admin@test.com")" "SUCCESS\|NTFC_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM notification_mgmt WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "NTFC_DELETE ok" "$(run_cobol "NTFC_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|NTFC_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM notification_mgmt WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "NTFC_SUMMARY ok" "$(run_cobol "NTFC_SUMMARY||||||admin@test.com")" "SUCCESS\|NTFC_SUMMARY"
assert_match "NTFC_AUDIT ok" "$(run_cobol "NTFC_AUDIT|50|0||||admin@test.com")" "SUCCESS\|NTFC_AUDIT"
assert_match "NTFC_VALIDATE ok" "$(run_cobol "NTFC_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|NTFC_VALID"
assert_match "non-admin refused" "$(run_cobol "NTFC_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0