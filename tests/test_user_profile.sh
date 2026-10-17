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
ADMIN="prof_admin@test.com"
NOACCT="prof_noacct@test.com"

q "DELETE FROM verification_logs WHERE email IN ('$U','$UNEW','$OTHER','$NOACCT');
   DELETE FROM accounts WHERE account_id IN (950,951,952);
   DELETE FROM users WHERE email IN ('$U','$UNEW','$OTHER','$NOACCT');
   INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES
   (950,'$U',CONCAT('SHA256_',SHA2('secret123',256)),'Prof User','1990-01-01','VERIFIED','USER'),
   (951,'$OTHER',CONCAT('SHA256_',SHA2('secret123',256)),'Other User','1990-01-01','VERIFIED','USER')
   ON DUPLICATE KEY UPDATE role='USER', status='VERIFIED';
   INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES
   (953,'$ADMIN',CONCAT('SHA256_',SHA2('secret123',256)),'Prof Admin','1990-01-03','VERIFIED','SUPER_ADMIN')
   ON DUPLICATE KEY UPDATE role='SUPER_ADMIN', status='VERIFIED';
   INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES
   (954,'$NOACCT','x','No Acct','1991-01-01','VERIFIED','USER');
   INSERT INTO accounts (account_id,user_id,currency_id,balance,account_type) VALUES
   (950,950,1,250.00,'SAVINGS'),(952,950,3,0.00,'SAVINGS'),(951,951,1,0.00,'SAVINGS');"

# --- GET_DASHBOARD ---
check_contains "dashboard self profile" "SUCCESS|DASHBOARD|$U|Prof User|VERIFIED|USER|1990-01-01|" "$(run GET_DASHBOARD "$U" "$U" "")"
check_contains "dashboard self accounts" "|USD:250.00:250.00:ACTIVE;IDR:0:0:ACTIVE" "$(run GET_DASHBOARD "$U" "$U" "")"
check_contains "dashboard by admin" "SUCCESS|DASHBOARD|$U|Prof User|VERIFIED|USER|1990-01-01|" "$(run GET_DASHBOARD "$U" "$ADMIN" "")"
check_contains "dashboard without accounts still works" "SUCCESS|DASHBOARD|$NOACCT|No Acct|VERIFIED|USER|1991-01-01|" "$(run GET_DASHBOARD "$NOACCT" "$NOACCT" "")"
check "dashboard other forbidden for non-admin" "ERROR|FORBIDDEN" "$(run GET_DASHBOARD "$U" "$OTHER" "")"
check "dashboard unknown user" "ERROR|ACCOUNT_NOT_FOUND" "$(run GET_DASHBOARD ghost@test.com "$ADMIN" "")"

# --- LIST_USERS + paging ---
check_contains "list users header" "SUCCESS|LIST_DONE|" "$(run LIST_USERS "" "" "$ADMIN")"
check_contains "list users includes a known user" "950:$U" "$(run LIST_USERS "" "" "$ADMIN")"
check_contains "get_user is enriched" "SUCCESS|USER|950|$U|Prof User|VERIFIED|USER|" "$(run GET_USER "$U" "$U" "")"
check_contains "list users role filter" "950:$U:Prof User:USER:VERIFIED" "$(run LIST_USERS 5 0 "$ADMIN" USER)"
check_contains "paging limit=1 returns the first" "|1:sender@test.com:Sender User:USER:VERIFIED" "$(run LIST_USERS 1 0 "$ADMIN")"
check_contains "paging offset=1 skips the first" "2:receiver@test.com" "$(run LIST_USERS 1 1 "$ADMIN")"
check_contains "paging limit=2 returns two rows" "1:sender@test.com:Sender User:USER:VERIFIED;2:receiver@test.com:Receiver User:USER:VERIFIED" "$(run LIST_USERS 2 0 "$ADMIN")"
page=$(run LIST_USERS 5 100000 "$ADMIN")
if [[ "$page" == "SUCCESS|LIST_DONE|"*"|" && "$page" != *"sender@test.com"* ]]; then
    check "paging past the end is empty" "ok" "ok"
else
    check "paging past the end is empty" "empty page" "$page"
fi
check "list users forbidden for non-admin" "ERROR|FORBIDDEN" "$(run LIST_USERS "" "" "$OTHER")"

# --- UPDATE_PROFILE ---
check "update name" "SUCCESS|PROFILE_UPDATED" "$(run UPDATE_PROFILE "$U" 'New Prof Name' "$U" "")"
check "name persisted" "New Prof Name" "$(q "SELECT full_name FROM users WHERE email='$U';")"
check "update name and dob" "SUCCESS|PROFILE_UPDATED" "$(run UPDATE_PROFILE "$U" 'Jane Doe' "$U" 1995-05-05)"
check "dob persisted" "1995-05-05" "$(q "SELECT dob FROM users WHERE email='$U';")"
check "update another user forbidden" "ERROR|FORBIDDEN" "$(run UPDATE_PROFILE "$U" 'X' "$OTHER" "")"
check "blank name rejected" "ERROR|INVALID_INPUT" "$(run UPDATE_PROFILE "$U" ' ' "$U" "")"
check "update unknown user" "ERROR|ACCOUNT_NOT_FOUND" "$(run UPDATE_PROFILE ghost@test.com 'X' ghost@test.com "")"
check "update audited" "2" "$(q "SELECT COUNT(*) FROM audit_trail WHERE user_id=950 AND action='UPDATE_PROFILE' AND entity_id='950';")"

