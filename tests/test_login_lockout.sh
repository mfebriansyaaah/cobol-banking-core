#!/bin/bash
# Login lockout suite (optional item 1).
# Three failed AUTH_LOGIN attempts within the window lock the account; a locked
# account rejects even the correct password; failed attempts are recorded.
# Usage: ./tests/test_login_lockout.sh

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
echo "  LOGIN LOCKOUT SUITE"
echo "======================================================================"

U="lock_user@test.com"
q "DELETE FROM users WHERE email='$U' OR id=931;
   INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES
   (931,'$U',CONCAT('SHA256_',SHA2('secret123',256)),'Lock User','1990-01-01','VERIFIED','USER');"

check "attempt 1 fails" "ERROR|INVALID_CREDENTIALS" "$(run AUTH_LOGIN "$U" wrong)"
check "attempt 2 fails" "ERROR|INVALID_CREDENTIALS" "$(run AUTH_LOGIN "$U" wrong)"
check "attempt 3 fails" "ERROR|INVALID_CREDENTIALS" "$(run AUTH_LOGIN "$U" wrong)"
check "attempt 4 locked" "ERROR|ACCOUNT_LOCKED" "$(run AUTH_LOGIN "$U" wrong)"
check "correct password still locked" "ERROR|ACCOUNT_LOCKED" "$(run AUTH_LOGIN "$U" secret123)"

# Failed attempts are recorded for lockout counting.
check "audit rows written" "3" "$(q "SELECT COUNT(*) FROM audit_trail WHERE user_id=931 AND action='AUTH_LOGIN_FAILED';")"

# Clearing the attempts unlocks the account.
q "DELETE FROM audit_trail WHERE user_id=931 AND action='AUTH_LOGIN_FAILED';"
check "unlocked after clearing" "SUCCESS|LOGIN_OK" "$(run AUTH_LOGIN "$U" secret123)"

echo "======================================================================"
echo -e "Tests Completed: ${GREEN}${passed} passed${NC}, ${RED}${failed} failed${NC}"
echo "======================================================================"
[ "$failed" -eq 0 ]
