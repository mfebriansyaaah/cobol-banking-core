#!/bin/bash
# Session management suite: list active refresh sessions, revoke one (owner or
# admin only, and only your own), and revoke-all (bumps the access-token version
# and revokes every refresh session).
# Usage: ./tests/test_sessions_manage.sh

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
echo "  SESSION MANAGEMENT SUITE"
echo "======================================================================"

U="sess_own@test.com"; ADM="sess_admin@test.com"
q "DELETE FROM users WHERE email IN ('$U','$ADM');
   INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES
   (960,'$U',CONCAT('SHA256_',SHA2('secret123',256)),'Sess Own','1990-01-01','VERIFIED','USER'),
   (961,'$ADM',CONCAT('SHA256_',SHA2('secret123',256)),'Sess Admin','1990-01-01','VERIFIED','SUPER_ADMIN');"

run STORE_SESSION sessjti001 "$U" 30 famA >/dev/null
run STORE_SESSION sessjti002 "$U" 30 famB >/dev/null

# --- list ----------------------------------------------------------------
out=$(run LIST_SESSIONS "$U" "$U")
check_contains "list returns SESSIONS" "SUCCESS|SESSIONS|" "$out"
check_contains "list has session 1" "sessjti001" "$out"
check_contains "list has session 2" "sessjti002" "$out"
check "list is owner-or-admin only" "ERROR|FORBIDDEN" "$(run LIST_SESSIONS "$U" other@test.com)"
check_contains "admin can list" "sessjti001" "$(run LIST_SESSIONS "$U" "$ADM")"

# --- revoke one ----------------------------------------------------------
check "revoke needs ownership" "ERROR|FORBIDDEN" "$(run REVOKE_USER_SESSION "$U" other@test.com sessjti001)"
check "unknown session" "ERROR|SESSION_NOT_FOUND" "$(run REVOKE_USER_SESSION "$U" "$U" nosuchjti)"
check "revoke a session" "SUCCESS|SESSION_REVOKED" "$(run REVOKE_USER_SESSION "$U" "$U" sessjti001)"
check "revoked session is gone from list" "0" "$(q "SELECT COUNT(*) FROM refresh_sessions WHERE jti='sessjti001' AND revoked=0;")"
check "other sessions untouched" "1" "$(q "SELECT COUNT(*) FROM refresh_sessions WHERE jti='sessjti002' AND revoked=0;")"

# A session that belongs to someone else cannot be revoked by targeting it
# under your own account (the WHERE ties it to the target email).
q "DELETE FROM refresh_sessions WHERE email='$ADM';"
run STORE_SESSION adminjti01 "$ADM" 30 famC >/dev/null
check "cannot revoke another account's session" "ERROR|SESSION_NOT_FOUND" "$(run REVOKE_USER_SESSION "$U" "$U" adminjti01)"

# --- revoke all ----------------------------------------------------------
before=$(q "SELECT token_version FROM users WHERE email='$U';")
check "revoke all" "SUCCESS|SESSIONS_REVOKED" "$(run REVOKE_ALL_SESSIONS "$U" "$U")"
check "token version bumped" "1" "$(q "SELECT 1 WHERE (SELECT token_version FROM users WHERE email='$U') > $before;")"
check "no active sessions left" "0" "$(q "SELECT COUNT(*) FROM refresh_sessions WHERE email='$U' AND revoked=0;")"
check "revoke all audited" "1" "$(q "SELECT COUNT(*) FROM audit_trail a JOIN users u ON u.id=a.user_id WHERE u.email='$U' AND a.action='SESSIONS_REVOKED';")"

q "DELETE FROM users WHERE email IN ('$U','$ADM');"

echo "======================================================================"
echo -e "Tests Completed: ${GREEN}${passed} passed${NC}, ${RED}${failed} failed${NC}"
echo "======================================================================"
[ "$failed" -eq 0 ]
