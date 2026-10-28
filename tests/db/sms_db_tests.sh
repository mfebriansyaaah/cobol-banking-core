#!/usr/bin/env bash
# SMS (Wave11) end-to-end DB tests via the COBOL binary.
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
db_reset_sms

# Create a cost center.
create_out="$(run_cobol "SMS_CREATE|SMS-W11-1|SenderA|GATEWAY|||admin@test.com")"
assert_match "SMS_CREATE ok" "$create_out" "SUCCESS\|SMS_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM sms WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "SMS_CREATE|SMS-W11-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "SMS_GET ok" "$(run_cobol "SMS_GET|${id}|||||admin@test.com")" "SUCCESS\|SMS_GET\|${id}\|SMS-W11-1"
assert_match "SMS_LIST ok" "$(run_cobol "SMS_LIST|||50|0||admin@test.com")" "SMS-W11-1"

# Allocate.
assert_match "SMS_CALC ok" "$(run_cobol "SMS_CALC|${id}|||||admin@test.com")" "SUCCESS\|SMS_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM sms WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "SMS_DELETE ok" "$(run_cobol "SMS_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|SMS_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM sms WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "SMS_SUMMARY ok" "$(run_cobol "SMS_SUMMARY||||||admin@test.com")" "SUCCESS\|SMS_SUMMARY"
assert_match "SMS_AUDIT ok" "$(run_cobol "SMS_AUDIT|50|0||||admin@test.com")" "SUCCESS\|SMS_AUDIT"
assert_match "SMS_VALIDATE ok" "$(run_cobol "SMS_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|SMS_VALID"
assert_match "non-admin refused" "$(run_cobol "SMS_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0