# --- REQ_EMAIL_CHANGE ---
check "request unknown current" "ERROR|ACCOUNT_NOT_FOUND" "$(run REQ_EMAIL_CHANGE ghost@test.com "$UNEW" ghost@test.com secret123)"
check "request taken new email is neutral" "SUCCESS|CODE_SENT" "$(run REQ_EMAIL_CHANGE "$U" "$OTHER" "$U" secret123)"
check "taken email stores no code" "0" "$(q "SELECT COUNT(*) FROM verification_logs WHERE email='$OTHER' AND purpose='EMAIL_CHANGE' AND is_used=0;")"
check "request with a wrong password" "ERROR|INVALID_CREDENTIALS" "$(run REQ_EMAIL_CHANGE "$U" "$UNEW" "$U" wrongpass)"
check "request another user's email forbidden" "ERROR|FORBIDDEN" "$(run REQ_EMAIL_CHANGE "$U" "prof_take@test.com" "$OTHER" secret123)"
out=$(run REQ_EMAIL_CHANGE "$U" "$UNEW" "$U" secret123)
code=$(echo "$out" | cut -d'|' -f3)
case "$out" in
    SUCCESS\|CODE_SENT\|[0-9][0-9][0-9][0-9][0-9][0-9]) check "request returns code" "ok" "ok" ;;
    *) check "request returns code" "SUCCESS|CODE_SENT|<6 digits>" "$out" ;;
esac

# --- CONFIRM_EMAIL_CHANGE ---
check "confirm wrong code" "ERROR|INVALID_CODE" "$(run CONFIRM_EMAIL_CHANGE "$U" "$UNEW" 000000 "$U")"
check "confirm another user's email forbidden" "ERROR|FORBIDDEN" "$(run CONFIRM_EMAIL_CHANGE "$U" "$UNEW" "$code" "$OTHER")"
check "confirm good code" "SUCCESS|EMAIL_CHANGED" "$(run CONFIRM_EMAIL_CHANGE "$U" "$UNEW" "$code" "$U")"
check "new email persisted" "1" "$(q "SELECT COUNT(*) FROM users WHERE email='$UNEW';")"
check "old email gone" "0" "$(q "SELECT COUNT(*) FROM users WHERE email='$U';")"
check "confirm reused code" "ERROR|INVALID_CODE" "$(run CONFIRM_EMAIL_CHANGE "$UNEW" "$UNEW" "$code" "$UNEW")"
check "token version bumped on email change" "2" "$(q "SELECT token_version FROM users WHERE email='$UNEW';")"
check "audit email_change row" "1" "$(q "SELECT COUNT(*) FROM audit_trail WHERE user_id=950 AND action='EMAIL_CHANGE';")"

# --- validation & confirm race ---
RU="prof_race@test.com"; RN="prof_race_new@test.com"
q "DELETE FROM verification_logs WHERE email IN ('$RU','$RN'); DELETE FROM users WHERE email IN ('$RU','$RN');
   INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES
   (955,'$RU',CONCAT('SHA256_',SHA2('secret123',256)),'Race User','1990-01-01','VERIFIED','USER');"
check "malformed email rejected" "ERROR|INVALID_INPUT" "$(run REQ_EMAIL_CHANGE notanemail "$RN" notanemail secret123)"
check "malformed new email rejected" "ERROR|INVALID_INPUT" "$(run REQ_EMAIL_CHANGE "$RU" notanemail "$RU" secret123)"
check "bad date of birth rejected" "ERROR|INVALID_INPUT" "$(run UPDATE_PROFILE "$RU" 'Race User' "$RU" 1990-13-01)"
rc=$(run REQ_EMAIL_CHANGE "$RU" "$RN" "$RU" secret123 | cut -d'|' -f3)
q "INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES (956,'$RN','x','Taken','1990-01-01','VERIFIED','USER');"
check "confirm race reports EMAIL_EXISTS" "ERROR|EMAIL_EXISTS" "$(run CONFIRM_EMAIL_CHANGE "$RU" "$RN" "$rc" "$RU")"
q "DELETE FROM verification_logs WHERE email IN ('$RU','$RN'); DELETE FROM users WHERE email IN ('$RU','$RN');"

echo "======================================================================"
echo -e "Tests Completed: ${GREEN}${passed} passed${NC}, ${RED}${failed} failed${NC}"
echo "======================================================================"
[ "$failed" -eq 0 ]
