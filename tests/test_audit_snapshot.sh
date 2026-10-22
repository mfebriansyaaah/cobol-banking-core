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
ADM="asn_admin@test.com"; USR="asn_user@test.com"
cleanup() {
    q "DELETE FROM audit_snapshot_audit WHERE actor_email IN ('$ADM','$USR');
       DELETE FROM audit_snapshot WHERE created_by IN ('$ADM','$USR');
       DELETE FROM users WHERE email IN ('$ADM','$USR');"
}
setup() {
    cleanup
    q "INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES
       (1280,'$ADM','x','ASN Admin','1990-01-01','VERIFIED','SUPER_ADMIN'),
       (1281,'$USR','x','ASN User','1990-01-01','VERIFIED','USER')
       ON DUPLICATE KEY UPDATE role=VALUES(role),status='VERIFIED';"
}
teardown() { cleanup; }
trap 'core_stop; teardown' EXIT
core_start
echo "======================================================================"
echo "  AUDIT SNAPSHOT SUITE (PHASE 1)"
echo "======================================================================"
setup
check "create audit snapshot" "SUCCESS|ASN_CREATED" \
    "$(run ASN_CREATE ASN_TEST 2020-01-01 2999-01-01 '' '' "$ADM")"
check_contains "get audit snapshot" "ASN_SNAPSHOT|ASN_TEST" \
    "$(run ASN_GET ASN_TEST '' '' '' '' "$ADM")"
check_contains "list audit snapshots" "ASN_TEST" \
    "$(run ASN_LIST 50 0 '' '' '' "$ADM")"
check "verify audit snapshot" "SUCCESS|ASN_VERIFY|OK|ASN_TEST" \
    "$(run ASN_VERIFY ASN_TEST '' '' '' '' "$ADM")"
check_contains "audit snapshot summary" "ASN_SUMMARY|" \
    "$(run ASN_SUMMARY '' '' '' '' '' "$ADM")"
check "missing snapshot rejected" "ERROR|NOT_FOUND" \
    "$(run ASN_GET ASN_MISSING '' '' '' '' "$ADM")"
check "non-admin forbidden" "ERROR|FORBIDDEN" \
    "$(run ASN_SUMMARY '' '' '' '' '' "$USR")"
check "audit snapshot audit rows recorded" "2" \
    "$(q "SELECT COUNT(*) FROM audit_snapshot_audit WHERE actor_email IN ('$ADM','$USR') AND action IN ('SNAPSHOT_CREATE','AUTHZ_DENIED');")"
echo "----------------------------------------------------------------------"; echo "PASSED: $passed  FAILED: $failed"; echo "----------------------------------------------------------------------"; [ "$failed" -eq 0 ]
