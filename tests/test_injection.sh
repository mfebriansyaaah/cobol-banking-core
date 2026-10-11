#!/bin/bash
# SQL injection mitigation suite: parameters containing SQL metacharacters are
# rejected (INVALID_INPUT) by the COBOL modules, so no query can be broken even
# when the binary is called directly (defense in depth behind the gateway).
# Usage: ./tests/test_injection.sh

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

check_contains() {
    local name="$1" needle="$2" actual="$3"
    if [[ "$actual" == *"$needle"* ]]; then
        echo -e "${GREEN}PASS${NC} $name"; passed=$((passed+1))
    else
        echo -e "${RED}FAIL${NC} $name (expected to contain [$needle] got [$actual])"; failed=$((failed+1))
    fi
}

echo "======================================================================"
echo "  SQL INJECTION MITIGATION SUITE"
echo "======================================================================"

q "DELETE FROM users WHERE email LIKE 'inj%';"

check "quote in password rejected" "ERROR|INVALID_INPUT" \
    "$(run REQUEST_SIGNUP inj1@test.com "a'b" 'Name' '1990-01-01')"
check "no user written on rejected signup" "0" "$(q "SELECT COUNT(*) FROM users WHERE email='inj1@test.com';")"
check "backslash in password rejected" "ERROR|INVALID_INPUT" \
    "$(run REQUEST_SIGNUP inj2@test.com 'a\b' 'Name' '1990-01-01')"
check "semicolon in password rejected" "ERROR|INVALID_INPUT" \
    "$(run REQUEST_SIGNUP inj3@test.com 'a;b' 'Name' '1990-01-01')"
check "quote in name rejected" "ERROR|INVALID_INPUT" \
    "$(run REQUEST_SIGNUP inj4@test.com 'secret123' "O'Brien" '1990-01-01')"
check "quote in email rejected" "ERROR|INVALID_INPUT" \
    "$(run AUTH_LOGIN "x'--@test.com" 'secret123')"
check "quote in transfer email rejected" "ERROR|INVALID_INPUT" \
    "$(run TRANSFER "x'--@test.com" receiver@test.com 10.00 "")"
check "quote in idempotency key rejected" "ERROR|INVALID_INPUT" \
    "$(run TRANSFER sender@test.com receiver@test.com 10.00 "k'1")"
check_contains "clean input still works" "SUCCESS|USER_CREATED" \
    "$(run REQUEST_SIGNUP inj5@test.com 'secret123' 'Clean Name' '1990-01-01')"

q "DELETE FROM users WHERE email LIKE 'inj%';"
echo "======================================================================"
echo -e "Tests Completed: ${GREEN}${passed} passed${NC}, ${RED}${failed} failed${NC}"
echo "======================================================================"
[ "$failed" -eq 0 ]
