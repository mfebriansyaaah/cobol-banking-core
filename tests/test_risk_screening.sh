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
ADM="rsk_admin@test.com"; USR="rsk_user@test.com"
cleanup() { q "DELETE FROM risk_audit WHERE actor_email IN ('$ADM','$USR'); DELETE FROM screening_hit WHERE created_by IN ('$ADM','$USR'); DELETE FROM risk_profile WHERE updated_by IN ('$ADM','$USR'); DELETE FROM users WHERE email IN ('$ADM','$USR');"; }
setup() { cleanup; q "INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES (1470,'$ADM','x','RSK Admin','1990-01-01','VERIFIED','SUPER_ADMIN'),(1471,'$USR','x','RSK User','1990-01-01','VERIFIED','USER') ON DUPLICATE KEY UPDATE role=VALUES(role),status='VERIFIED';"; }
teardown() { cleanup; }
trap 'core_stop; teardown' EXIT
core_start
echo "======================================================================"
echo "  RISK SCREENING SUITE (PHASE 1)"
echo "======================================================================"
setup
check "set risk profile" "SUCCESS|RSK_PROFILE_SAVED" "$(run RSK_PROFILE_SET "$ADM" HIGH 90 '' '' "$ADM")"
check_contains "get risk profile" "RSK_PROFILE|$ADM" "$(run RSK_PROFILE_GET "$ADM" '' '' '' '' "$ADM")"
check "screen customer" "SUCCESS|RSK_SCREENED" "$(run RSK_SCREEN "$ADM" HIGH PEP 'hit' '' "$ADM")"
check_contains "list screening hits" "PEP" "$(run RSK_HIT_LIST '' 50 0 '' '' "$ADM")"
check_contains "risk summary" "RSK_SUMMARY|" "$(run RSK_SUMMARY '' '' '' '' '' "$ADM")"
check "non-admin forbidden" "ERROR|FORBIDDEN" "$(run RSK_SUMMARY '' '' '' '' '' "$USR")"
echo "----------------------------------------------------------------------"; echo "PASSED: $passed  FAILED: $failed"; echo "----------------------------------------------------------------------"; [ "$failed" -eq 0 ]
