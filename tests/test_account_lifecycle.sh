#!/bin/bash
# Account lifecycle suite: self-service deactivation (soft-close) and admin
# status changes (SUSPENDED/CLOSED/VERIFIED); login honours the status and
# side effects force a clean re-login.
# Usage: ./tests/test_account_lifecycle.sh

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
echo "  ACCOUNT LIFECYCLE SUITE"
echo "======================================================================"

U="lc_user@test.com"; ADM="lc_admin@test.com"
q "DELETE FROM refresh_sessions WHERE email IN ('$U','$ADM'); DELETE FROM users WHERE email IN ('$U','$ADM');
   INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES
   (966,'$U',CONCAT('SHA256_',SHA2('secret123',256)),'Life User','1990-01-01','VERIFIED','USER'),
   (967,'$ADM','x','Life Admin','1990-01-01','VERIFIED','SUPER_ADMIN');"
q "INSERT INTO refresh_sessions (jti, family, email, expires_at) VALUES ('lcjti','lcfam','$U', DATE_ADD(NOW(), INTERVAL 7 DAY));"

# --- self deactivation ---------------------------------------------------
check "deactivate self" "SUCCESS|ACCOUNT_DEACTIVATED" "$(run DEACTIVATE_ACCOUNT "$U" "$U")"
check "status is CLOSED" "CLOSED" "$(q "SELECT status FROM users WHERE email='$U';")"
check "token version bumped" "2" "$(q "SELECT token_version FROM users WHERE email='$U';")"
check "session revoked" "1" "$(q "SELECT revoked FROM refresh_sessions WHERE jti='lcjti';")"
check "login on a closed account" "ERROR|USER_CLOSED" "$(run AUTH_LOGIN "$U" secret123)"
check "deactivate another user forbidden" "ERROR|FORBIDDEN" "$(run DEACTIVATE_ACCOUNT "$U" "$ADM")"
check "deactivate unknown user" "ERROR|ACCOUNT_NOT_FOUND" "$(run DEACTIVATE_ACCOUNT ghost_lc@test.com ghost_lc@test.com)"

# --- admin status changes ------------------------------------------------
q "UPDATE users SET status='VERIFIED' WHERE email='$U';"
check "admin suspends" "SUCCESS|STATUS_CHANGED" "$(run SET_USER_STATUS "$U" SUSPENDED "$ADM")"
check "status is SUSPENDED" "SUSPENDED" "$(q "SELECT status FROM users WHERE email='$U';")"
check "login on a suspended account" "ERROR|USER_SUSPENDED" "$(run AUTH_LOGIN "$U" secret123)"
check "invalid status rejected" "ERROR|INVALID_STATUS" "$(run SET_USER_STATUS "$U" NOPE "$ADM")"
check "non-admin cannot set status" "ERROR|FORBIDDEN" "$(run SET_USER_STATUS "$U" VERIFIED "$U")"
check "admin restores" "SUCCESS|STATUS_CHANGED" "$(run SET_USER_STATUS "$U" VERIFIED "$ADM")"
check "login works again" "SUCCESS|LOGIN_OK" "$(run AUTH_LOGIN "$U" secret123)"
check "status change audited" "2" "$(q "SELECT COUNT(*) FROM audit_trail WHERE user_id=966 AND action='SET_USER_STATUS';")"

q "DELETE FROM refresh_sessions WHERE email IN ('$U','$ADM'); DELETE FROM users WHERE email IN ('$U','$ADM');"

echo "======================================================================"
echo -e "Tests Completed: ${GREEN}${passed} passed${NC}, ${RED}${failed} failed${NC}"
echo "======================================================================"
[ "$failed" -eq 0 ]
