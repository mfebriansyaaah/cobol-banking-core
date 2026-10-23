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
ADM="grl_admin@test.com"; USR="grl_user@test.com"
cleanup() { q "DELETE FROM gl_revaluation_audit WHERE actor_email IN ('$ADM','$USR'); DELETE FROM gl_revaluation_line WHERE run_id IN (SELECT id FROM gl_revaluation_run WHERE created_by IN ('$ADM','$USR')); DELETE FROM gl_revaluation_run WHERE created_by IN ('$ADM','$USR'); DELETE FROM users WHERE email IN ('$ADM','$USR');"; }
setup() { cleanup; q "INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES (1500,'$ADM','x','GRL Admin','1990-01-01','VERIFIED','SUPER_ADMIN'),(1501,'$USR','x','GRL User','1990-01-01','VERIFIED','USER') ON DUPLICATE KEY UPDATE role=VALUES(role),status='VERIFIED';"; }
teardown() { cleanup; }
trap 'core_stop; teardown' EXIT
core_start
echo "======================================================================"
echo "  GL REVALUATION SUITE (PHASE 1)"
echo "======================================================================"
setup
check "start revaluation run" "SUCCESS|GRL_RUN_STARTED" "$(run GRL_RUN_START 2026-10 USD '' '' '' "$ADM")"
RID=$(q "SELECT id FROM gl_revaluation_run WHERE created_by='$ADM' ORDER BY id DESC LIMIT 1;")
check "add revaluation line" "SUCCESS|GRL_LINE_ADDED" "$(run GRL_LINE_ADD "$RID" 1000 100.00 110.00 10.00 "$ADM")"
check "complete revaluation run" "SUCCESS|GRL_RUN_COMPLETED" "$(run GRL_RUN_COMPLETE "$RID" 1 10.00 '' '' "$ADM")"
check_contains "get revaluation run" "GRL_RUN|$RID" "$(run GRL_RUN_GET "$RID" '' '' '' '' "$ADM")"
check_contains "list revaluation runs" "$RID" "$(run GRL_RUN_LIST '' 50 0 '' '' "$ADM")"
check_contains "revaluation summary" "GRL_SUMMARY|" "$(run GRL_SUMMARY '' '' '' '' '' "$ADM")"
check "missing run rejected" "ERROR|NOT_FOUND" "$(run GRL_RUN_GET 999999 '' '' '' '' "$ADM")"
check "non-admin forbidden" "ERROR|FORBIDDEN" "$(run GRL_SUMMARY '' '' '' '' '' "$USR")"
echo "----------------------------------------------------------------------"; echo "PASSED: $passed  FAILED: $failed"; echo "----------------------------------------------------------------------"; [ "$failed" -eq 0 ]
