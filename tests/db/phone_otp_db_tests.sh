#!/usr/bin/env bash
# Phone OTP shell coverage (PR-082b): link lifecycle + issue/verify guards.
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
U="otpU@test.com"
db_exec "DELETE FROM otp_challenges WHERE user_id IN (SELECT id FROM users WHERE email='${U}');"
db_exec "DELETE FROM phone_links WHERE user_id IN (SELECT id FROM users WHERE email='${U}');"
db_exec "DELETE FROM users WHERE email='${U}';"
run_cobol "REQUEST_SIGNUP|${U}|Passw0rd!|Otp You|1990-01-01" >/dev/null
code="$(db_query "SELECT code FROM verification_logs WHERE email='${U}' AND is_used=0 ORDER BY id DESC LIMIT 1;")"
run_cobol "VERIFY_EMAIL|${U}|${code}" >/dev/null

# Link lifecycle: begin -> confirm -> confirm replay refused.
assert_match "ISSUE before link refused" "$(run_cobol "OTP_ISSUE|${U}|sms||${U}||")" "ERROR\|PHONE_NOT_LINKED"
begin_out="$(run_cobol "OTP_LINK_BEGIN|${U}|deadbeefcafe1234||${U}||")"
assert_match "LINK_BEGIN ok" "$begin_out" "SUCCESS\|LINK_BEGIN"
token="$(printf '%s' "$begin_out" | awk -F'|' '{print $3}')"
assert_match "token present" "$token" "^[A-Za-z0-9]+$"
assert_match "LINK_CONFIRM ok" "$(run_cobol "OTP_LINK_CONFIRM|${U}|${token}|chat-777|${U}||")" "SUCCESS\|LINK_CONFIRMED"
assert_match "link bound" "$(db_query "SELECT chat_id FROM phone_links WHERE user_id=(SELECT id FROM users WHERE email='${U}');")" "^chat-777$"
assert_match "confirm replay refused" "$(run_cobol "OTP_LINK_CONFIRM|${U}|${token}|chat-777|${U}||")" "ERROR\|INVALID_CODE"
assert_match "wrong token refused" "$(run_cobol "OTP_LINK_CONFIRM|${U}|nope-token|chat-1|${U}||")" "ERROR\|INVALID_CODE"
assert_match "foreign actor refused" "$(run_cobol "OTP_LINK_BEGIN|${U}|deadbeefcafe1234||sender@test.com||")" "ERROR\|FORBIDDEN"

# Issue + verify happy path with burn-after-5.
issue_out="$(run_cobol "OTP_ISSUE|${U}|sms||${U}||")"
assert_match "ISSUE ok" "$issue_out" "SUCCESS\|OTP_ISSUED"
otp="$(db_query "SELECT code FROM otp_challenges WHERE user_id=(SELECT id FROM users WHERE email='${U}') ORDER BY id DESC LIMIT 1;")"
assert_match "otp stored" "$otp" "^[0-9]+$"
assert_match "bad channel refused" "$(run_cobol "OTP_ISSUE|${U}|pigeon||${U}||")" "ERROR\|INVALID_INPUT"
assert_match "VERIFY ok" "$(run_cobol "OTP_VERIFY|${U}|${otp}||${U}||")" "SUCCESS\|OTP_VERIFIED"
assert_match "verified stamped" "$(db_query "SELECT verified_at IS NOT NULL FROM phone_links WHERE user_id=(SELECT id FROM users WHERE email='${U}');")" "^1$"
assert_match "reuse refused" "$(run_cobol "OTP_VERIFY|${U}|${otp}||${U}||")" "ERROR\|INVALID_CODE"

# Five failures burn the challenge.
issue2="$(run_cobol "OTP_ISSUE|${U}|telegram||${U}||")"
assert_match "ISSUE ok (2)" "$issue2" "SUCCESS\|OTP_ISSUED"
for i in 1 2 3 4 5; do
    run_cobol "OTP_VERIFY|${U}|000000||${U}||" >/dev/null
done
assert_match "burned after 5" "$(run_cobol "OTP_VERIFY|${U}|000000||${U}||")" "ERROR\|INVALID_CODE"
assert_match "challenge burned" "$(db_query "SELECT used FROM otp_challenges WHERE user_id=(SELECT id FROM users WHERE email='${U}') ORDER BY id DESC LIMIT 1;")" "^1$"
assert_match "missing refused" "$(run_cobol "OTP_VERIFY|nobody@test.com|123456||nobody@test.com||")" "ERROR\|ACCOUNT_NOT_FOUND"

db_exec "DELETE FROM otp_challenges WHERE user_id IN (SELECT id FROM users WHERE email='${U}');"
db_exec "DELETE FROM phone_links WHERE user_id IN (SELECT id FROM users WHERE email='${U}');"
db_exec "DELETE FROM users WHERE email='${U}';"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
