#!/bin/bash
# Reference-data expansion suite (Sprint 1 slice 6).
BIN="./cobol/bin/main_logic"
. ./tests/serve_harness.sh
if [ -f ./tests/.dbenv ]; then . ./tests/.dbenv; fi
DB_USER="${DB_USER:-cobol_user}"; DB_PASS="${DB_PASS:-cobol_pass}"; DB_NAME="${DB_NAME:-cobol_db}"
GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
passed=0; failed=0
q() { mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -N -B -e "$1" 2>/dev/null; }
run() { core_run "$@"; }
check() { local n="$1" e="$2" a="$3"; if [ "$a" = "$e" ]; then echo -e "${GREEN}PASS${NC} $n"; passed=$((passed+1)); else echo -e "${RED}FAIL${NC} $n (expected [$e] got [$a])"; failed=$((failed+1)); fi; }
check_contains() { local n="$1" x="$2" a="$3"; if [[ "$a" == *"$x"* ]]; then echo -e "${GREEN}PASS${NC} $n"; passed=$((passed+1)); else echo -e "${RED}FAIL${NC} $n (expected [$x] got [$a])"; failed=$((failed+1)); fi; }
ADM="ref_admin@test.com"; USR="ref_user@test.com"
cleanup() {
 q "DELETE FROM ref_engine_audit WHERE actor_email IN ('$ADM','$USR');
    DELETE FROM ref_hierarchy WHERE parent_value_id IN (SELECT id FROM ref_value WHERE type_code='rxtest') OR child_value_id IN (SELECT id FROM ref_value WHERE type_code='rxtest');
    DELETE FROM ref_translation WHERE ref_value_id IN (SELECT id FROM ref_value WHERE type_code='rxtest');
    DELETE FROM ref_value_version WHERE ref_value_id IN (SELECT id FROM ref_value WHERE type_code='rxtest');
    DELETE FROM ref_value WHERE type_code='rxtest'; DELETE FROM ref_type WHERE type_code='rxtest';
    DELETE FROM users WHERE email IN ('$ADM','$USR');"
}
setup() {
 cleanup
 q "INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES (1001,'$ADM','x','Ref Admin','1990-01-01','VERIFIED','SUPER_ADMIN'),(1002,'$USR','x','Ref User','1990-01-01','VERIFIED','USER') ON DUPLICATE KEY UPDATE role=VALUES(role),status='VERIFIED';
    INSERT INTO ref_type (type_code,label,description,is_active) VALUES ('rxtest','RX Test','test type',TRUE);
    INSERT INTO ref_value (type_code,code) VALUES ('rxtest','PARENT'),('rxtest','CHILD'),('rxtest','OTHER');
    INSERT INTO ref_value_version (ref_value_id,version_no,label,attributes,status,effective_from) SELECT id,1,'Parent active','{}','ACTIVE','2026-01-01' FROM ref_value WHERE type_code='rxtest' AND code='PARENT';
    INSERT INTO ref_value_version (ref_value_id,version_no,label,attributes,status,effective_from) SELECT id,1,'Child active','{}','ACTIVE','2026-01-01' FROM ref_value WHERE type_code='rxtest' AND code='CHILD';"
}
teardown() { cleanup; q "DELETE FROM audit_trail WHERE action='AUTHZ_DENIED' AND actor_id=1002;"; }
trap 'core_stop; teardown' EXIT
core_start
echo "======================================================================"
echo "  REFERENCE-DATA EXPANSION SUITE (PHASE 1)"
echo "======================================================================"
setup

check "set translation" "SUCCESS|RX_TRANSLATION_SET" \
 "$(run RX_TRANSLATION_SET rxtest PARENT id 'Induk' '' "$ADM")"
check_contains "list translations" "id:Induk" \
 "$(run RX_TRANSLATION_LIST rxtest PARENT 50 0 '' "$ADM")"
check "add hierarchy" "SUCCESS|RX_HIERARCHY_ADDED" \
 "$(run RX_HIERARCHY_ADD rxtest PARENT CHILD '' '' "$ADM")"
check_contains "list hierarchy" "PARENT:CHILD" \
 "$(run RX_HIERARCHY_LIST rxtest PARENT 50 0 '' "$ADM")"
check "remove hierarchy" "SUCCESS|RX_HIERARCHY_REMOVED" \
 "$(run RX_HIERARCHY_REMOVE rxtest PARENT CHILD '' '' "$ADM")"
check_contains "as-of value" "Parent active" \
 "$(run RX_VALUE_GET_ASOF rxtest PARENT 2026-06-01 '' '' "$ADM")"
check "clone value" "SUCCESS|RX_VALUE_CLONED" \
 "$(run RX_VALUE_CLONE rxtest PARENT CLONE 'Clone label' '' "$ADM")"
check_contains "export values" "PARENT" \
 "$(run RX_EXPORT rxtest CSV '' '' '' "$ADM")"
check "non-admin forbidden" "ERROR|FORBIDDEN" \
 "$(run RX_EXPORT rxtest CSV '' '' '' "$USR")"
check "reference audit rows recorded" "5" \
 "$(q "SELECT COUNT(*) FROM ref_engine_audit WHERE actor_email IN ('$ADM','$USR');")"
echo "----------------------------------------------------------------------"
echo "PASSED: $passed  FAILED: $failed"
echo "----------------------------------------------------------------------"
[ "$failed" -eq 0 ]
