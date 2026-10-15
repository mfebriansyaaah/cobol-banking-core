#!/bin/bash
# Last-admin protection suite: the system refuses to remove its final active
# (VERIFIED) SUPER_ADMIN via CHANGE_ROLE, SET_USER_STATUS or DEACTIVATE_ACCOUNT.
# The shared test database holds SUPER_ADMIN leftovers from other suites, so the
# suite temporarily suspends them and restores them on exit.
# Usage: ./tests/test_last_admin.sh

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
echo "  LAST-ADMIN PROTECTION SUITE"
echo "======================================================================"

S1="la_super@test.com"; S2="la_super2@test.com"; U="la_user@test.com"

# Neutralize every other active SUPER_ADMIN so this suite controls the admin
# population; restore them on exit.
OTHERS_FILE=$(mktemp)
q "SELECT email FROM users WHERE role='SUPER_ADMIN' AND status='VERIFIED' AND email NOT IN ('$S1','$S2')" > "$OTHERS_FILE"
while read -r e; do [ -n "$e" ] && q "UPDATE users SET status='SUSPENDED' WHERE email='$e';"; done < "$OTHERS_FILE"

cleanup() {
    q "DELETE FROM users WHERE email IN ('$S1','$S2','$U');"
    while read -r e; do [ -n "$e" ] && q "UPDATE users SET status='VERIFIED' WHERE email='$e';"; done < "$OTHERS_FILE"
    rm -f "$OTHERS_FILE"
}
trap cleanup EXIT

q "DELETE FROM users WHERE email IN ('$S1','$S2','$U');
   INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES
   (760,'$S1','x','Last Super','1990-01-01','VERIFIED','SUPER_ADMIN'),
   (761,'$U','x','Last User','1990-01-01','VERIFIED','USER');"

# --- the only active SUPER_ADMIN cannot be removed ------------------------
check "cannot demote the last SUPER_ADMIN to USER" "ERROR|LAST_ADMIN" \
    "$(run CHANGE_ROLE "$S1" USER "$S1")"
check "cannot demote the last SUPER_ADMIN to MANAGER" "ERROR|LAST_ADMIN" \
    "$(run CHANGE_ROLE "$S1" MANAGER "$S1")"
check "re-setting SUPER_ADMIN is allowed (no-op)" "SUCCESS|ROLE_CHANGED" \
    "$(run CHANGE_ROLE "$S1" SUPER_ADMIN "$S1")"
check "cannot suspend the last SUPER_ADMIN" "ERROR|LAST_ADMIN" \
    "$(run SET_USER_STATUS "$S1" SUSPENDED "$S1")"
check "cannot close the last SUPER_ADMIN" "ERROR|LAST_ADMIN" \
    "$(run SET_USER_STATUS "$S1" CLOSED "$S1")"
check "cannot unverify the last SUPER_ADMIN" "ERROR|LAST_ADMIN" \
    "$(run SET_USER_STATUS "$S1" UNVERIFIED "$S1")"
check "re-setting VERIFIED is allowed (no-op)" "SUCCESS|STATUS_CHANGED" \
    "$(run SET_USER_STATUS "$S1" VERIFIED "$S1")"
check "cannot self-deactivate the last SUPER_ADMIN" "ERROR|LAST_ADMIN" \
    "$(run DEACTIVATE_ACCOUNT "$S1" "$S1")"
check "last admin is untouched" "SUPER_ADMIN" "$(q "SELECT role FROM users WHERE email='$S1';")"

# --- with a second active SUPER_ADMIN the change is allowed ---------------
q "INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES
   (762,'$S2','x','Second Super','1990-01-01','VERIFIED','SUPER_ADMIN');"
check "with a second super, demotion is allowed" "SUCCESS|ROLE_CHANGED" \
    "$(run CHANGE_ROLE "$S1" USER "$S2")"
q "UPDATE users SET role='SUPER_ADMIN' WHERE email='$S1';"
check "with a second super, suspending one is allowed" "SUCCESS|STATUS_CHANGED" \
    "$(run SET_USER_STATUS "$S1" SUSPENDED "$S2")"
check "the now-last super cannot suspend itself" "ERROR|LAST_ADMIN" \
    "$(run SET_USER_STATUS "$S2" SUSPENDED "$S2")"
check "the now-last super cannot deactivate itself" "ERROR|LAST_ADMIN" \
    "$(run DEACTIVATE_ACCOUNT "$S2" "$S2")"

echo "======================================================================"
echo -e "Tests Completed: ${GREEN}${passed} passed${NC}, ${RED}${failed} failed${NC}"
echo "======================================================================"
[ "$failed" -eq 0 ]
