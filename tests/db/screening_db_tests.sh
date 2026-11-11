#!/usr/bin/env bash
# Sanctions/PEP screening (PR-090): verdict recording, fail-closed provider
# mapping, reviewer-only confirm/false-positive, APPLY screening gate.
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
A="admin@test.com"
U="scrU@test.com"
V="scrV@test.com"
cleanup() {
    db_exec "DELETE FROM screening_checks WHERE user_id IN (SELECT id FROM users WHERE email IN ('${U}','${V}'));"
    db_exec "DELETE FROM manual_reviews WHERE user_id IN (SELECT id FROM users WHERE email IN ('${U}','${V}'));"
    db_exec "DELETE FROM identity_verifications WHERE user_id IN (SELECT id FROM users WHERE email IN ('${U}','${V}'));"
    db_exec "DELETE FROM otp_challenges WHERE user_id IN (SELECT id FROM users WHERE email IN ('${U}','${V}'));"
    db_exec "DELETE FROM phone_links WHERE user_id IN (SELECT id FROM users WHERE email IN ('${U}','${V}'));"
    db_exec "DELETE FROM users WHERE email IN ('${U}','${V}');"
}
cleanup
for E in "$U" "$V"; do
    run_cobol "REQUEST_SIGNUP|${E}|Passw0rd!|Scr You|1990-01-01" >/dev/null
    code="$(db_query "SELECT code FROM verification_logs WHERE email='${E}' AND is_used=0 ORDER BY id DESC LIMIT 1;")"
    run_cobol "VERIFY_EMAIL|${E}|${code}" >/dev/null
done

assert_match "status unscreened" "$(run_cobol "SCR_STATUS|${U}|||||${U}")" "SUCCESS\|SCREEN_STATUS\|UNSCREENED"
assert_match "bad verdict refused" "$(run_cobol "SCR_SCREEN|${U}|q|MAYBE|opensanctions|r|${U}")" "ERROR\|INVALID_INPUT"
assert_match "missing user refused" "$(run_cobol "SCR_SCREEN|nobody@test.com|q|CLEAR|opensanctions|r|nobody@test.com")" "ERROR\|ACCOUNT_NOT_FOUND"
assert_match "foreign actor refused" "$(run_cobol "SCR_SCREEN|${U}|q|CLEAR|opensanctions|r|sender@test.com")" "ERROR\|FORBIDDEN"
assert_match "stranger cannot read" "$(run_cobol "SCR_STATUS|${U}|||||sender@test.com")" "ERROR\|FORBIDDEN"
assert_match "admin can read" "$(run_cobol "SCR_STATUS|${U}|||||${A}")" "SUCCESS\|SCREEN_STATUS\|UNSCREENED"

# Complete NIK + phone so only the screening gate remains.
assert_match "NIK valid" "$(run_cobol "IDV_NIK_VALIDATE|${U}|hash|0001|VALID||${U}")" "SUCCESS\|NIK_RECORDED"
begin_out="$(run_cobol "OTP_LINK_BEGIN|${U}|hash||${U}||")"
token="$(printf '%s' "$begin_out" | awk -F'|' '{print $3}')"
run_cobol "OTP_LINK_CONFIRM|${U}|${token}|chat-scr|${U}||" >/dev/null
issue_out="$(run_cobol "OTP_ISSUE|${U}|PHONE|SCR_PURPOSE|${U}|")"
otp="$(printf '%s' "$issue_out" | awk -F'|' '{print $4}')"
run_cobol "OTP_VERIFY|${U}|${otp}|SCR_PURPOSE|${U}|" >/dev/null
assert_match "APPLY names screening" "$(run_cobol "IDV_APPLY|${U}|||||${U}")" "SUCCESS\|KYC_PENDING\|SCREENING"

assert_match "CLEAR recorded" "$(run_cobol "SCR_SCREEN|${U}|qhash1|CLEAR|opensanctions|ref1|${U}")" "SUCCESS\|SCREEN_RECORDED"
assert_match "status clear" "$(run_cobol "SCR_STATUS|${U}|||||${U}")" "SUCCESS\|SCREEN_STATUS\|CLEAR"
assert_match "no review for clear" "$(db_query "SELECT COUNT(*) FROM manual_reviews WHERE user_id=(SELECT id FROM users WHERE email='${U}');")" "^0$"
assert_match "APPLY approves" "$(run_cobol "IDV_APPLY|${U}|||||${U}")" "SUCCESS\|KYC_APPROVED"

