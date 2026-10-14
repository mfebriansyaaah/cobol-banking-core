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

check "store session" "SUCCESS|SESSION_STORED" "$(run STORE_SESSION jti-sh-1 sess@test.com 7 jti-sh-fam)"
check "consume session" "SUCCESS|SESSION_CONSUMED" "$(run CONSUME_SESSION jti-sh-1)"
check "revoke session (logout)" "SUCCESS|SESSION_REVOKED" "$(run REVOKE_SESSION jti-sh-1)"
check "logged-out token is gone" "ERROR|SESSION_NOT_FOUND" "$(run CONSUME_SESSION jti-sh-1)"
check "unknown session" "ERROR|SESSION_NOT_FOUND" "$(run CONSUME_SESSION jti-sh-nope)"

# Replaying a token revoked by rotation is reuse: the whole family is revoked.
run STORE_SESSION jti-sh-a sess@test.com 7 fam2 >/dev/null
run STORE_SESSION jti-sh-b sess@test.com 7 fam2 >/dev/null
run CONSUME_SESSION jti-sh-a >/dev/null
check "reuse detected on family" "ERROR|SESSION_REUSED" "$(run CONSUME_SESSION jti-sh-a)"
check "family fully revoked" "2" "$(q "SELECT COUNT(*) FROM refresh_sessions WHERE family='fam2' AND revoked=1;")"
check "sibling is now reused/revoked" "ERROR|SESSION_REUSED" "$(run CONSUME_SESSION jti-sh-b)"

# Expired sessions are pruned when a new session is stored.
q "INSERT INTO refresh_sessions (jti,family,email,expires_at) VALUES ('jti-sh-exp','jti-sh-exp','sess@test.com', DATE_SUB(NOW(), INTERVAL 1 DAY));"
run STORE_SESSION jti-sh-new sess@test.com 7 jti-sh-new >/dev/null
check "expired session pruned" "0" "$(q "SELECT COUNT(*) FROM refresh_sessions WHERE jti='jti-sh-exp';")"

# Access-token version: revoking bumps it so already-issued tokens stop working.
TV=$(run GET_TOKEN_VERSION sess@test.com); TV=${TV##*|}
check "token valid at current version" "SUCCESS|TOKEN_VALID" "$(run CHECK_TOKEN sess@test.com "$TV")"
check "wrong version is revoked" "ERROR|TOKEN_REVOKED" "$(run CHECK_TOKEN sess@test.com 99999)"
check "unknown user token check" "ERROR|ACCOUNT_NOT_FOUND" "$(run CHECK_TOKEN ghost_tok@test.com 1)"
check "revoke all sessions" "SUCCESS|SESSIONS_REVOKED" "$(run REVOKE_ALL_SESSIONS sess@test.com sess@test.com)"
check "previous version now revoked" "ERROR|TOKEN_REVOKED" "$(run CHECK_TOKEN sess@test.com "$TV")"

# Per-token denylist: one jti can be revoked without bumping the version.
TJ=$(run GET_TOKEN_VERSION sess@test.com); TJ=${TJ##*|}
check "jti valid before revoke" "SUCCESS|TOKEN_VALID" "$(run CHECK_TOKEN sess@test.com "$TJ" jti-den-1)"
check "revoke access token" "SUCCESS|TOKEN_REVOKED" "$(run REVOKE_ACCESS_TOKEN jti-den-1 sess@test.com 900)"
check "jti revoked after" "ERROR|TOKEN_REVOKED" "$(run CHECK_TOKEN sess@test.com "$TJ" jti-den-1)"
check "other jti still valid" "SUCCESS|TOKEN_VALID" "$(run CHECK_TOKEN sess@test.com "$TJ" jti-den-2)"

q "DELETE FROM refresh_sessions WHERE jti LIKE 'jti-sh%'; DELETE FROM users WHERE id=970;"
echo "======================================================================"
echo -e "Tests Completed: ${GREEN}${passed} passed${NC}, ${RED}${failed} failed${NC}"
echo "======================================================================"
[ "$failed" -eq 0 ]
