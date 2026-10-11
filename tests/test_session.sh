#!/bin/bash
# Refresh-session suite: STORE/CHECK/REVOKE_SESSION drive refresh-token
# revocation for the gateway.
# Usage: ./tests/test_session.sh

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
echo "  REFRESH SESSION SUITE"
echo "======================================================================"

q "DELETE FROM refresh_sessions WHERE jti LIKE 'jti-sh%';"
q "INSERT IGNORE INTO users (id,email,password_hash,full_name,dob,status,role) VALUES (970,'sess@test.com','x','Sess','1990-01-01','VERIFIED','USER');"

check "store session" "SUCCESS|SESSION_STORED" "$(run STORE_SESSION jti-sh-1 sess@test.com 7)"
check "check valid" "SUCCESS|SESSION_VALID" "$(run CHECK_SESSION jti-sh-1)"
check "revoke session" "SUCCESS|SESSION_REVOKED" "$(run REVOKE_SESSION jti-sh-1)"
check "check revoked" "ERROR|SESSION_REVOKED" "$(run CHECK_SESSION jti-sh-1)"
check "check unknown" "ERROR|SESSION_REVOKED" "$(run CHECK_SESSION jti-sh-nope)"

q "DELETE FROM refresh_sessions WHERE jti LIKE 'jti-sh%'; DELETE FROM users WHERE id=970;"
echo "======================================================================"
echo -e "Tests Completed: ${GREEN}${passed} passed${NC}, ${RED}${failed} failed${NC}"
echo "======================================================================"
[ "$failed" -eq 0 ]
