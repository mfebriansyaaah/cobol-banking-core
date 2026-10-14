#!/bin/bash
# Password reset / change suite: FORGOT_PASSWORD issues a reset code (only for an
# existing account), RESET_PASSWORD consumes it and revokes sessions, and
# CHANGE_PASSWORD requires the current password and the owner actor.
# Usage: ./tests/test_password.sh

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
echo "  PASSWORD RESET / CHANGE SUITE"
echo "======================================================================"

EMAIL="pw_test@test.com"
q "DELETE FROM verification_logs WHERE email='$EMAIL'; DELETE FROM users WHERE email='$EMAIL';"
out=$(run REQUEST_SIGNUP "$EMAIL" secret123 'PW User' '1990-01-01')
code=$(echo "$out" | cut -d'|' -f3)
run VERIFY_EMAIL "$EMAIL" "$code" >/dev/null

# --- FORGOT / RESET ---
before=$(q "SELECT token_version FROM users WHERE email='$EMAIL';")
out=$(run FORGOT_PASSWORD "$EMAIL" "" "" "")
check_contains "forgot sends a code" "SUCCESS|CODE_SENT|" "$out"
rcode=$(echo "$out" | cut -d'|' -f3)
case "$rcode" in [0-9][0-9][0-9][0-9][0-9][0-9]) check "reset code is 6 digits" "ok" "ok" ;; *) check "reset code is 6 digits" "6 digits" "$rcode" ;; esac
check "forgot unknown is neutral" "SUCCESS|CODE_SENT" "$(run FORGOT_PASSWORD ghost_pw@test.com "" "" "")"

check "weak new password rejected" "ERROR|WEAK_PASSWORD" "$(run RESET_PASSWORD "$EMAIL" "$rcode" short)"
check "wrong code rejected" "ERROR|INVALID_CODE" "$(run RESET_PASSWORD "$EMAIL" 000000 test1234)"
check "reset with the code" "SUCCESS|PASSWORD_RESET" "$(run RESET_PASSWORD "$EMAIL" "$rcode" test1234)"
check "login with new password" "SUCCESS|LOGIN_OK" "$(run AUTH_LOGIN "$EMAIL" test1234)"
check "old password rejected" "ERROR|INVALID_CREDENTIALS" "$(run AUTH_LOGIN "$EMAIL" secret123)"
check "reset code is single use" "ERROR|INVALID_CODE" "$(run RESET_PASSWORD "$EMAIL" "$rcode" other1234)"
after=$(q "SELECT token_version FROM users WHERE email='$EMAIL';")
check "reset bumped the token version" "1" "$(q "SELECT 1 WHERE $after > $before;")"

# --- CHANGE PASSWORD (owner only) ---
check "change requires the current password" "ERROR|INVALID_CREDENTIALS" "$(run CHANGE_PASSWORD "$EMAIL" wrongpass newpass12 "$EMAIL")"
check "change is owner-only" "ERROR|FORBIDDEN" "$(run CHANGE_PASSWORD "$EMAIL" test1234 newpass12 sender@test.com)"
check "change with the current password" "SUCCESS|PASSWORD_CHANGED" "$(run CHANGE_PASSWORD "$EMAIL" test1234 newpass12 "$EMAIL")"
check "login with changed password" "SUCCESS|LOGIN_OK" "$(run AUTH_LOGIN "$EMAIL" newpass12)"

q "DELETE FROM verification_logs WHERE email='$EMAIL'; DELETE FROM users WHERE email='$EMAIL';"
echo "======================================================================"
echo -e "Tests Completed: ${GREEN}${passed} passed${NC}, ${RED}${failed} failed${NC}"
echo "======================================================================"
[ "$failed" -eq 0 ]
