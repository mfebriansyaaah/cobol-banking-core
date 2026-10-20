#!/bin/bash
# Generated smoke suite for the currency reference module.
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
       DELETE FROM currencies WHERE iso_code = 'ZZZ';
       DELETE FROM reference_audit WHERE entity = 'currencies';
       DELETE FROM users WHERE email IN ('$ADM','$USR');
       INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES
       (970,'$ADM','x','Ref Admin','1990-01-01','VERIFIED','SUPER_ADMIN'),
       (971,'$USR','x','Ref User','1990-01-01','VERIFIED','USER')
       ON DUPLICATE KEY UPDATE role=VALUES(role), status='VERIFIED';"
}
teardown() {
    q "DELETE FROM currencies WHERE iso_code = 'ZZZ';
       DELETE FROM reference_audit WHERE entity = 'currencies';
       DELETE FROM audit_trail WHERE action LIKE 'REF_CUR_%';
       DELETE FROM users WHERE email IN ('$ADM','$USR');"
}
trap 'core_stop; teardown' EXIT
core_start

echo "======================================================================"
echo "  REFERENCE currency SUITE"
echo "======================================================================"
setup

check "create ZZZ" "SUCCESS|REF_CREATED" "$(run REF_CUR_CREATE ZZZ Z 2 1 '' "$ADM")"
check_contains "list contains created key" "ZZZ" "$(run REF_CUR_LIST 20 0 '' '' '' "$ADM")"
check "get ZZZ" "SUCCESS|REF_GET|ZZZ:Z:2:1" "$(run REF_CUR_GET ZZZ '' '' '' '' "$ADM")"
check "update ZZZ" "SUCCESS|REF_UPDATED" "$(run REF_CUR_UPDATE ZZZ ZZ 3 1 '' "$ADM")"
check "get ZZZ after update" "SUCCESS|REF_GET|ZZZ:ZZ:3:1" "$(run REF_CUR_GET ZZZ '' '' '' '' "$ADM")"
check "deactivate ZZZ" "SUCCESS|REF_DEACTIVATED" "$(run REF_CUR_DEACT ZZZ '' '' '' '' "$ADM")"
check "get ZZZ after deactivate" "SUCCESS|REF_GET|ZZZ:ZZ:3:0" "$(run REF_CUR_GET ZZZ '' '' '' '' "$ADM")"
check "duplicate create rejected" "ERROR|DUPLICATE" "$(run REF_CUR_CREATE ZZZ Z 2 1 '' "$ADM")"
check "non-admin forbidden" "ERROR|FORBIDDEN" "$(run REF_CUR_LIST 20 0 '' '' '' "$USR")"
check "bad key rejected" "ERROR|INVALID_INPUT" "$(run REF_CUR_CREATE ZZ Z 2 1 '' "$ADM")"
check "audit rows recorded" "3" "$(q "SELECT COUNT(*) FROM reference_audit WHERE entity='currencies' AND entity_key='ZZZ';")"

echo "----------------------------------------------------------------------"
echo "PASSED: $passed  FAILED: $failed"
echo "----------------------------------------------------------------------"
[ "$failed" -eq 0 ]
