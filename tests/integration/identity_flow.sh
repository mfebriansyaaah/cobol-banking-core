#!/usr/bin/env bash
# Integration: signup -> NIK -> phone OTP -> KYC approved.
# Proves identity verification is continuous end to end.
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
U="idvflow@test.com"
db_exec "DELETE FROM manual_reviews WHERE user_id IN (SELECT id FROM users WHERE email='${U}');"
db_exec "DELETE FROM identity_verifications WHERE user_id IN (SELECT id FROM users WHERE email='${U}');"
db_exec "DELETE FROM otp_challenges WHERE user_id IN (SELECT id FROM users WHERE email='${U}');"
db_exec "DELETE FROM phone_links WHERE user_id IN (SELECT id FROM users WHERE email='${U}');"
db_exec "DELETE FROM users WHERE email='${U}';"
run_cobol "REQUEST_SIGNUP|${U}|Passw0rd!|Idv Flow|1990-01-01" >/dev/null
code="$(db_query "SELECT code FROM verification_logs WHERE email='${U}' AND is_used=0 ORDER BY id DESC LIMIT 1;")"
run_cobol "VERIFY_EMAIL|${U}|${code}" >/dev/null

echo "=== Identity KYC end-to-end flow ==="
assert_match "nik" "$(run_cobol "IDV_NIK_VALIDATE|${U}|hash|0001|VALID||${U}")" "SUCCESS\|NIK_RECORDED"
begin_out="$(run_cobol "OTP_LINK_BEGIN|${U}|hash||${U}||")"
token="$(printf '%s' "$begin_out" | awk -F'|' '{print $3}')"
assert_match "link" "$(run_cobol "OTP_LINK_CONFIRM|${U}|${token}|chat-flow|${U}||")" "SUCCESS\|LINK_CONFIRMED"
issue_out="$(run_cobol "OTP_ISSUE|${U}|PHONE|KYC_FLOW|${U}|")"
otp="$(printf '%s' "$issue_out" | awk -F'|' '{print $4}')"
assert_match "verify" "$(run_cobol "OTP_VERIFY|${U}|${otp}|KYC_FLOW|${U}|")" "SUCCESS\|OTP_VERIFIED"
assert_match "approved" "$(run_cobol "IDV_APPLY|${U}|||||${U}")" "SUCCESS\|KYC_APPROVED"
assert_match "status" "$(run_cobol "IDV_STATUS|${U}|||||${U}")" "SUCCESS\|KYC_STATUS\|APPROVED"

db_exec "DELETE FROM manual_reviews WHERE user_id IN (SELECT id FROM users WHERE email='${U}');"
db_exec "DELETE FROM identity_verifications WHERE user_id IN (SELECT id FROM users WHERE email='${U}');"
db_exec "DELETE FROM otp_challenges WHERE user_id IN (SELECT id FROM users WHERE email='${U}');"
db_exec "DELETE FROM phone_links WHERE user_id IN (SELECT id FROM users WHERE email='${U}');"
db_exec "DELETE FROM users WHERE email='${U}';"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
