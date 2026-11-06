#!/usr/bin/env bash
# KYC enforcement (PR-089): money moves above 1,000,000 only for APPROVED
# users. TRANSFER and LOAN_DISBURSE refuse with KYC_REQUIRED; below the bar
# verified users are frictionless; the review queue backs the flow.
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
KS="kycenfS@test.com"
KR="kycenfR@test.com"

cleanup_fixture() {
    db_exec "DELETE FROM loan_repayment WHERE loan_id IN (SELECT id FROM loan_application WHERE customer_email IN ('${KS}','${KR}'));"
    db_exec "DELETE FROM loan_application WHERE customer_email IN ('${KS}','${KR}');"
    db_exec "DELETE FROM ledger WHERE account_id IN (SELECT account_id FROM accounts WHERE user_id IN (SELECT id FROM users WHERE email IN ('${KS}','${KR}')));"
    db_exec "DELETE FROM pending_transactions WHERE from_email IN ('${KS}','${KR}') OR to_email IN ('${KS}','${KR}');"
    db_exec "DELETE FROM transfer_reversals WHERE from_email IN ('${KS}','${KR}');"
    db_exec "DELETE FROM screening_checks WHERE user_id IN (SELECT id FROM users WHERE email IN ('${KS}','${KR}'));"
    db_exec "DELETE FROM manual_reviews WHERE user_id IN (SELECT id FROM users WHERE email IN ('${KS}','${KR}'));"
    db_exec "DELETE FROM identity_verifications WHERE user_id IN (SELECT id FROM users WHERE email IN ('${KS}','${KR}'));"
    db_exec "DELETE FROM otp_challenges WHERE user_id IN (SELECT id FROM users WHERE email IN ('${KS}','${KR}'));"
    db_exec "DELETE FROM phone_links WHERE user_id IN (SELECT id FROM users WHERE email IN ('${KS}','${KR}'));"
    db_exec "DELETE FROM accounts WHERE user_id IN (SELECT id FROM users WHERE email IN ('${KS}','${KR}'));"
    db_exec "DELETE FROM users WHERE email IN ('${KS}','${KR}');"
    db_exec "DELETE FROM fee_schedule WHERE currency_id=1;"
    db_exec "DELETE FROM accounts WHERE account_type='FEE_INCOME' AND currency_id=1;"
}
cleanup_fixture
for U in "$KS" "$KR"; do
    run_cobol "REQUEST_SIGNUP|${U}|Passw0rd!|Kyc Enf|1990-01-01" >/dev/null
    code="$(db_query "SELECT code FROM verification_logs WHERE email='${U}' AND is_used=0 ORDER BY id DESC LIMIT 1;")"
    run_cobol "VERIFY_EMAIL|${U}|${code}" >/dev/null
    db_exec "INSERT INTO accounts (user_id, currency_id, balance) SELECT id, 1, 3000000.00 FROM users WHERE email='${U}';"
done

echo "=== TRANSFER gate ==="
assert_match "small transfer frictionless" "$(run_cobol "TRANSFER|${KS}|${KR}|100.00|KYCENF-1|||")" "SUCCESS\|TRANSFER_OK"
assert_match "large transfer blocked" "$(run_cobol "TRANSFER|${KS}|${KR}|1500000.00|KYCENF-2|||")" "ERROR\|KYC_REQUIRED"
assert_match "boundary (exactly 1M) allowed" "$(run_cobol "TRANSFER|${KS}|${KR}|1000000.00|KYCENF-3|||")" "SUCCESS\|TRANSFER_OK"
assert_match "blocked transfer moved nothing" "$(db_query "SELECT COUNT(*) FROM pending_transactions WHERE txn_ref='KYCENF-2';")" "^0$"

