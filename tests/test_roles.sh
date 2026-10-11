#!/bin/bash
# CHECK_ROLE + CHANGE_ROLE suite (Phase 3d).
# CHECK_ROLE reports whether a user holds a role. CHANGE_ROLE is restricted to a
# SUPER_ADMIN actor and validates role name and target existence.
# Usage: ./tests/test_roles.sh

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
echo "  ROLE SUITE (CHECK_ROLE / CHANGE_ROLE)"
echo "======================================================================"

ADMIN="roled_admin@test.com"
USER="roled_user@test.com"
q "DELETE FROM users WHERE email IN ('$ADMIN','$USER');
   INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES
   (920,'$ADMIN',CONCAT('SHA256_',SHA2('secret123',256)),'Admin','1990-01-01','VERIFIED','SUPER_ADMIN'),
   (921,'$USER',CONCAT('SHA256_',SHA2('secret123',256)),'User','1990-01-01','VERIFIED','USER');"

# --- CHECK_ROLE ---
check "check matching role" "SUCCESS|ROLE_OK" "$(run CHECK_ROLE "$USER" USER)"
check "check non-matching role" "ERROR|ROLE_DENIED" "$(run CHECK_ROLE "$USER" SUPER_ADMIN)"
check "check unknown user" "ERROR|ACCOUNT_NOT_FOUND" "$(run CHECK_ROLE ghost@test.com USER)"

# --- CHANGE_ROLE ---
check "non-admin actor forbidden" "ERROR|FORBIDDEN" \
    "$(run CHANGE_ROLE "$USER" MANAGER "$USER")"
check "unknown actor forbidden" "ERROR|FORBIDDEN" \
    "$(run CHANGE_ROLE "$USER" MANAGER ghost@test.com)"
check "invalid role rejected" "ERROR|INVALID_ROLE" \
    "$(run CHANGE_ROLE "$USER" GOD "$ADMIN")"
check "unknown target rejected" "ERROR|ACCOUNT_NOT_FOUND" \
    "$(run CHANGE_ROLE ghost@test.com USER "$ADMIN")"
check "admin changes role" "SUCCESS|ROLE_CHANGED" \
    "$(run CHANGE_ROLE "$USER" MANAGER "$ADMIN")"
check "role persisted" "MANAGER" "$(q "SELECT role FROM users WHERE email='$USER';")"
check "role now reported by CHECK_ROLE" "SUCCESS|ROLE_OK" "$(run CHECK_ROLE "$USER" MANAGER)"
check "audit change_role row" "1" "$(q "SELECT COUNT(*) FROM audit_trail WHERE user_id=921 AND action='CHANGE_ROLE';")"

echo "======================================================================"
echo -e "Tests Completed: ${GREEN}${passed} passed${NC}, ${RED}${failed} failed${NC}"
echo "======================================================================"
[ "$failed" -eq 0 ]
