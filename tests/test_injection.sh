#!/bin/bash
# SQL injection safety suite.
# auth_core ESCAPES values (mysql_real_escape_string), so metacharacters are
# accepted literally and cannot break a query. user_core/wallet_core are still
# whitelist-only (they reject metacharacters). Either way, no injection.
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
echo "  SQL INJECTION SAFETY SUITE"
echo "======================================================================"

q "DELETE FROM verification_logs WHERE email LIKE 'inj%'; DELETE FROM users WHERE email LIKE 'inj%';"

# auth escapes values, so metacharacters are accepted literally (no error, no injection).
out=$(run REQUEST_SIGNUP inj1@test.com "a'b\\c;dE" "O'Brien" '1990-01-01')
check_contains "metacharacters accepted (escaped)" "SUCCESS|USER_CREATED" "$out"
code=$(echo "$out" | cut -d'|' -f3)
check "apostrophe name stored literally" "O'Brien" "$(q "SELECT full_name FROM users WHERE email='inj1@test.com';")"
check "verify with metachar password" "SUCCESS|EMAIL_VERIFIED" "$(run VERIFY_EMAIL inj1@test.com "$code")"
check "login with metachar password" "SUCCESS|LOGIN_OK" "$(run AUTH_LOGIN inj1@test.com "a'b\\c;dE")"

# Bridge diagnostics must not leak the concatenated SQL (emails) to stderr.
printf "%s|%s|%s|%s|%s\n" "AUTH_LOGIN" "inj1@test.com" "secret" "" "" > input.txt
diag=$("$BIN" 2>&1 >/dev/null)
case "$diag" in
    *"[SQL_BRIDGE]"*) check "bridge diagnostic marker emitted" "ok" "ok" ;;
    *) check "bridge diagnostic marker emitted" "ok" "missing" ;;
esac
case "$diag" in
    *"inj1@test.com"*) check "no email in diagnostics" "absent" "present" ;;
    *) check "no email in diagnostics" "absent" "absent" ;;
esac

# An injection-shaped password is just a literal; it cannot create rows or drop anything.
out=$(run REQUEST_SIGNUP inj2@test.com "x') OR 1=1--zz" "Bobby Tables" '1990-01-01')
check_contains "injection-shaped password is literal" "SUCCESS|USER_CREATED" "$out"
check "no unexpected admin user" "0" "$(q "SELECT COUNT(*) FROM users WHERE email='inj2@test.com' AND role='SUPER_ADMIN';")"
check "users table intact" "1" "$(q "SELECT COUNT(*) > 0 FROM users WHERE email='inj2@test.com';")"

# user_core / wallet_core remain whitelist-only: metacharacters rejected.
check "wallet email with quote rejected" "ERROR|INVALID_INPUT" \
    "$(run TRANSFER "x'--@test.com" receiver@test.com 10.00 "")"
check "user lookup email with quote rejected" "ERROR|INVALID_INPUT" \
    "$(run GET_USER "x'--@test.com" "" "")"

q "DELETE FROM verification_logs WHERE email LIKE 'inj%'; DELETE FROM users WHERE email LIKE 'inj%';"
echo "======================================================================"
echo -e "Tests Completed: ${GREEN}${passed} passed${NC}, ${RED}${failed} failed${NC}"
echo "======================================================================"
[ "$failed" -eq 0 ]
