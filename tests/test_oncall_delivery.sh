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
ADM="odl_admin@test.com"; USR="odl_user@test.com"
cleanup() {
    q "DELETE FROM oncall_delivery_audit WHERE actor_email IN ('$ADM','$USR');
       DELETE FROM oncall_delivery WHERE target_email IN ('$ADM','$USR');
       DELETE FROM oncall_page WHERE detail='ODL_TEST';
       DELETE FROM ops_alert WHERE source_key='ODL_TEST';
       DELETE FROM users WHERE email IN ('$ADM','$USR');"
}
setup() {
    cleanup
    q "INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES
       (1230,'$ADM','x','ODL Admin','1990-01-01','VERIFIED','SUPER_ADMIN'),
       (1231,'$USR','x','ODL User','1990-01-01','VERIFIED','USER')
       ON DUPLICATE KEY UPDATE role=VALUES(role),status='VERIFIED';
       INSERT INTO ops_alert (alert_type,severity,source_key,title,detail,created_by)
       VALUES ('MANUAL','WARNING','ODL_TEST','ODL Test','test','$ADM');
       SET @aid=LAST_INSERT_ID();
       INSERT INTO oncall_page (alert_id,step_no,target_email,detail,created_by) VALUES (@aid,1,'$ADM','ODL_TEST','$ADM');"
}
teardown() { cleanup; }
trap 'core_stop; teardown' EXIT
core_start
echo "======================================================================"
echo "  ONCALL DELIVERY SUITE (PHASE 1)"
echo "======================================================================"
setup
PAGE=$(q "SELECT id FROM oncall_page WHERE detail='ODL_TEST' LIMIT 1;")
check "enqueue delivery" "SUCCESS|ODL_ENQUEUED" \
    "$(run ODL_ENQUEUE "$PAGE" EMAIL "$ADM" 'test delivery' '' "$ADM")"
DID=$(q "SELECT id FROM oncall_delivery WHERE target_email='$ADM' ORDER BY id DESC LIMIT 1;")
check_contains "get delivery" "ODL_DELIVERY|$DID" \
    "$(run ODL_GET "$DID" '' '' '' '' "$ADM")"
check_contains "list deliveries" "$DID" \
    "$(run ODL_LIST '' QUEUED 50 0 '' "$ADM")"
check "send delivery" "SUCCESS|ODL_SENT" \
    "$(run ODL_SEND "$DID" '' '' '' '' "$ADM")"
check "confirm delivery" "SUCCESS|ODL_CONFIRMED" \
    "$(run ODL_CONFIRM "$DID" '' '' '' '' "$ADM")"
check "retry not applicable" "ERROR|INVALID_STATUS" \
    "$(run ODL_RETRY "$DID" '' '' '' '' "$ADM")"
check "cleanup old deliveries" "SUCCESS|ODL_CLEANED" \
    "$(run ODL_CLEANUP 2000-01-01 '' '' '' '' "$ADM")"
check_contains "delivery summary" "ODL_SUMMARY|" \
    "$(run ODL_SUMMARY '' '' '' '' '' "$ADM")"
check "missing delivery rejected" "ERROR|NOT_FOUND" \
    "$(run ODL_GET 999999 '' '' '' '' "$ADM")"
check "non-admin forbidden" "ERROR|FORBIDDEN" \
    "$(run ODL_SUMMARY '' '' '' '' '' "$USR")"
echo "----------------------------------------------------------------------"; echo "PASSED: $passed  FAILED: $failed"; echo "----------------------------------------------------------------------"; [ "$failed" -eq 0 ]
