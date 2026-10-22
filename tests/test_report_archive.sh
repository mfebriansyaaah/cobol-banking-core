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
ADM="rpa_admin@test.com"; USR="rpa_user@test.com"
cleanup() {
    q "DELETE FROM report_archive_audit WHERE actor_email IN ('$ADM','$USR');
       DELETE FROM report_archive WHERE created_by IN ('$ADM','$USR');
       DELETE FROM users WHERE email IN ('$ADM','$USR');"
}
setup() {
    cleanup
    q "INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES
       (1290,'$ADM','x','RPA Admin','1990-01-01','VERIFIED','SUPER_ADMIN'),
       (1291,'$USR','x','RPA User','1990-01-01','VERIFIED','USER')
       ON DUPLICATE KEY UPDATE role=VALUES(role),status='VERIFIED';"
}
teardown() { cleanup; }
trap 'core_stop; teardown' EXIT
core_start
echo "======================================================================"
echo "  REPORT ARCHIVE SUITE (PHASE 1)"
echo "======================================================================"
setup
check "archive report" "SUCCESS|RPA_ARCHIVED" \
    "$(run RPA_ARCHIVE RPA_TEST TRIAL_BALANCE 2026-01 42 ABC123 "$ADM")"
check_contains "get report archive" "RPA_ARCHIVE|RPA_TEST" \
    "$(run RPA_GET RPA_TEST '' '' '' '' "$ADM")"
check_contains "list report archives" "RPA_TEST" \
    "$(run RPA_LIST '' 50 0 '' '' "$ADM")"
check_contains "report archive summary" "RPA_SUMMARY|" \
    "$(run RPA_SUMMARY '' '' '' '' '' "$ADM")"
check "purge old report archives" "SUCCESS|RPA_PURGED" \
    "$(run RPA_PURGE 2000-01-01 '' '' '' '' "$ADM")"
check "missing archive rejected" "ERROR|NOT_FOUND" \
    "$(run RPA_GET RPA_MISSING '' '' '' '' "$ADM")"
check "non-admin forbidden" "ERROR|FORBIDDEN" \
    "$(run RPA_SUMMARY '' '' '' '' '' "$USR")"
check "report archive audit rows recorded" "2" \
    "$(q "SELECT COUNT(*) FROM report_archive_audit WHERE actor_email IN ('$ADM','$USR') AND action IN ('ARCHIVE','AUTHZ_DENIED');")"
echo "----------------------------------------------------------------------"; echo "PASSED: $passed  FAILED: $failed"; echo "----------------------------------------------------------------------"; [ "$failed" -eq 0 ]
