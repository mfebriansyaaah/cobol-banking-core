#!/bin/bash
# Fee, waiver, tier, and velocity suite (Sprint 1 slice 4).
# Usage: ./tests/test_fee.sh

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

ADM="fee_admin@test.com"; USR="fee_user@test.com"
cleanup() {
    q "DELETE FROM fee_audit WHERE actor_email IN ('$ADM','$USR');
       DELETE FROM fee_waiver WHERE rule_id IN (SELECT id FROM fee_rule WHERE rule_code LIKE 'FEE_%');
       DELETE FROM fee_tier WHERE rule_id IN (SELECT id FROM fee_rule WHERE rule_code LIKE 'FEE_%');
       DELETE FROM fee_rule WHERE rule_code LIKE 'FEE_%';
       DELETE FROM velocity_counter WHERE profile_code LIKE 'VEL_TEST%';
       DELETE FROM velocity_profile WHERE profile_code LIKE 'VEL_TEST%';"
}
setup() {
    cleanup
    q "DELETE FROM users WHERE email IN ('$ADM','$USR');
       INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES
       (996,'$ADM','x','Fee Admin','1990-01-01','VERIFIED','SUPER_ADMIN'),
       (997,'$USR','x','Fee User','1990-01-01','VERIFIED','USER')
       ON DUPLICATE KEY UPDATE role=VALUES(role),status='VERIFIED';"
}
teardown() { cleanup; q "DELETE FROM audit_trail WHERE action='AUTHZ_DENIED' AND actor_id=997; DELETE FROM users WHERE email IN ('$ADM','$USR');"; }
trap 'core_stop; teardown' EXIT
core_start
echo "======================================================================"
echo "  FEE / LIMIT / VELOCITY SUITE (PHASE 1)"
echo "======================================================================"
setup

check "create flat fee rule" "SUCCESS|FEE_RULE_CREATED" \
    "$(run FEE_RULE_CREATE FEE_FLAT 'Flat fee' FLAT IDR '1000,0,0,5000' "$ADM")"
check_contains "list fee rules" "FEE_FLAT:Flat fee:FLAT:IDR" \
    "$(run FEE_RULE_LIST 50 0 '' '' '' "$ADM")"
check "flat fee calculation" "SUCCESS|FEE_CALC|1000.0000000000" \
    "$(run FEE_CALCULATE user@test.com FEE_FLAT 1000 IDR '' "$ADM")"

check "create tiered fee rule" "SUCCESS|FEE_RULE_CREATED" \
    "$(run FEE_RULE_CREATE FEE_TIER 'Tier fee' TIERED IDR '0,0,0,5000' "$ADM")"
check "create fee tier" "SUCCESS|FEE_TIER_CREATED" \
    "$(run FEE_TIER_CREATE FEE_TIER 1 0 1000 '100,0' "$ADM")"
check_contains "list fee tiers" "1:0.0000000000:1000.0000000000:100.0000000000" \
    "$(run FEE_TIER_LIST FEE_TIER 50 0 '' '' "$ADM")"
check "tier fee calculation" "SUCCESS|FEE_CALC|100.0000000000" \
    "$(run FEE_CALCULATE user@test.com FEE_TIER 500 IDR '' "$ADM")"

check "create fee waiver" "SUCCESS|FEE_WAIVER_CREATED" \
    "$(run FEE_WAIVER_CREATE FEE_FLAT user@test.com promo 2026-01-01 2026-12-31 "$ADM")"
check_contains "list fee waivers" "user@test.com:promo" \
    "$(run FEE_WAIVER_LIST FEE_FLAT 50 0 '' '' "$ADM")"
check "waiver makes fee zero" "SUCCESS|FEE_CALC|0.0000000000" \
    "$(run FEE_CALCULATE user@test.com FEE_FLAT 1000 IDR '' "$ADM")"
check "update fee rule" "SUCCESS|FEE_RULE_UPDATED" \
    "$(run FEE_RULE_UPDATE FEE_FLAT 1 50 '1000,0,0,5000' '' "$ADM")"

check "create velocity profile" "SUCCESS|VEL_PROFILE_CREATED" \
    "$(run VEL_PROFILE_CREATE VEL_TEST 'Velocity' '3600,2,1000,IDR' '' '' "$ADM")"
check_contains "list velocity profiles" "VEL_TEST:Velocity:3600:2" \
    "$(run VEL_PROFILE_LIST 50 0 '' '' '' "$ADM")"
check "velocity check allows" "SUCCESS|VELOCITY|OK|0|0.0000000000" \
    "$(run VEL_CHECK user@test.com VEL_TEST 400 IDR '' "$ADM")"
check "velocity record one" "SUCCESS|VELOCITY_RECORDED" \
    "$(run VEL_RECORD user@test.com VEL_TEST 400 IDR '' "$ADM")"
check "velocity check sees one" "SUCCESS|VELOCITY|OK|1|400.0000000000" \
    "$(run VEL_CHECK user@test.com VEL_TEST 400 IDR '' "$ADM")"
check "velocity record two" "SUCCESS|VELOCITY_RECORDED" \
    "$(run VEL_RECORD user@test.com VEL_TEST 400 IDR '' "$ADM")"
check "velocity blocks third" "SUCCESS|VELOCITY|BLOCKED|2|800.0000000000" \
    "$(run VEL_CHECK user@test.com VEL_TEST 400 IDR '' "$ADM")"
check "velocity usage" "SUCCESS|VEL_USAGE|2|800.0000000000" \
    "$(run VEL_USAGE user@test.com VEL_TEST '' '' '' "$ADM")"
check "non-admin forbidden" "ERROR|FORBIDDEN" \
    "$(run FEE_RULE_LIST 50 0 '' '' '' "$USR")"

check "fee audit rows recorded" "9" \
    "$(q "SELECT COUNT(*) FROM fee_audit WHERE actor_email IN ('$ADM','$USR');")"

echo "----------------------------------------------------------------------"
echo "PASSED: $passed  FAILED: $failed"
echo "----------------------------------------------------------------------"
[ "$failed" -eq 0 ]
