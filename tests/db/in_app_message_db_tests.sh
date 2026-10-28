#!/usr/bin/env bash
# In-app message (Wave11) end-to-end DB tests via the COBOL binary.
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
db_reset_in_app_message

# Create a cost center.
create_out="$(run_cobol "IAM_CREATE|IAM-W11-1|SenderA|CHAT|||admin@test.com")"
assert_match "IAM_CREATE ok" "$create_out" "SUCCESS\|IAM_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM in_app_message WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "IAM_CREATE|IAM-W11-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "IAM_GET ok" "$(run_cobol "IAM_GET|${id}|||||admin@test.com")" "SUCCESS\|IAM_GET\|${id}\|IAM-W11-1"
assert_match "IAM_LIST ok" "$(run_cobol "IAM_LIST|||50|0||admin@test.com")" "IAM-W11-1"

# Allocate.
assert_match "IAM_CALC ok" "$(run_cobol "IAM_CALC|${id}|||||admin@test.com")" "SUCCESS\|IAM_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM in_app_message WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "IAM_DELETE ok" "$(run_cobol "IAM_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|IAM_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM in_app_message WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "IAM_SUMMARY ok" "$(run_cobol "IAM_SUMMARY||||||admin@test.com")" "SUCCESS\|IAM_SUMMARY"
assert_match "IAM_AUDIT ok" "$(run_cobol "IAM_AUDIT|50|0||||admin@test.com")" "SUCCESS\|IAM_AUDIT"
assert_match "IAM_VALIDATE ok" "$(run_cobol "IAM_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|IAM_VALID"
assert_match "non-admin refused" "$(run_cobol "IAM_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0