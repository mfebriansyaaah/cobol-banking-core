#!/bin/bash
# AUTH_LOGIN suite (Phase 3b).
# Verifies login: success only for VERIFIED + correct password; distinct errors
# for unknown account, wrong password, and unverified account.
# Usage: ./tests/test_auth_login.sh

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
echo "  AUTH_LOGIN SUITE"
echo "======================================================================"

# Dedicated, isolated users (do not touch sender@/receiver@).
q "DELETE FROM users WHERE email IN ('login_ok@test.com','login_unverified@test.com');
   INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES
   (901,'login_ok@test.com',CONCAT('SHA256_',SHA2('secret',256)),'OK User','1990-01-01','VERIFIED','USER'),
   (902,'login_unverified@test.com',CONCAT('SHA256_',SHA2('secret',256)),'Unv User','1990-01-01','UNVERIFIED','USER');"

check "verified + correct password" "SUCCESS|LOGIN_OK" \
    "$(run AUTH_LOGIN login_ok@test.com secret "")"
check "wrong password" "ERROR|INVALID_CREDENTIALS" \
    "$(run AUTH_LOGIN login_ok@test.com wrong "")"
check "unverified account" "ERROR|UNVERIFIED" \
    "$(run AUTH_LOGIN login_unverified@test.com secret "")"
check "unknown account" "ERROR|ACCOUNT_NOT_FOUND" \
    "$(run AUTH_LOGIN ghost@test.com secret "")"
check "unknown action routes to invalid" "ERROR|INVALID_ACTION" \
    "$(run NOPE login_ok@test.com secret "")"

echo "======================================================================"
echo -e "Tests Completed: ${GREEN}${passed} passed${NC}, ${RED}${failed} failed${NC}"
echo "======================================================================"
[ "$failed" -eq 0 ]
