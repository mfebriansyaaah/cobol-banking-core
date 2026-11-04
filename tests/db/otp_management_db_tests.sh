#!/usr/bin/env bash
# OTP management (Wave8) end-to-end DB tests via the COBOL binary.
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
db_reset_otp_management

# Create a cost center.
create_out="$(run_cobol "OTP_CREATE|OTP-W8-1|UserA|SMS|||admin@test.com")"
assert_match "OTP_CREATE ok" "$create_out" "SUCCESS\|OTP_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM otp_management WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "OTP_CREATE|OTP-W8-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "OTP_GET ok" "$(run_cobol "OTP_GET|${id}|||||admin@test.com")" "SUCCESS\|OTP_GET\|${id}\|OTP-W8-1"
assert_match "OTP_LIST ok" "$(run_cobol "OTP_LIST|||50|0||admin@test.com")" "OTP-W8-1"

# Allocate.
assert_match "OTP_CALC ok" "$(run_cobol "OTP_CALC|${id}|||||admin@test.com")" "SUCCESS\|OTP_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM otp_management WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "OTP_DELETE ok" "$(run_cobol "OTP_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|OTP_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM otp_management WHERE id=${id};")" "^EXPIRED$"

# Summary and audit.
assert_match "OTP_SUMMARY ok" "$(run_cobol "OTP_SUMMARY||||||admin@test.com")" "SUCCESS\|OTP_SUMMARY"
assert_match "OTP_AUDIT ok" "$(run_cobol "OTP_AUDIT|50|0||||admin@test.com")" "SUCCESS\|OTP_AUDIT"
assert_match "OTP_VALIDATE ok" "$(run_cobol "OTP_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|OTP_VALID"
assert_match "non-admin refused" "$(run_cobol "OTP_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"


# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM otp_management WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM otp_management_audit WHERE otp_management_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "OTP_UPDATE|${id}|UserA|SMS|||admin@test.com")"
assert_match "OTP_UPDATE ok" "$upd_out" "SUCCESS\\|OTP_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM otp_management WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM otp_management_audit WHERE otp_management_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "OTP_UPDATE|999999|UserA|SMS|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "OTP_UPDATE|${id}|UserA|SMS|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0