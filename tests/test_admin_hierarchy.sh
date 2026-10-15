#!/bin/bash
# Admin role-hierarchy suite: a lower-ranked actor may not administer a
# higher-ranked account. A MANAGER can never suspend/close/verify a
# SUPER_ADMIN, nor revoke a SUPER_ADMIN's sessions; equal or higher ranks are
# allowed. Session revocation of another account follows the same rule.
# Usage: ./tests/test_admin_hierarchy.sh

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
echo "  ADMIN ROLE-HIERARCHY SUITE"
echo "======================================================================"

S1="hier_super@test.com"; S2="hier_super2@test.com"
MG="hier_mgr@test.com";  U="hier_user@test.com"
q "DELETE FROM users WHERE email IN ('$S1','$S2','$MG','$U');
   INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES
   (774,'$S1','x','Super One','1990-01-01','VERIFIED','SUPER_ADMIN'),
   (775,'$S2','x','Super Two','1990-01-01','VERIFIED','SUPER_ADMIN'),
   (776,'$MG','x','Manager','1990-01-01','VERIFIED','MANAGER'),
   (777,'$U','x','Plain User','1990-01-01','VERIFIED','USER');"

# --- status changes ------------------------------------------------------
check "MANAGER cannot suspend a SUPER_ADMIN" "ERROR|FORBIDDEN" \
    "$(run SET_USER_STATUS "$S1" SUSPENDED "$MG")"
check "MANAGER cannot close a SUPER_ADMIN" "ERROR|FORBIDDEN" \
    "$(run SET_USER_STATUS "$S1" CLOSED "$MG")"
check "MANAGER cannot verify a SUPER_ADMIN" "ERROR|FORBIDDEN" \
    "$(run SET_USER_STATUS "$S1" VERIFIED "$MG")"
check "MANAGER can act on a plain USER" "SUCCESS|STATUS_CHANGED" \
    "$(run SET_USER_STATUS "$U" SUSPENDED "$MG")"
check "SUPER_ADMIN can act on a MANAGER" "SUCCESS|STATUS_CHANGED" \
    "$(run SET_USER_STATUS "$MG" SUSPENDED "$S1")"
check "equal rank is allowed (SUPER_ADMIN on SUPER_ADMIN)" "SUCCESS|STATUS_CHANGED" \
    "$(run SET_USER_STATUS "$S2" SUSPENDED "$S1")"
q "UPDATE users SET status='VERIFIED' WHERE email IN ('$U','$MG','$S2');"
check "plain USER cannot set status" "ERROR|FORBIDDEN" \
    "$(run SET_USER_STATUS "$U" SUSPENDED "$U")"
check "unknown actor is refused" "ERROR|FORBIDDEN" \
    "$(run SET_USER_STATUS "$U" SUSPENDED ghost_hier@test.com)"

# --- session revocation of another account -------------------------------
check "MANAGER cannot revoke-all a SUPER_ADMIN's sessions" "ERROR|FORBIDDEN" \
    "$(run REVOKE_ALL_SESSIONS "$S1" "$MG")"
check "MANAGER cannot revoke a SUPER_ADMIN's session" "ERROR|FORBIDDEN" \
    "$(run REVOKE_USER_SESSION "$S1" "$MG" somejti)"
check "SUPER_ADMIN can revoke a MANAGER's sessions" "SUCCESS|SESSIONS_REVOKED" \
    "$(run REVOKE_ALL_SESSIONS "$MG" "$S1")"
check "self revoke-all is still allowed" "SUCCESS|SESSIONS_REVOKED" \
    "$(run REVOKE_ALL_SESSIONS "$U" "$U")"

q "DELETE FROM users WHERE email IN ('$S1','$S2','$MG','$U');"

echo "======================================================================"
echo -e "Tests Completed: ${GREEN}${passed} passed${NC}, ${RED}${failed} failed${NC}"
echo "======================================================================"
[ "$failed" -eq 0 ]