# Adverse path on a second user (approval is sticky by design; post-approval
# adverse info goes to review + suspension, not silent un-approval).
assert_match "V NIK valid" "$(run_cobol "IDV_NIK_VALIDATE|${V}|hash|0002|VALID||${V}")" "SUCCESS\|NIK_RECORDED"
begin_v="$(run_cobol "OTP_LINK_BEGIN|${V}|hash||${V}||")"
token_v="$(printf '%s' "$begin_v" | awk -F'|' '{print $3}')"
run_cobol "OTP_LINK_CONFIRM|${V}|${token_v}|chat-scrv|${V}||" >/dev/null
issue_v="$(run_cobol "OTP_ISSUE|${V}|PHONE|SCR_PURPOSE|${V}|")"
otp_v="$(printf '%s' "$issue_v" | awk -F'|' '{print $4}')"
run_cobol "OTP_VERIFY|${V}|${otp_v}|SCR_PURPOSE|${V}|" >/dev/null
assert_match "match recorded" "$(run_cobol "SCR_SCREEN|${V}|qhash2|POTENTIAL_MATCH|opensanctions|ref2|${V}")" "SUCCESS\|SCREEN_RECORDED"
assert_match "review opened" "$(db_query "SELECT COUNT(*) FROM manual_reviews WHERE user_id=(SELECT id FROM users WHERE email='${V}') AND kind='SCREENING' AND status='OPEN';")" "^1$"
assert_match "APPLY blocked on match" "$(run_cobol "IDV_APPLY|${V}|||||${V}")" "SUCCESS\|KYC_PENDING\|SCREENING"
assert_match "owner cannot clear" "$(run_cobol "SCR_SCREEN|${V}|qhash3|FALSE_POSITIVE|opensanctions|ref3|${V}")" "ERROR\|FORBIDDEN"
assert_match "admin false-positive" "$(run_cobol "SCR_SCREEN|${V}|qhash3|FALSE_POSITIVE|opensanctions|ref3|${A}")" "SUCCESS\|SCREEN_RECORDED"
assert_match "no second review for false-positive" "$(db_query "SELECT COUNT(*) FROM manual_reviews WHERE user_id=(SELECT id FROM users WHERE email='${V}') AND kind='SCREENING' AND status='OPEN';")" "^1$"
assert_match "APPLY approves after false-positive" "$(run_cobol "IDV_APPLY|${V}|||||${V}")" "SUCCESS\|KYC_APPROVED"

assert_match "confirmed opens review" "$(run_cobol "SCR_SCREEN|${V}|qhash4|CONFIRMED_MATCH|opensanctions|ref4|${A}")" "SUCCESS\|SCREEN_RECORDED"
assert_match "status confirmed" "$(run_cobol "SCR_STATUS|${V}|||||${V}")" "SUCCESS\|SCREEN_STATUS\|CONFIRMED_MATCH"
assert_match "kind filter lists screening" "$(run_cobol "IDV_REVIEW_LIST||SCREENING||||${A}")" "SCREENING"
assert_match "kind filter excludes kyc" "$(run_cobol "IDV_REVIEW_LIST||KYC||||${A}")" "SUCCESS\|REVIEWS\|$"
assert_match "stranger cannot list" "$(run_cobol "IDV_REVIEW_LIST||||||sender@test.com")" "ERROR\|FORBIDDEN"
assert_match "stranger cannot list filtered" "$(run_cobol "IDV_REVIEW_LIST||SCREENING||||sender@test.com")" "ERROR\|FORBIDDEN"

# Freeze path: rejecting a screening review freezes the subject's
# wallets (sanctions chain), transfers block, unfreeze restores.
db_exec "INSERT INTO accounts (user_id, currency_id, balance) SELECT id,1,5000.00 FROM users WHERE email IN ('${U}','${V}');"
srev="$(db_query "SELECT id FROM manual_reviews WHERE user_id=(SELECT id FROM users WHERE email='${V}') AND kind='SCREENING' AND status='OPEN' ORDER BY id DESC LIMIT 1;")"
assert_match "reject review freezes" "$(run_cobol "IDV_REVIEW_DECIDE|${srev}|REJECTED|sanction-hit|||${A}")" "SUCCESS\|REVIEW_DECIDED"
assert_match "wallets frozen" "$(db_query "SELECT COUNT(*) FROM accounts WHERE user_id=(SELECT id FROM users WHERE email='${V}') AND status='ACTIVE';")" "^0$"
assert_match "frozen sender blocked" "$(run_cobol "TRANSFER|${V}|${U}|10.00|||")" "ERROR\|ACCOUNT_FROZEN"
assert_match "freeze unknown refused" "$(run_cobol "ACCOUNT_FREEZE|nobody@test.com|||||${A}")" "ERROR\|NOT_FOUND"
assert_match "non-admin freeze refused" "$(run_cobol "ACCOUNT_FREEZE|${V}|||||sender@test.com")" "ERROR\|FORBIDDEN"
assert_match "unfreeze ok" "$(run_cobol "ACCOUNT_UNFREEZE|${V}|cleared||||${A}")" "SUCCESS\|ACCOUNT_UNFROZEN"
assert_match "transfer works after unfreeze" "$(run_cobol "TRANSFER|${V}|${U}|10.00|||")" "SUCCESS\|TRANSFER_OK"
assert_match "freeze ok" "$(run_cobol "ACCOUNT_FREEZE|${V}|sanctions||||${A}")" "SUCCESS\|ACCOUNT_FROZEN"
assert_match "freeze again refused" "$(run_cobol "ACCOUNT_FREEZE|${V}|||||${A}")" "ERROR\|INVALID_STATUS"
assert_match "unfreeze non-frozen refused" "$(run_cobol "ACCOUNT_UNFREEZE|${U}|||||${A}")" "ERROR\|INVALID_STATUS"
db_exec "INSERT INTO manual_reviews (user_id, kind, status, reason) SELECT id,'KYC','OPEN','doc-check' FROM users WHERE email='${V}';"
krev="$(db_query "SELECT id FROM manual_reviews WHERE user_id=(SELECT id FROM users WHERE email='${V}') AND kind='KYC' AND status='OPEN' ORDER BY id DESC LIMIT 1;")"
assert_match "kyc approve blocked on sanction" "$(run_cobol "IDV_REVIEW_DECIDE|${krev}|APPROVED|looks-ok|||${A}")" "ERROR\|SANCTION_CHECK_REQUIRED"

cleanup

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
