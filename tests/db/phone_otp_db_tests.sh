#!/usr/bin/env bash
# OTP mechanics shell coverage (PR-082b/085): resend, rate limit, lockout,
# hashed-at-rest, wrong-channel guards. KYC-integrated flow lives in
# identity_db_tests.sh.
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
U="otpM@test.com"
db_exec "DELETE FROM otp_challenges WHERE user_id IN (SELECT id FROM users WHERE email='${U}');"
db_exec "DELETE FROM phone_links WHERE user_id IN (SELECT id FROM users WHERE email='${U}');"
db_exec "DELETE FROM users WHERE email='${U}';"
run_cobol "REQUEST_SIGNUP|${U}|Passw0rd!|Otp Em|1990-01-01" >/dev/null
code="$(db_query "SELECT code FROM verification_logs WHERE email='${U}' AND is_used=0 ORDER BY id DESC LIMIT 1;")"
run_cobol "VERIFY_EMAIL|${U}|${code}" >/dev/null
run_cobol "OTP_LINK_BEGIN|${U}|hashm||${U}||" >/dev/null

# Issue is rate-limited: 3 live per purpose per 10 minutes.
assert_match "ISSUE 1 ok" "$(run_cobol "OTP_ISSUE|${U}|PHONE|M_PURPOSE|${U}|")" "SUCCESS\|OTP_ISSUED"
assert_match "ISSUE 2 ok" "$(run_cobol "OTP_ISSUE|${U}|PHONE|M_PURPOSE|${U}|")" "SUCCESS\|OTP_ISSUED"
assert_match "ISSUE 3 ok" "$(run_cobol "OTP_ISSUE|${U}|PHONE|M_PURPOSE|${U}|")" "SUCCESS\|OTP_ISSUED"
assert_match "ISSUE 4 refused" "$(run_cobol "OTP_ISSUE|${U}|PHONE|M_PURPOSE|${U}|")" "ERROR\|RATE_LIMITED"
assert_match "live count" "$(db_query "SELECT COUNT(*) FROM otp_challenges WHERE user_id=(SELECT id FROM users WHERE email='${U}') AND status='PENDING';")" "^3$"

# Codes hashed at rest (64-hex, never the plaintext).
assert_match "hash shape" "$(db_query "SELECT code_hash FROM otp_challenges WHERE user_id=(SELECT id FROM users WHERE email='${U}') ORDER BY id DESC LIMIT 1;")" "^[0-9a-f]{64}$"

# Resend expires the live ones and issues fresh (still under the cap:
# resend counts live rows first, so drain one via verify... instead use a
# fresh purpose to observe the resend path cleanly).
issue_r="$(run_cobol "OTP_ISSUE|${U}|PHONE|R_PURPOSE|${U}|")"
assert_match "ISSUE ok (resend purpose)" "$issue_r" "SUCCESS\|OTP_ISSUED"
assert_match "RESEND ok" "$(run_cobol "OTP_RESEND|${U}||R_PURPOSE|${U}|")" "SUCCESS\|OTP_ISSUED"
assert_match "old expired" "$(db_query "SELECT COUNT(*) FROM otp_challenges WHERE user_id=(SELECT id FROM users WHERE email='${U}') AND purpose='R_PURPOSE' AND status='EXPIRED';")" "^[1-9][0-9]*$"
assert_match "one live" "$(db_query "SELECT COUNT(*) FROM otp_challenges WHERE user_id=(SELECT id FROM users WHERE email='${U}') AND purpose='R_PURPOSE' AND status='PENDING';")" "^1$"

# Wrong channel refused; unknown user refused; foreign actor refused.
assert_match "bad channel refused" "$(run_cobol "OTP_ISSUE|${U}|pigeon|M_PURPOSE|${U}|")" "ERROR\|INVALID_INPUT"
assert_match "missing refused" "$(run_cobol "OTP_ISSUE|nobody@test.com|PHONE|M_PURPOSE|nobody@test.com|")" "ERROR\|ACCOUNT_NOT_FOUND"
assert_match "foreign refused" "$(run_cobol "OTP_ISSUE|${U}|PHONE|M_PURPOSE|sender@test.com|")" "ERROR\|FORBIDDEN"

# Lockout: 5 failures lock the newest challenge.
for i in 1 2 3 4 5; do
    run_cobol "OTP_VERIFY|${U}|000000|M_PURPOSE|${U}|" >/dev/null
done
assert_match "locked" "$(db_query "SELECT status FROM otp_challenges WHERE user_id=(SELECT id FROM users WHERE email='${U}') AND purpose='M_PURPOSE' ORDER BY id DESC LIMIT 1;")" "^LOCKED$"
assert_match "locked verify refused" "$(run_cobol "OTP_VERIFY|${U}|000000|M_PURPOSE|${U}|")" "ERROR\|INVALID_CODE"

# Chat lookup for server-side delivery: no verified link yet.
assert_match "chat missing" "$(run_cobol "OTP_CHAT|${U}|||${U}||")" "ERROR\|NOT_FOUND"
assert_match "chat foreign refused" "$(run_cobol "OTP_CHAT|${U}|||sender@test.com||")" "ERROR\|FORBIDDEN"
# Confirm the link, then the verified chat_id is returned (never via HTTP).
begin_out="$(run_cobol "OTP_LINK_BEGIN|${U}|aaaabbbbccccddddaaaabbbbccccddddaaaabbbbccccddddaaaabbbbccccdddd||${U}||")"
token="$(printf '%s' "$begin_out" | awk -F'|' '{print $3}')"
run_cobol "OTP_LINK_CONFIRM|${U}|${token}|chat-otp-1|${U}||" >/dev/null
assert_match "chat ok" "$(run_cobol "OTP_CHAT|${U}|||${U}||")" "SUCCESS\|CHAT\|chat-otp-1\|[0-9a-f]{64}"

db_exec "DELETE FROM otp_challenges WHERE user_id IN (SELECT id FROM users WHERE email='${U}');"
db_exec "DELETE FROM phone_links WHERE user_id IN (SELECT id FROM users WHERE email='${U}');"
db_exec "DELETE FROM users WHERE email='${U}';"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