echo "=== Review queue ==="
assert_match "OCR opens review" "$(run_cobol "IDV_KTP_OCR_RESULT|${KR}|MANUAL_REVIEW|enf-check|||${KR}")" "SUCCESS\|OCR_RECORDED"
assert_match "stranger cannot list" "$(run_cobol "IDV_REVIEW_LIST||||||sender@test.com")" "ERROR\|FORBIDDEN"
assert_match "admin lists open row" "$(run_cobol "IDV_REVIEW_LIST||||||${A}")" "SUCCESS\|REVIEWS\|[0-9][0-9]*:[0-9][0-9]*:KYC:OPEN"
rid="$(db_query "SELECT id FROM manual_reviews WHERE user_id=(SELECT id FROM users WHERE email='${KR}') AND status='OPEN' ORDER BY id DESC LIMIT 1;")"
assert_match "approve ok" "$(run_cobol "IDV_REVIEW_DECIDE|${rid}|APPROVED|enf-ok|||${A}")" "SUCCESS\|REVIEW_DECIDED"
assert_match "queue clear" "$(run_cobol "IDV_REVIEW_LIST||||||${A}")" "SUCCESS\|REVIEWS\|$"
assert_match "KR approved via review" "$(run_cobol "IDV_STATUS|${KR}|||||${KR}")" "SUCCESS\|KYC_STATUS\|APPROVED"

echo "=== Approved money moves ==="
assert_match "KR large transfer ok" "$(run_cobol "TRANSFER|${KR}|${KS}|1500000.00|KYCENF-4|||")" "SUCCESS\|TRANSFER_OK"

echo "=== Loan gate ==="
apply_out="$(run_cobol "LOAN_APPLY|${KS}|2000000.00|USD|12|5.5|${A}")"
assert_match "loan applied" "$apply_out" "SUCCESS\|LOAN_APPLY\|"
lid="$(printf '%s' "$apply_out" | awk -F'|' '{print $3}')"
assert_match "loan approved" "$(run_cobol "LOAN_APPROVE|${lid}|5.5|ok|||${A}")" "SUCCESS\|LOAN_APPROVE"
assert_match "disburse blocked (borrower unverified)" "$(run_cobol "LOAN_DISBURSE|${lid}|||||${A}")" "ERROR\|KYC_REQUIRED"
assert_match "not disbursed" "$(db_query "SELECT status FROM loan_application WHERE id=${lid};")" "^APPROVED$"

echo "=== Full KYC dance unlocks ==="
assert_match "NIK valid" "$(run_cobol "IDV_NIK_VALIDATE|${KS}|hash|0001|VALID||${KS}")" "SUCCESS\|NIK_RECORDED"
begin_out="$(run_cobol "OTP_LINK_BEGIN|${KS}|hash||${KS}||")"
token="$(printf '%s' "$begin_out" | awk -F'|' '{print $3}')"
assert_match "link" "$(run_cobol "OTP_LINK_CONFIRM|${KS}|${token}|chat-enf|${KS}||")" "SUCCESS\|LINK_CONFIRMED"
issue_out="$(run_cobol "OTP_ISSUE|${KS}|PHONE|KYC_ENF|${KS}|")"
otp="$(printf '%s' "$issue_out" | awk -F'|' '{print $4}')"
assert_match "otp verified" "$(run_cobol "OTP_VERIFY|${KS}|${otp}|KYC_ENF|${KS}|")" "SUCCESS\|OTP_VERIFIED"
assert_match "screening clear" "$(run_cobol "SCR_SCREEN|${KS}|qhash-enf|CLEAR|opensanctions|ref-enf|${KS}")" "SUCCESS\|SCREEN_RECORDED"
assert_match "KS approved" "$(run_cobol "IDV_APPLY|${KS}|||||${KS}")" "SUCCESS\|KYC_APPROVED"
assert_match "KS large transfer ok" "$(run_cobol "TRANSFER|${KS}|${KR}|1500000.00|KYCENF-5|||")" "SUCCESS\|TRANSFER_OK"
assert_match "disburse ok after KYC" "$(run_cobol "LOAN_DISBURSE|${lid}|||||${A}")" "SUCCESS\|LOAN_DISBURSE"

cleanup_fixture

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
