#!/bin/bash
# Audit analytics and retention suite (Phase 1, Sprint 1 slice 14).
BIN="./cobol/bin/main_logic"
. ./tests/serve_harness.sh
if [ -f ./tests/.dbenv ]; then . ./tests/.dbenv; fi
DB_USER="${DB_USER:-cobol_user}"; DB_PASS="${DB_PASS:-cobol_pass}"; DB_NAME="${DB_NAME:-cobol_db}"
GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'; passed=0; failed=0
q() { mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -N -B -e "$1" 2>/dev/null; }
run() { core_run "$@"; }
check() { local n="$1" e="$2" a="$3"; if [ "$a" = "$e" ]; then echo -e "${GREEN}PASS${NC} $n"; passed=$((passed+1)); else echo -e "${RED}FAIL${NC} $n (expected [$e] got [$a])"; failed=$((failed+1)); fi; }
check_contains() { local n="$1" x="$2" a="$3"; if [[ "$a" == *"$x"* ]]; then echo -e "${GREEN}PASS${NC} $n"; passed=$((passed+1)); else echo -e "${RED}FAIL${NC} $n (expected [$x] got [$a])"; failed=$((failed+1)); fi; }
ADM="aan_admin@test.com"; USR="aan_user@test.com"; TODAY="$(date +%F)"
cleanup() { q "DELETE FROM audit_analytics_snapshot WHERE 1=1;
       DELETE FROM audit_trail_archive WHERE audit_id IN (SELECT audit_id FROM audit_trail WHERE actor_id IN (SELECT id FROM users WHERE email IN ('$ADM','$USR')));
       DELETE FROM audit_trail WHERE actor_id IN (SELECT id FROM users WHERE email IN ('$ADM','$USR'));
       DELETE FROM users WHERE email IN ('$ADM','$USR');"; }
setup() {
    cleanup
    q "INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES
       (1120,'$ADM','x','AAN Admin','1990-01-01','VERIFIED','SUPER_ADMIN'),
       (1121,'$USR','x','AAN User','1990-01-01','VERIFIED','USER')
       ON DUPLICATE KEY UPDATE role=VALUES(role),status='VERIFIED';
       INSERT INTO audit_trail (user_id,actor_id,action,entity_type,entity_id,status,created_at) VALUES
       ((SELECT id FROM users WHERE email='$ADM'),(SELECT id FROM users WHERE email='$ADM'),'TEST_ACTION','AUDIT_ANALYTICS','1','SUCCESS',NOW()),
       ((SELECT id FROM users WHERE email='$USR'),(SELECT id FROM users WHERE email='$USR'),'TEST_ACTION','AUDIT_ANALYTICS','2','FAILED',NOW());"
}
teardown() { cleanup; q "DELETE FROM audit_trail WHERE action='AUTHZ_DENIED' AND actor_id=1121;"; }
trap 'core_stop; teardown' EXIT
core_start
echo "======================================================================"
echo "  AUDIT ANALYTICS SUITE (PHASE 1)"
echo "======================================================================"
setup
check_contains "summary" "AAN_SUMMARY|" "$(run AAN_SUMMARY '' '' '' '' '' "$ADM")"
check_contains "actions" "TEST_ACTION" "$(run AAN_ACTIONS '' '' 50 0 '' "$ADM")"
check_contains "actors" "aan_admin@test.com" "$(run AAN_ACTORS '' '' 50 0 '' "$ADM")"
check_contains "entities" "AUDIT_ANALYTICS" "$(run AAN_ENTITIES '' '' 50 0 '' "$ADM")"
check_contains "trend" "$TODAY" "$(run AAN_TREND '' '' '' '' '' "$ADM")"
check_contains "failures" "TEST_ACTION" "$(run AAN_FAILURES '' '' 50 0 '' "$ADM")"
check_contains "actor detail" "TEST_ACTION" "$(run AAN_ACTOR_DETAIL "$ADM" '' '' '' '' "$ADM")"
check_contains "anomaly" "AAN_ANOMALY|" "$(run AAN_ANOMALY 1 24 50 '' '' "$ADM")"
check_contains "search" "TEST_ACTION" "$(run AAN_SEARCH '' '' 50 0 TEST_ACTION "$ADM")"
check "snapshot" "SUCCESS|AAN_SNAPSHOT" "$(run AAN_SNAPSHOT "$TODAY" '' '' '' '' "$ADM")"
check "retention" "SUCCESS|AAN_RETENTION" "$(run AAN_RETENTION 2000-01-01 '' '' '' '' "$ADM")"
check "bad date rejected" "ERROR|INVALID_INPUT" "$(run AAN_SUMMARY 2026-13-01 '' '' '' '' "$ADM")"
check "non-admin forbidden" "ERROR|FORBIDDEN" "$(run AAN_ACTIONS '' '' 50 0 '' "$USR")"
check "audit analytics audit rows recorded" "3" \
    "$(q "SELECT COUNT(*) FROM audit_trail WHERE actor_id IN (SELECT id FROM users WHERE email IN ('$ADM','$USR')) AND action IN ('AUDIT_ANALYTICS','AUTHZ_DENIED');")"
echo "----------------------------------------------------------------------"; echo "PASSED: $passed  FAILED: $failed"; echo "----------------------------------------------------------------------"; [ "$failed" -eq 0 ]
