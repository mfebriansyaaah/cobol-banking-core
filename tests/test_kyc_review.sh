#!/bin/bash
BIN="./cobol/bin/main_logic"
. ./tests/serve_harness.sh
if [ -f ./tests/.dbenv ]; then . ./tests/.dbenv; fi
DB_USER="${DB_USER:-cobol_user}"; DB_PASS="${DB_PASS:-cobol_pass}"; DB_NAME="${DB_NAME:-cobol_db}"
GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'; passed=0; failed=0
q() { mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -N -B -e "$1" 2>/dev/null; }
run() { core_run "$@"; }
check() { local n="$1" e="$2" a="$3"; if [ "$a" = "$e" ]; then echo -e "${GREEN}PASS${NC} $n"; passed=$((passed+1)); else echo -e "${RED}FAIL${NC} $n (expected [$e] got [$a])"; failed=$((failed+1)); fi; }
check_contains() { local n="$1" x="$2" a="$3"; if [[ "$a" == *"$x"* ]]; then echo -e "${GREEN}PASS${NC} $n"; passed=$((passed+1)); else echo -e "${RED}FAIL${NC} $n (expected [$x] got [$a])"; failed=$((failed+1)); fi; }
ADM="kyc_admin@test.com"; USR="kyc_user@test.com"
cleanup() {
    q "DELETE FROM kyc_review_audit WHERE actor_email IN ('$ADM','$USR');
       DELETE FROM kyc_review WHERE created_by IN ('$ADM','$USR');
       DELETE FROM users WHERE email IN ('$ADM','$USR');"
}
setup() {
    cleanup
    q "INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES
       (1300,'$ADM','x','KYC Admin','1990-01-01','VERIFIED','SUPER_ADMIN'),
       (1301,'$USR','x','KYC User','1990-01-01','VERIFIED','USER')
       ON DUPLICATE KEY UPDATE role=VALUES(role),status='VERIFIED';"
}
teardown() { cleanup; }
trap 'core_stop; teardown' EXIT
core_start
echo "======================================================================"
echo "  KYC REVIEW SUITE (PHASE 1)"
echo "======================================================================"
setup
check "create KYC review" "SUCCESS|KYC_CREATED" \
    "$(run KYC_CREATE $ADM ONBOARDING HIGH 2026-12-31 'initial' "$ADM")"
RID=$(q "SELECT id FROM kyc_review WHERE created_by='$ADM' ORDER BY id DESC LIMIT 1;")
check_contains "get KYC review" "KYC_REVIEW|$RID" \
    "$(run KYC_GET "$RID" '' '' '' '' "$ADM")"
check_contains "list KYC reviews" "$RID" \
    "$(run KYC_LIST PENDING 50 0 '' '' "$ADM")"
check "approve KYC review" "SUCCESS|KYC_APPROVED" \
    "$(run KYC_APPROVE "$RID" 'ok' '' '' '' "$ADM")"
check "cannot approve again" "ERROR|INVALID_STATUS" \
    "$(run KYC_APPROVE "$RID" 'again' '' '' '' "$ADM")"
check_contains "KYC summary" "KYC_SUMMARY|" \
    "$(run KYC_SUMMARY '' '' '' '' '' "$ADM")"
check "missing review rejected" "ERROR|NOT_FOUND" \
    "$(run KYC_GET 999999 '' '' '' '' "$ADM")"
check "non-admin forbidden" "ERROR|FORBIDDEN" \
    "$(run KYC_SUMMARY '' '' '' '' '' "$USR")"
echo "----------------------------------------------------------------------"; echo "PASSED: $passed  FAILED: $failed"; echo "----------------------------------------------------------------------"; [ "$failed" -eq 0 ]
