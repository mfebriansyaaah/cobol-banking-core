#!/bin/bash
# Audit drill-down saved queries (Phase 1, Sprint 1 slice 17).
BIN="./cobol/bin/main_logic"
. ./tests/serve_harness.sh
if [ -f ./tests/.dbenv ]; then . ./tests/.dbenv; fi
DB_USER="${DB_USER:-cobol_user}"; DB_PASS="${DB_PASS:-cobol_pass}"; DB_NAME="${DB_NAME:-cobol_db}"
GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'; passed=0; failed=0
q() { mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -N -B -e "$1" 2>/dev/null; }
run() { core_run "$@"; }
check() { local n="$1" e="$2" a="$3"; if [ "$a" = "$e" ]; then echo -e "${GREEN}PASS${NC} $n"; passed=$((passed+1)); else echo -e "${RED}FAIL${NC} $n (expected [$e] got [$a])"; failed=$((failed+1)); fi; }
check_contains() { local n="$1" x="$2" a="$3"; if [[ "$a" == *"$x"* ]]; then echo -e "${GREEN}PASS${NC} $n"; passed=$((passed+1)); else echo -e "${RED}FAIL${NC} $n (expected [$x] got [$a])"; failed=$((failed+1)); fi; }
ADM="adr_admin@test.com"; USR="adr_user@test.com"; QRY="ADR_DR_TEST"
cleanup() {
    q "DELETE FROM audit_drilldown_audit WHERE actor_email IN ('$ADM','$USR');
       DELETE FROM audit_drilldown_run WHERE executed_by IN ('$ADM','$USR');
       DELETE FROM audit_drilldown_query WHERE saved_by IN ('$ADM','$USR');
       DELETE FROM audit_trail WHERE user_id IN (1200,1201);
       DELETE FROM users WHERE email IN ('$ADM','$USR');"
}
setup() {
    cleanup
    q "INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES
       (1200,'$ADM','x','ADR Admin','1990-01-01','VERIFIED','SUPER_ADMIN'),
       (1201,'$USR','x','ADR User','1990-01-01','VERIFIED','USER')
       ON DUPLICATE KEY UPDATE role=VALUES(role),status='VERIFIED';
       INSERT INTO audit_trail (user_id,actor_id,action,entity_type,entity_id,detail,status) VALUES
       (1200,1200,'ADRXFER','ADRTEST','1','to:2','SUCCESS'),
       (1200,1200,'ADRXFER','ADRTEST','2','to:1','SUCCESS'),
       (1200,1200,'LOGIN','USER','1200','login','FAILED');"
}
teardown() { cleanup; }
trap 'core_stop; teardown' EXIT
core_start
echo "======================================================================"
echo "  AUDIT DRILL-DOWN SUITE (PHASE 1)"
echo "======================================================================"
setup
check "save drill-down query" "SUCCESS|ADR_QUERY_SAVED" \
    "$(run ADR_QUERY_SAVE "$QRY" 'Audit drill' 'ADRXFER,ADRTEST,SUCCESS,2020-01-01,2999-01-01' '' '' "$ADM")"
check_contains "get drill-down query" "ADR_QUERY|$QRY|Audit drill" \
    "$(run ADR_QUERY_GET "$QRY" '' '' '' '' "$ADM")"
check_contains "list drill-down queries" "$QRY" \
    "$(run ADR_QUERY_LIST 50 0 '' '' '' "$ADM")"
check_contains "run saved query" "SUCCESS|ADR_ROWS|2|" \
    "$(run ADR_RUN "$QRY" 50 0 '' '' "$ADM")"
check_contains "ad-hoc drill-down" "SUCCESS|ADR_ROWS|2|" \
    "$(run ADR_DRILL ADRXFER ADRTEST SUCCESS 2020-01-01 2999-01-01 "$ADM")"
check_contains "audit summary" "ADR_SUMMARY|0|0|0|0" \
    "$(run ADR_SUMMARY 2999-01-01 2999-12-31 '' '' '' "$ADM")"
check_contains "audit pivot" "ADRTEST:2" \
    "$(run ADR_PIVOT 2020-01-01 2999-01-01 '' '' '' "$ADM")"
check_contains "run history" "$QRY" \
    "$(run ADR_RUN_LIST "$QRY" 50 0 '' '' "$ADM")"
check "missing query rejected" "ERROR|NOT_FOUND" \
    "$(run ADR_QUERY_GET 'ADR_MISSING' '' '' '' '' "$ADM")"
check "delete drill-down query" "SUCCESS|ADR_QUERY_DELETED" \
    "$(run ADR_QUERY_DELETE "$QRY" '' '' '' '' "$ADM")"
check "deleted query missing" "ERROR|NOT_FOUND" \
    "$(run ADR_QUERY_GET "$QRY" '' '' '' '' "$ADM")"
check "non-admin forbidden" "ERROR|FORBIDDEN" \
    "$(run ADR_SUMMARY '' '' '' '' '' "$USR")"
check "audit drill-down audit rows recorded" "4" \
    "$(q "SELECT COUNT(*) FROM audit_drilldown_audit WHERE actor_email IN ('$ADM','$USR') AND action IN ('QUERY_SAVE','RUN','QUERY_DELETE','AUTHZ_DENIED');")"
echo "----------------------------------------------------------------------"; echo "PASSED: $passed  FAILED: $failed"; echo "----------------------------------------------------------------------"; [ "$failed" -eq 0 ]
