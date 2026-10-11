#!/bin/bash
# User profile suite (Phase 4).
# GET_DASHBOARD returns balance/email/full_name; LIST_USERS lists users;
# the two-step email change (REQ_EMAIL_CHANGE -> CONFIRM_EMAIL_CHANGE) enforces a
# code, uniqueness, and single use.
# Usage: ./tests/test_user_profile.sh

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
echo "  USER PROFILE SUITE"
echo "======================================================================"

U="prof@test.com"
UNEW="prof_new@test.com"
OTHER="prof_other@test.com"

q "DELETE FROM verification_logs WHERE email IN ('$U','$UNEW','$OTHER');
   DELETE FROM accounts WHERE account_id IN (950,951);
   DELETE FROM users WHERE email IN ('$U','$UNEW','$OTHER');
   INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES
   (950,'$U',CONCAT('SHA256_',SHA2('secret123',256)),'Prof User','1990-01-01','VERIFIED','USER'),
   (951,'$OTHER',CONCAT('SHA256_',SHA2('secret123',256)),'Other User','1990-01-01','VERIFIED','USER');
   INSERT INTO accounts (account_id,user_id,currency_id,balance,account_type) VALUES
   (950,950,1,250.00,'SAVINGS'),(951,951,1,0.00,'SAVINGS');"

# --- GET_DASHBOARD ---
check "dashboard exact" "SUCCESS|DASHBOARD|250.00|$U|Prof User" "$(run GET_DASHBOARD "$U" "" "")"
check "dashboard unknown user" "ERROR|ACCOUNT_NOT_FOUND" "$(run GET_DASHBOARD ghost@test.com "" "")"

# --- LIST_USERS ---
check_contains "list users header" "SUCCESS|LIST_DONE|" "$(run LIST_USERS "" "" "")"
check_contains "list users includes a known user" "950:$U" "$(run LIST_USERS "" "" "")"

# --- REQ_EMAIL_CHANGE ---
check "request unknown current" "ERROR|ACCOUNT_NOT_FOUND" "$(run REQ_EMAIL_CHANGE ghost@test.com "$UNEW" "")"
check "request taken new email" "ERROR|EMAIL_EXISTS" "$(run REQ_EMAIL_CHANGE "$U" "$OTHER" "")"
out=$(run REQ_EMAIL_CHANGE "$U" "$UNEW" "")
code=$(echo "$out" | cut -d'|' -f3)
case "$out" in
    SUCCESS\|CODE_SENT\|[0-9][0-9][0-9][0-9][0-9][0-9]) check "request returns code" "ok" "ok" ;;
    *) check "request returns code" "SUCCESS|CODE_SENT|<6 digits>" "$out" ;;
esac

# --- CONFIRM_EMAIL_CHANGE ---
check "confirm wrong code" "ERROR|INVALID_CODE" "$(run CONFIRM_EMAIL_CHANGE "$U" "$UNEW" 000000)"
check "confirm good code" "SUCCESS|EMAIL_CHANGED" "$(run CONFIRM_EMAIL_CHANGE "$U" "$UNEW" "$code")"
check "new email persisted" "1" "$(q "SELECT COUNT(*) FROM users WHERE email='$UNEW';")"
check "old email gone" "0" "$(q "SELECT COUNT(*) FROM users WHERE email='$U';")"
check "confirm reused code" "ERROR|INVALID_CODE" "$(run CONFIRM_EMAIL_CHANGE "$UNEW" "$UNEW" "$code")"

echo "======================================================================"
echo -e "Tests Completed: ${GREEN}${passed} passed${NC}, ${RED}${failed} failed${NC}"
echo "======================================================================"
[ "$failed" -eq 0 ]
