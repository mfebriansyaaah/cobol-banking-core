#!/bin/bash
# Generated smoke suite for the timezone_region reference module.
set -u
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

ADM="ref_admin@test.com"
USR="ref_user@test.com"
setup() {
    q "CREATE TABLE IF NOT EXISTS reference_audit (
         id INT AUTO_INCREMENT PRIMARY KEY,
         entity VARCHAR(64) NOT NULL,
         entity_key VARCHAR(128) NOT NULL,
         action VARCHAR(32) NOT NULL,
         actor_email VARCHAR(100),
         created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
       ) ENGINE=InnoDB;
       CREATE TABLE IF NOT EXISTS ref_timezone_region (     code VARCHAR(6) PRIMARY KEY,     label VARCHAR(64) NOT NULL,     num_val INT NOT NULL DEFAULT 0,     is_active BOOLEAN NOT NULL DEFAULT TRUE,     updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP ) ENGINE=InnoDB;
       DELETE FROM ref_timezone_region WHERE code = 'ZZZZZZ';
       DELETE FROM reference_audit WHERE entity = 'ref_timezone_region';
       DELETE FROM users WHERE email IN ('$ADM','$USR');
       INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES
       (970,'$ADM','x','Ref Admin','1990-01-01','VERIFIED','SUPER_ADMIN'),
       (971,'$USR','x','Ref User','1990-01-01','VERIFIED','USER')
       ON DUPLICATE KEY UPDATE role=VALUES(role), status='VERIFIED';"
}
teardown() {
    q "DELETE FROM ref_timezone_region WHERE code = 'ZZZZZZ';
       DELETE FROM reference_audit WHERE entity = 'ref_timezone_region';
       DELETE FROM audit_trail WHERE action LIKE 'REF_TZR_%';
       DELETE FROM users WHERE email IN ('$ADM','$USR');"
}
trap 'core_stop; teardown' EXIT
core_start

echo "======================================================================"
echo "  REFERENCE timezone_region SUITE"
echo "======================================================================"
setup

check "create ZZZZZZ" "SUCCESS|REF_CREATED" "$(run REF_TZR_CREATE ZZZZZZ Z 2 1 '' "$ADM")"
check_contains "list contains created key" "ZZZZZZ" "$(run REF_TZR_LIST 20 0 '' '' '' "$ADM")"
check "get ZZZZZZ" "SUCCESS|REF_GET|ZZZZZZ:Z:2:1" "$(run REF_TZR_GET ZZZZZZ '' '' '' '' "$ADM")"
check "update ZZZZZZ" "SUCCESS|REF_UPDATED" "$(run REF_TZR_UPDATE ZZZZZZ ZZ 3 1 '' "$ADM")"
check "get ZZZZZZ after update" "SUCCESS|REF_GET|ZZZZZZ:ZZ:3:1" "$(run REF_TZR_GET ZZZZZZ '' '' '' '' "$ADM")"
check "deactivate ZZZZZZ" "SUCCESS|REF_DEACTIVATED" "$(run REF_TZR_DEACT ZZZZZZ '' '' '' '' "$ADM")"
check "get ZZZZZZ after deactivate" "SUCCESS|REF_GET|ZZZZZZ:ZZ:3:0" "$(run REF_TZR_GET ZZZZZZ '' '' '' '' "$ADM")"
check "duplicate create rejected" "ERROR|DUPLICATE" "$(run REF_TZR_CREATE ZZZZZZ Z 2 1 '' "$ADM")"
check "non-admin forbidden" "ERROR|FORBIDDEN" "$(run REF_TZR_LIST 20 0 '' '' '' "$USR")"
check "bad key rejected" "ERROR|INVALID_INPUT" "$(run REF_TZR_CREATE ZZZZZ Z 2 1 '' "$ADM")"
check "audit rows recorded" "3" "$(q "SELECT COUNT(*) FROM reference_audit WHERE entity='ref_timezone_region' AND entity_key='ZZZZZZ';")"

echo "----------------------------------------------------------------------"
echo "PASSED: $passed  FAILED: $failed"
echo "----------------------------------------------------------------------"
[ "$failed" -eq 0 ]
