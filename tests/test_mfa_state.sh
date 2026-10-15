#!/bin/bash
# MFA-state suite: GET_MFA_STATE returns the role and MFA flag the gateway uses
# to prompt an admin (SUPER_ADMIN/MANAGER) to enrol MFA at login.
# Usage: ./tests/test_mfa_state.sh

BIN="./cobol/bin/main_logic"

if [ -f ./tests/.dbenv ]; then . ./tests/.dbenv; fi
DB_USER="${DB_USER:-cobol_user}"
DB_PASS="${DB_PASS:-cobol_pass}"
DB_NAME="${DB_NAME:-cobol_db}"

GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
passed=0; failed=0

q() { mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -N -B -e "$1" 2>/dev/null; }

run() {
    printf "%s|%s|%s|%s|%s\n" "$1" "$2" "$3" "$4" "$5" > input.txt
    "$BIN" >/dev/null 2>&1
    cat output.txt
}

check() {
    local name="$1" expected="$2" actual="$3"
    if [ "$actual" = "$expected" ]; then
        echo -e "${GREEN}PASS${NC} $name"; passed=$((passed+1))
    else
        echo -e "${RED}FAIL${NC} $name (expected [$expected] got [$actual])"; failed=$((failed+1))
    fi
}

echo "======================================================================"
echo "  MFA-STATE SUITE (GET_MFA_STATE)"
echo "======================================================================"

q "DELETE FROM users WHERE email IN ('mf_a@test.com','mf_b@test.com','mf_m@test.com','mf_u@test.com');
   INSERT INTO users (id,email,password_hash,full_name,dob,status,role,mfa_enabled) VALUES
   (890,'mf_a@test.com','x','A','1990-01-01','VERIFIED','SUPER_ADMIN',FALSE),
   (891,'mf_b@test.com','x','B','1990-01-01','VERIFIED','SUPER_ADMIN',TRUE),
   (892,'mf_m@test.com','x','M','1990-01-01','VERIFIED','MANAGER',FALSE),
   (893,'mf_u@test.com','x','U','1990-01-01','VERIFIED','USER',FALSE);"

check "super without MFA" "SUCCESS|SUPER_ADMIN|0" "$(run GET_MFA_STATE mf_a@test.com)"
check "super with MFA" "SUCCESS|SUPER_ADMIN|1" "$(run GET_MFA_STATE mf_b@test.com)"
check "manager without MFA" "SUCCESS|MANAGER|0" "$(run GET_MFA_STATE mf_m@test.com)"
check "plain user" "SUCCESS|USER|0" "$(run GET_MFA_STATE mf_u@test.com)"
check "unknown account" "ERROR|ACCOUNT_NOT_FOUND" "$(run GET_MFA_STATE ghost_mf@test.com)"

q "DELETE FROM users WHERE email IN ('mf_a@test.com','mf_b@test.com','mf_m@test.com','mf_u@test.com');"

echo "======================================================================"
echo -e "Tests Completed: ${GREEN}${passed} passed${NC}, ${RED}${failed} failed${NC}"
echo "======================================================================"
[ "$failed" -eq 0 ]
