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
ADM="loan_admin@test.com"; USR="loan_user@test.com"
cleanup() {
    q "DELETE FROM loan_audit WHERE actor_email IN ('$ADM','$USR');
       DELETE FROM loan_repayment WHERE loan_id IN (SELECT id FROM loan_application WHERE created_by IN ('$ADM','$USR'));
       DELETE FROM loan_application WHERE created_by IN ('$ADM','$USR');
       DELETE FROM users WHERE email IN ('$ADM','$USR');"
}
setup() {
    cleanup
    q "INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES
       (1320,'$ADM','x','LOAN Admin','1990-01-01','VERIFIED','SUPER_ADMIN'),
       (1321,'$USR','x','LOAN User','1990-01-01','VERIFIED','USER')
       ON DUPLICATE KEY UPDATE role=VALUES(role),status='VERIFIED';"
}
teardown() { cleanup; }
trap 'core_stop; teardown' EXIT
core_start
echo "======================================================================"
echo "  LOAN SUITE (PHASE 1)"
echo "======================================================================"
setup
check "apply loan" "SUCCESS|LOAN_APPLIED" \
    "$(run LOAN_APPLY "$ADM" 5000.00 USD 12 0.05 "$ADM")"
LID=$(q "SELECT id FROM loan_application WHERE created_by='$ADM' ORDER BY id DESC LIMIT 1;")
check_contains "get loan" "LOAN|$LID" \
    "$(run LOAN_GET "$LID" '' '' '' '' "$ADM")"
check_contains "list loans" "$LID" \
    "$(run LOAN_LIST PENDING 50 0 '' '' "$ADM")"
check "approve loan" "SUCCESS|LOAN_APPROVED" \
    "$(run LOAN_APPROVE "$LID" 0.07 'ok' '' '' "$ADM")"
check "disburse loan" "SUCCESS|LOAN_DISBURSED" \
    "$(run LOAN_DISBURSE "$LID" '' '' '' '' "$ADM")"
check "repay loan" "SUCCESS|LOAN_REPAID" \
    "$(run LOAN_REPAY "$LID" 100.00 '' '' '' "$ADM")"
check_contains "loan summary" "LOAN_SUMMARY|" \
    "$(run LOAN_SUMMARY '' '' '' '' '' "$ADM")"
check "non-admin forbidden" "ERROR|FORBIDDEN" \
    "$(run LOAN_SUMMARY '' '' '' '' '' "$USR")"
echo "----------------------------------------------------------------------"; echo "PASSED: $passed  FAILED: $failed"; echo "----------------------------------------------------------------------"; [ "$failed" -eq 0 ]
