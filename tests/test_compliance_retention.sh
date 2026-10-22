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
ADM="crt_admin@test.com"; USR="crt_user@test.com"; POL="CRT_TEST"
cleanup() {
    q "DELETE FROM compliance_retention_audit WHERE actor_email IN ('$ADM','$USR');
       DELETE FROM compliance_retention_run WHERE executed_by IN ('$ADM','$USR');
       DELETE FROM compliance_retention_policy WHERE policy_code='$POL';
       DELETE FROM users WHERE email IN ('$ADM','$USR');"
}
setup() {
    cleanup
    q "INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES
       (1240,'$ADM','x','CRT Admin','1990-01-01','VERIFIED','SUPER_ADMIN'),
       (1241,'$USR','x','CRT User','1990-01-01','VERIFIED','USER')
       ON DUPLICATE KEY UPDATE role=VALUES(role),status='VERIFIED';"
}
teardown() { cleanup; }
trap 'core_stop; teardown' EXIT
core_start
echo "======================================================================"
echo "  COMPLIANCE RETENTION SUITE (PHASE 1)"
echo "======================================================================"
setup
check "save retention policy" "SUCCESS|CRT_POLICY_SAVED" \
    "$(run CRT_POLICY_SET "$POL" AUDIT 30 1 '' "$ADM")"
check_contains "list retention policies" "$POL" \
    "$(run CRT_POLICY_LIST 50 0 '' '' '' "$ADM")"
check "run retention policy" "SUCCESS|CRT_RETENTION_RAN" \
    "$(run CRT_RETENTION_RUN "$POL" '' '' '' '' "$ADM")"
check_contains "list retention runs" "$POL" \
    "$(run CRT_RUN_LIST "$POL" 50 0 '' '' "$ADM")"
check_contains "retention summary" "CRT_SUMMARY|" \
    "$(run CRT_SUMMARY '' '' '' '' '' "$ADM")"
check "delete retention policy" "SUCCESS|CRT_POLICY_DELETED" \
    "$(run CRT_POLICY_DELETE "$POL" '' '' '' '' "$ADM")"
check "missing policy rejected" "ERROR|NOT_FOUND" \
    "$(run CRT_POLICY_DELETE "$POL" '' '' '' '' "$ADM")"
check "non-admin forbidden" "ERROR|FORBIDDEN" \
    "$(run CRT_SUMMARY '' '' '' '' '' "$USR")"
check "retention audit rows recorded" "4" \
    "$(q "SELECT COUNT(*) FROM compliance_retention_audit WHERE actor_email IN ('$ADM','$USR') AND action IN ('POLICY_SET','RETENTION_RUN','POLICY_DELETE','AUTHZ_DENIED');")"
echo "----------------------------------------------------------------------"; echo "PASSED: $passed  FAILED: $failed"; echo "----------------------------------------------------------------------"; [ "$failed" -eq 0 ]
