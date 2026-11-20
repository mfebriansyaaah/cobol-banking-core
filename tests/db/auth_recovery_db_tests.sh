#!/usr/bin/env bash
# MFA recovery (PR-5a): request/verify/list/reject with neutral request path.
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
U="arec@test.com"
A="admin@test.com"
db_exec "DELETE FROM mfa_recovery_requests WHERE user_id IN (SELECT id FROM users WHERE email='${U}');"
db_exec "DELETE FROM verification_logs WHERE email='${U}';"
db_exec "DELETE FROM notification_outbox WHERE recipient='${U}';"
db_exec "DELETE FROM users WHERE email='${U}';"
run_cobol "REQUEST_SIGNUP|${U}|Passw0rd!|Rec Test|1990-01-01" >/dev/null
code="$(db_query "SELECT code FROM verification_logs WHERE email='${U}' AND is_used=0 ORDER BY id DESC LIMIT 1;")"
run_cobol "VERIFY_EMAIL|${U}|${code}" >/dev/null

assert_match "request neutral" "$(run_cobol "REQUEST_MFA_RECOVERY|${U}|Passw0rd!||||")" "SUCCESS\|CODE_SENT"
assert_match "request persisted" "$(db_query "SELECT COUNT(*) FROM mfa_recovery_requests WHERE user_id=(SELECT id FROM users WHERE email='${U}') AND state='PENDING';")" "^1$"
rid="$(db_query "SELECT request_id FROM mfa_recovery_requests WHERE user_id=(SELECT id FROM users WHERE email='${U}') ORDER BY request_id DESC LIMIT 1;")"
assert_match "request id present" "$rid" "^[0-9]+$"
rcode="$(db_query "SELECT code FROM verification_logs WHERE email='${U}' AND purpose='MFA_RECOVERY' AND is_used=0 ORDER BY id DESC LIMIT 1;")"
assert_match "recovery code issued" "$rcode" "^[0-9]+$"

assert_match "wrong code refused" "$(run_cobol "VERIFY_MFA_RECOVERY|${U}|000000|||")" "ERROR\|INVALID_CODE"
assert_match "verify ok" "$(run_cobol "VERIFY_MFA_RECOVERY|${U}|${rcode}|||")" "SUCCESS\|RECOVERY_VERIFIED"
assert_match "verified persisted" "$(db_query "SELECT state FROM mfa_recovery_requests WHERE request_id=${rid};")" "^VERIFIED$"
assert_match "list verified" "$(run_cobol "LIST_MFA_RECOVERY|${A}|VERIFIED|50|0||")" "${rid}"
assert_match "list non-admin refused" "$(run_cobol "LIST_MFA_RECOVERY|sender@test.com||50|0||")" "ERROR\|FORBIDDEN"
assert_match "reject ok" "$(run_cobol "REJECT_MFA_RECOVERY|${rid}|${A}||||")" "SUCCESS\|RECOVERY_REJECTED"
assert_match "rejected persisted" "$(db_query "SELECT state FROM mfa_recovery_requests WHERE request_id=${rid};")" "^REJECTED$"
assert_match "double reject refused" "$(run_cobol "REJECT_MFA_RECOVERY|${rid}|${A}||||")" "ERROR\|UNKNOWN_TRANSACTION"

db_exec "DELETE FROM mfa_recovery_requests WHERE user_id IN (SELECT id FROM users WHERE email='${U}');"
db_exec "DELETE FROM verification_logs WHERE email='${U}';"
db_exec "DELETE FROM notification_outbox WHERE recipient='${U}';"
db_exec "DELETE FROM users WHERE email='${U}';"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
