#!/bin/bash
# Audit read suite: LIST_AUDIT is SUPER_ADMIN-only, filters by action/email,
# pages with limit/offset, and ARCHIVE_AUDIT refuses a zero-day retention window.
# Usage: ./tests/test_audit_read.sh

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
run5() {
    printf "%s|%s|%s|%s|%s|%s\n" "$1" "$2" "$3" "$4" "$5" "$6" > input.txt
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
check_not_contains() {
    local name="$1" needle="$2" actual="$3"
    if [[ "$actual" != *"$needle"* ]]; then
        echo -e "${GREEN}PASS${NC} $name"; passed=$((passed+1))
    else
        echo -e "${RED}FAIL${NC} $name (expected not to contain [$needle] got [$actual])"; failed=$((failed+1))
    fi
}

echo "======================================================================"
echo "  AUDIT READ SUITE"
echo "======================================================================"

A="ard_admin@test.com"; B="ard_user@test.com"
q "DELETE FROM users WHERE email IN ('$A','$B');
   DELETE FROM audit_trail WHERE action IN ('SET_USER_STATUS','UPDATE_PROFILE');
   INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES
   (810,'$A','x','Read Admin','1990-01-01','VERIFIED','SUPER_ADMIN'),
   (811,'$B','x','Read User','1990-01-01','VERIFIED','USER');"
run SET_USER_STATUS "$B" SUSPENDED "$A" >/dev/null
run SET_USER_STATUS "$B" VERIFIED "$A" >/dev/null
run UPDATE_PROFILE "$B" Bee "$B" >/dev/null

check "non-super cannot read the audit" "ERROR|FORBIDDEN" "$(run5 LIST_AUDIT "$B" "" "" "" "")"

all=$(run5 LIST_AUDIT "$A" "" "" "50" "0")
check_contains "super reads the audit" "SUCCESS|AUDIT|" "$all"

byaction=$(run5 LIST_AUDIT "$A" SET_USER_STATUS "" "50" "0")
check "action filter total" "2" "$(echo "$byaction" | cut -d'|' -f3)"
check_not_contains "action filter excludes others" "UPDATE_PROFILE" "$byaction"
check_contains "row carries the acting admin" "$A" "$byaction"

byemail=$(run5 LIST_AUDIT "$A" "" "$B" "50" "0")
check "email filter total" "3" "$(echo "$byemail" | cut -d'|' -f3)"

paged=$(run5 LIST_AUDIT "$A" SET_USER_STATUS "" "1" "0")
rows=$(echo "$paged" | cut -d'|' -f4-)
check "limit is honored (one row)" "1" "$(echo "$rows" | tr ';' '\n' | grep -c .)"
check "total is unaffected by paging" "2" "$(echo "$paged" | cut -d'|' -f3)"

check "zero-day retention is refused" "ERROR|INVALID_INPUT" "$(run ARCHIVE_AUDIT 0 "$A")"

q "DELETE FROM users WHERE email IN ('$A','$B'); DELETE FROM audit_trail WHERE action IN ('SET_USER_STATUS','UPDATE_PROFILE');"

echo "======================================================================"
echo -e "Tests Completed: ${GREEN}${passed} passed${NC}, ${RED}${failed} failed${NC}"
echo "======================================================================"
[ "$failed" -eq 0 ]
