#!/usr/bin/env bash
# KYC identity shell coverage (PR-085): NIK record, OCR review path,
# gated APPLY, status reads, admin review decisions.
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
U="kycU@test.com"
db_exec "DELETE FROM manual_reviews WHERE user_id IN (SELECT id FROM users WHERE email='${U}');"
db_exec "DELETE FROM identity_verifications WHERE user_id IN (SELECT id FROM users WHERE email='${U}');"
db_exec "DELETE FROM phone_links WHERE user_id IN (SELECT id FROM users WHERE email='${U}');"
db_exec "DELETE FROM users WHERE email='${U}';"
run_cobol "REQUEST_SIGNUP|${U}|Passw0rd!|Kyc You|1990-01-01" >/dev/null
code="$(db_query "SELECT code FROM verification_logs WHERE email='${U}' AND is_used=0 ORDER BY id DESC LIMIT 1;")"
run_cobol "VERIFY_EMAIL|${U}|${code}" >/dev/null

# APPLY gates: nothing yet -> NIK missing named.
assert_match "STATUS ok (fresh)" "$(run_cobol "IDV_STATUS|${U}|||||${A}")" "SUCCESS\|KYC_STATUS\|UNVERIFIED"
assert_match "APPLY needs NIK" "$(run_cobol "IDV_APPLY|${U}|||||${U}")" "SUCCESS\|KYC_PENDING\|NIK"
assert_match "foreign actor refused" "$(run_cobol "IDV_APPLY|${U}|||||sender@test.com")" "ERROR\|FORBIDDEN"

# NIK record: invalid verdict stores, valid flips kyc.
assert_match "NIK invalid stored" "$(run_cobol "IDV_NIK_VALIDATE|${U}|aaaabbbbccccdddd|0001|INVALID||${U}")" "SUCCESS\|NIK_RECORDED"
assert_match "still pending NIK" "$(run_cobol "IDV_APPLY|${U}|||||${U}")" "SUCCESS\|KYC_PENDING\|NIK"
assert_match "NIK valid stored" "$(run_cobol "IDV_NIK_VALIDATE|${U}|aaaabbbbccccdddd|0001|VALID||${U}")" "SUCCESS\|NIK_RECORDED"
assert_match "kyc NIK_VALID" "$(db_query "SELECT kyc_status FROM users WHERE email='${U}';")" "^NIK_VALID$"
assert_match "APPLY needs phone" "$(run_cobol "IDV_APPLY|${U}|||||${U}")" "SUCCESS\|KYC_PENDING\|PHONE"
assert_match "bad verdict refused" "$(run_cobol "IDV_NIK_VALIDATE|${U}|x|0001|MAYBE||${U}")" "ERROR\|INVALID_INPUT"

# OCR low-confidence path: review opens, kyc gated, admin decides.
assert_match "OCR manual stored" "$(run_cobol "IDV_KTP_OCR_RESULT|${U}|MANUAL_REVIEW|blurry|||${U}")" "SUCCESS\|OCR_RECORDED"
rid="$(db_query "SELECT id FROM manual_reviews WHERE user_id=(SELECT id FROM users WHERE email='${U}') AND status='OPEN' ORDER BY id DESC LIMIT 1;")"
assert_match "review row" "$rid" "^[0-9]+$"
assert_match "approve refused (non-admin)" "$(run_cobol "IDV_REVIEW_DECIDE|${rid}|APPROVED||||sender@test.com")" "ERROR\|FORBIDDEN"
assert_match "approve ok" "$(run_cobol "IDV_REVIEW_DECIDE|${rid}|APPROVED|looks good|||${A}")" "SUCCESS\|REVIEW_DECIDED"
assert_match "review closed" "$(db_query "SELECT status FROM manual_reviews WHERE id=${rid};")" "^APPROVED$"
assert_match "double decide refused" "$(run_cobol "IDV_REVIEW_DECIDE|${rid}|REJECTED|x|||${A}")" "ERROR\|INVALID_STATUS"
assert_match "OCR approve rejected (must review)" "$(run_cobol "IDV_KTP_OCR_RESULT|${U}|APPROVED|x|||${U}")" "ERROR\|INVALID_INPUT"

# Phone proof via OTP link flow, then APPLY completes (idempotent).
begin_out="$(run_cobol "OTP_LINK_BEGIN|${U}|hash9||${U}||")"
assert_match "LINK_BEGIN ok" "$begin_out" "SUCCESS\|LINK_BEGIN"
token="$(printf '%s' "$begin_out" | awk -F'|' '{print $3}')"
assert_match "LINK_CONFIRM ok" "$(run_cobol "OTP_LINK_CONFIRM|${U}|${token}|chat--idv|${U}||")" "SUCCESS\|LINK_CONFIRMED"
issue_out="$(run_cobol "OTP_ISSUE|${U}|PHONE|KYC_LOGIN|${U}|")"
assert_match "ISSUE ok" "$issue_out" "SUCCESS\|OTP_ISSUED"
otp="$(printf '%s' "$issue_out" | awk -F'|' '{print $4}')"
assert_match "otp carried for provider" "$otp" "^[0-9]+$"
assert_match "VERIFY ok" "$(run_cobol "OTP_VERIFY|${U}|${otp}|KYC_LOGIN|${U}|")" "SUCCESS\|OTP_VERIFIED"
assert_match "APPLY ok" "$(run_cobol "IDV_APPLY|${U}|||||${U}")" "SUCCESS\|KYC_APPROVED"
assert_match "APPLY idempotent" "$(run_cobol "IDV_APPLY|${U}|||||${U}")" "SUCCESS\|KYC_APPROVED"
assert_match "STATUS approved" "$(run_cobol "IDV_STATUS|${U}|||||${U}")" "SUCCESS\|KYC_STATUS\|APPROVED"
assert_match "admin can read" "$(run_cobol "IDV_STATUS|${U}|||||${A}")" "SUCCESS\|KYC_STATUS\|APPROVED"
assert_match "stranger refused" "$(run_cobol "IDV_STATUS|${U}|||||sender@test.com")" "ERROR\|FORBIDDEN"

db_exec "DELETE FROM manual_reviews WHERE user_id IN (SELECT id FROM users WHERE email='${U}');"
db_exec "DELETE FROM identity_verifications WHERE user_id IN (SELECT id FROM users WHERE email='${U}');"
db_exec "DELETE FROM otp_challenges WHERE user_id IN (SELECT id FROM users WHERE email='${U}');"
db_exec "DELETE FROM phone_links WHERE user_id IN (SELECT id FROM users WHERE email='${U}');"
db_exec "DELETE FROM users WHERE email='${U}';"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
