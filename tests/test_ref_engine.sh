#!/bin/bash
# Generic reference-data engine suite (Phase 1).
# Covers type/value creation, DRAFT -> ACTIVE -> RETIRED lifecycle, history,
# authorization, duplicate rejection, and audit rows.
# Usage: ./tests/test_ref_engine.sh

BIN="./cobol/bin/main_logic"
. ./tests/serve_harness.sh

if [ -f ./tests/.dbenv ]; then . ./tests/.dbenv; fi
DB_USER="${DB_USER:-cobol_user}"
DB_PASS="${DB_PASS:-cobol_pass}"
DB_NAME="${DB_NAME:-cobol_db}"

GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
passed=0; failed=0

q() { mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -N -B -e "$1" 2>/dev/null; }
run() { core_run "$@"; }

check() {
    local name="$1" expected="$2" actual="$3"
    if [ "$actual" = "$expected" ]; then
        echo -e "${GREEN}PASS${NC} $name"; passed=$((passed+1))
    else
        echo -e "${RED}FAIL${NC} $name (expected [$expected] got [$actual])"; failed=$((failed+1))
    fi
}

check_contains() {
    local name="$1" needle="$2" actual="$3"
    if [[ "$actual" == *"$needle"* ]]; then
        echo -e "${GREEN}PASS${NC} $name"; passed=$((passed+1))
    else
        echo -e "${RED}FAIL${NC} $name (expected to contain [$needle] got [$actual])"; failed=$((failed+1))
    fi
}

ADM="refeng_admin@test.com"
USR="refeng_user@test.com"

setup() {
    q "DELETE FROM ref_engine_audit WHERE type_code='test_type';
       DELETE FROM ref_value_version WHERE ref_value_id IN (SELECT id FROM ref_value WHERE type_code='test_type');
       DELETE FROM ref_value WHERE type_code='test_type';
       DELETE FROM ref_type WHERE type_code='test_type';
       DELETE FROM users WHERE email IN ('$ADM','$USR');
       INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES
       (980,'$ADM','x','Ref Engine Admin','1990-01-01','VERIFIED','SUPER_ADMIN'),
       (981,'$USR','x','Ref Engine User','1990-01-01','VERIFIED','USER')
       ON DUPLICATE KEY UPDATE role=VALUES(role), status='VERIFIED';"
}

teardown() {
    q "DELETE FROM ref_engine_audit WHERE type_code='test_type';
       DELETE FROM ref_value_version WHERE ref_value_id IN (SELECT id FROM ref_value WHERE type_code='test_type');
       DELETE FROM ref_value WHERE type_code='test_type';
       DELETE FROM ref_type WHERE type_code='test_type';
       DELETE FROM audit_trail WHERE action='AUTHZ_DENIED' AND actor_id=981;
       DELETE FROM users WHERE email IN ('$ADM','$USR');"
}

trap 'core_stop; teardown' EXIT
core_start

echo "======================================================================"
echo "  REFERENCE ENGINE SUITE (PHASE 1)"
echo "======================================================================"
setup

check "create type" "SUCCESS|RFE_TYPE_CREATED" \
    "$(run RFE_TYPE_CREATE test_type 'Test Type' 'Test description' '' '' "$ADM")"
check_contains "list types" "test_type:Test Type:1" \
    "$(run RFE_TYPE_LIST 50 0 '' '' '' "$ADM")"
check "create value" "SUCCESS|RFE_VALUE_CREATED|1" \
    "$(run RFE_VALUE_CREATE test_type TEST_CODE 'Test Value' 'x:1' '' "$ADM")"
check_contains "list values" "TEST_CODE:Test Value:1:DRAFT" \
    "$(run RFE_VALUE_LIST test_type 50 0 '' '' "$ADM")"
check_contains "get draft" "TEST_CODE:Test Value:1:DRAFT" \
    "$(run RFE_VALUE_GET test_type TEST_CODE '' '' '' "$ADM")"
check "approve" "SUCCESS|RFE_VALUE_APPROVED" \
    "$(run RFE_VALUE_APPROVE test_type TEST_CODE 1 '' '' "$ADM")"
check_contains "get active" "TEST_CODE:Test Value:1:ACTIVE" \
    "$(run RFE_VALUE_GET test_type TEST_CODE '' '' '' "$ADM")"
check_contains "history shows the active version" "1:ACTIVE:Test Value" \
    "$(run RFE_VALUE_HIST test_type TEST_CODE '' '' '' "$ADM")"
check "retire" "SUCCESS|RFE_VALUE_RETIRED" \
    "$(run RFE_VALUE_RETIRE test_type TEST_CODE 'cleanup' '' '' "$ADM")"
check_contains "get retired" "TEST_CODE:Test Value:1:RETIRED" \
    "$(run RFE_VALUE_GET test_type TEST_CODE '' '' '' "$ADM")"
check "non-admin forbidden" "ERROR|FORBIDDEN" \
    "$(run RFE_TYPE_LIST 50 0 '' '' '' "$USR")"
check "duplicate rejected" "ERROR|DUPLICATE" \
    "$(run RFE_VALUE_CREATE test_type TEST_CODE 'Again' 'x:2' '' "$ADM")"
check "invalid type rejected" "ERROR|INVALID_INPUT" \
    "$(run RFE_TYPE_CREATE '' 'Bad' '' '' '' "$ADM")"
check_contains "country cutover list" "ID:Indonesia:1:ACTIVE" \
    "$(run RFE_VALUE_LIST country 50 0 '' '' "$ADM")"
check_contains "country cutover get" "ID:Indonesia:1:ACTIVE" \
    "$(run RFE_VALUE_GET country ID '' '' '' "$ADM")"
check_contains "holiday cutover list" "NEWYEAR:New Year:1:ACTIVE" \
    "$(run RFE_VALUE_LIST holiday 50 0 '' '' "$ADM")"
check_contains "holiday cutover get" "NEWYEAR:New Year:1:ACTIVE" \
    "$(run RFE_VALUE_GET holiday NEWYEAR '' '' '' "$ADM")"

check_contains "fee code cutover list" "TRANSF:Transfer fee:1:ACTIVE" \
    "$(run RFE_VALUE_LIST fee_code 50 0 '' '' "$ADM")"
check_contains "fee code cutover get" "TRANSF:Transfer fee:1:ACTIVE" \
    "$(run RFE_VALUE_GET fee_code TRANSF '' '' '' "$ADM")"
check_contains "limit type cutover list" "DAILYL:Daily limit:1:ACTIVE" \
    "$(run RFE_VALUE_LIST limit_type 50 0 '' '' "$ADM")"
check_contains "limit type cutover get" "DAILYL:Daily limit:1:ACTIVE" \
    "$(run RFE_VALUE_GET limit_type DAILYL '' '' '' "$ADM")"
check_contains "product type cutover list" "EWALLT:E-wallet:1:ACTIVE" \
    "$(run RFE_VALUE_LIST product_type 50 0 '' '' "$ADM")"
check_contains "product type cutover get" "EWALLT:E-wallet:1:ACTIVE" \
    "$(run RFE_VALUE_GET product_type EWALLT '' '' '' "$ADM")"

check "audit rows recorded" "4" \
    "$(q "SELECT COUNT(*) FROM ref_engine_audit WHERE type_code='test_type';")"

echo "----------------------------------------------------------------------"
echo "PASSED: $passed  FAILED: $failed"
echo "----------------------------------------------------------------------"
[ "$failed" -eq 0 ]
