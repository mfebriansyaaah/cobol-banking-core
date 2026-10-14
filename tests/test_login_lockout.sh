#!/bin/bash
# Login lockout suite.
# Three failed AUTH_LOGIN attempts lock the account for 15 minutes. A locked
# account keeps returning the uniform INVALID_CREDENTIALS for wrong passwords
# (so lockout cannot be probed or used to enumerate accounts) and only tells a
# caller who supplies the correct password. A password reset or a good login
# clears the counter.
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
check "failed_logins reached 3" "3" "$(q "SELECT failed_logins FROM users WHERE id=931;")"
check "locked_until is set" "1" "$(q "SELECT locked_until IS NOT NULL FROM users WHERE id=931;")"

# A locked account does not reveal itself to a wrong-password guesser.
check "locked + wrong password stays uniform" "ERROR|INVALID_CREDENTIALS" "$(run AUTH_LOGIN "$U" wrong)"
# The owner who knows the password is told.
check "locked + correct password is told" "ERROR|ACCOUNT_LOCKED" "$(run AUTH_LOGIN "$U" secret123)"

# Failed attempts are recorded; being locked does not add more rows.
check "audit rows written" "3" "$(q "SELECT COUNT(*) FROM audit_trail WHERE user_id=931 AND action='AUTH_LOGIN_FAILED';")"

# A password reset clears the lockout (self-service recovery).
code=$(run FORGOT_PASSWORD "$U" '' '' '' | cut -d'|' -f3)
check "reset succeeds" "SUCCESS|PASSWORD_RESET" "$(run RESET_PASSWORD "$U" "$code" newsecret1)"
check "failed_logins cleared by reset" "0" "$(q "SELECT failed_logins FROM users WHERE id=931;")"
check "login after reset works" "SUCCESS|LOGIN_OK" "$(run AUTH_LOGIN "$U" newsecret1)"

# A good login below the threshold clears the counter too.
run AUTH_LOGIN "$U" wrong >/dev/null
run AUTH_LOGIN "$U" wrong >/dev/null
check "two failures counted" "2" "$(q "SELECT failed_logins FROM users WHERE id=931;")"
check "good login succeeds" "SUCCESS|LOGIN_OK" "$(run AUTH_LOGIN "$U" newsecret1)"
check "good login clears the counter" "0" "$(q "SELECT failed_logins FROM users WHERE id=931;")"

q "DELETE FROM users WHERE id=931; DELETE FROM verification_logs WHERE email='$U';"

echo "======================================================================"
echo -e "Tests Completed: ${GREEN}${passed} passed${NC}, ${RED}${failed} failed${NC}"
echo "======================================================================"
[ "$failed" -eq 0 ]
