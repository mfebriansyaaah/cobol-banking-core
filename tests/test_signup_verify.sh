#!/bin/bash
# REQUEST_SIGNUP + VERIFY_EMAIL suite (Phase 3c).
# Verifies signup creates an UNVERIFIED user with a 6-digit code, enforces
# password strength and email uniqueness, and that VERIFY_EMAIL flips status to
# VERIFIED exactly once.
# Usage: ./tests/test_signup_verify.sh

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
echo "  SIGNUP + VERIFY EMAIL SUITE"
echo "======================================================================"

EMAIL="signup_ok@test.com"
q "DELETE FROM verification_logs WHERE email='$EMAIL'; DELETE FROM users WHERE email='$EMAIL';"

# Weak password is rejected before any row is written.
check "weak password rejected" "ERROR|WEAK_PASSWORD" \
    "$(run REQUEST_SIGNUP "$EMAIL" short 'Sign Up' '1990-01-01')"
check "no user written on weak password" "0" "$(q "SELECT COUNT(*) FROM users WHERE email='$EMAIL';")"

# Successful signup returns a code and leaves the user UNVERIFIED.
out=$(run REQUEST_SIGNUP "$EMAIL" secret123 'Sign Up' '1990-01-01')
code=$(echo "$out" | cut -d'|' -f3)
case "$out" in
    SUCCESS\|USER_CREATED\|[0-9][0-9][0-9][0-9][0-9][0-9]) check "signup returns code" "ok" "ok" ;;
    *) check "signup returns code" "SUCCESS|USER_CREATED|<6 digits>" "$out" ;;
esac
check "user status UNVERIFIED" "UNVERIFIED" "$(q "SELECT status FROM users WHERE email='$EMAIL';")"
check "email stored without padding" "18" "$(q "SELECT CHAR_LENGTH(email) FROM users WHERE email='$EMAIL';")"
check "verification log written" "1" "$(q "SELECT COUNT(*) FROM verification_logs WHERE email='$EMAIL' AND purpose='SIGNUP' AND is_used=0;")"

# Duplicate email is rejected.
check "duplicate email rejected" "ERROR|EMAIL_EXISTS" \
    "$(run REQUEST_SIGNUP "$EMAIL" secret123 'Sign Up' '1990-01-01')"

# Wrong code rejected; correct code verifies; reuse rejected.
check "wrong code rejected" "ERROR|INVALID_CODE" "$(run VERIFY_EMAIL "$EMAIL" 000000)"
check "correct code verifies" "SUCCESS|EMAIL_VERIFIED" "$(run VERIFY_EMAIL "$EMAIL" "$code")"
check "user status VERIFIED" "VERIFIED" "$(q "SELECT status FROM users WHERE email='$EMAIL';")"
check "code marked used" "1" "$(q "SELECT is_used FROM verification_logs WHERE email='$EMAIL' AND code='$code';")"
check "reused code rejected" "ERROR|INVALID_CODE" "$(run VERIFY_EMAIL "$EMAIL" "$code")"

# After verification, login works.
check "login after verify" "SUCCESS|LOGIN_OK" "$(run AUTH_LOGIN "$EMAIL" secret123)"

echo "======================================================================"
echo -e "Tests Completed: ${GREEN}${passed} passed${NC}, ${RED}${failed} failed${NC}"
echo "======================================================================"
[ "$failed" -eq 0 ]
