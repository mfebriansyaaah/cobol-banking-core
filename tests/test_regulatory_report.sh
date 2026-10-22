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
ADM="reg_admin@test.com"; USR="reg_user@test.com"; RC="REG_TEST"
cleanup() {
    q "DELETE FROM regulatory_report_audit WHERE actor_email IN ('$ADM','$USR');
       DELETE FROM regulatory_report WHERE report_code='$RC';
       DELETE FROM users WHERE email IN ('$ADM','$USR');"
}
setup() {
    cleanup
    q "INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES
       (1310,'$ADM','x','REG Admin','1990-01-01','VERIFIED','SUPER_ADMIN'),
       (1311,'$USR','x','REG User','1990-01-01','VERIFIED','USER')
       ON DUPLICATE KEY UPDATE role=VALUES(role),status='VERIFIED';"
}
teardown() { cleanup; }
trap 'core_stop; teardown' EXIT
core_start
echo "======================================================================"
echo "  REGULATORY REPORT SUITE (PHASE 1)"
echo "======================================================================"
setup
check "create regulatory report" "SUCCESS|REG_CREATED" \
    "$(run REG_CREATE "$RC" OJK MONTHLY 2026-09 100 "$ADM")"
check_contains "get regulatory report" "REG_REPORT|$RC" \
    "$(run REG_GET "$RC" '' '' '' '' "$ADM")"
check_contains "list regulatory reports" "$RC" \
    "$(run REG_LIST DRAFT 50 0 '' '' "$ADM")"
check "submit regulatory report" "SUCCESS|REG_SUBMITTED" \
    "$(run REG_SUBMIT "$RC" '' '' '' '' "$ADM")"
check "accept regulatory report" "SUCCESS|REG_ACCEPTED" \
    "$(run REG_ACCEPT "$RC" 'accepted' '' '' '' "$ADM")"
check_contains "regulatory summary" "REG_SUMMARY|" \
    "$(run REG_SUMMARY '' '' '' '' '' "$ADM")"
check "missing report rejected" "ERROR|NOT_FOUND" \
    "$(run REG_GET REG_MISSING '' '' '' '' "$ADM")"
check "non-admin forbidden" "ERROR|FORBIDDEN" \
    "$(run REG_SUMMARY '' '' '' '' '' "$USR")"
echo "----------------------------------------------------------------------"; echo "PASSED: $passed  FAILED: $failed"; echo "----------------------------------------------------------------------"; [ "$failed" -eq 0 ]
