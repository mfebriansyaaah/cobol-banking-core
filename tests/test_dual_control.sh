#!/bin/bash
# Dual-control suite: designated privileged operations refuse direct
# execution (DUAL_CONTROL_REQUIRED) and travel the maker-checker request
# path instead. No self-approval; re-validation at approve time; last-admin
# protection holds through approval; undesignating restores direct use.
# Usage: ./tests/test_dual_control.sh

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
    local name="$1" expected="$2" actual="$3"
    if [[ "$actual" == *"$expected"* ]]; then
        echo -e "${GREEN}PASS${NC} $name"; passed=$((passed+1))
    else
        echo -e "${RED}FAIL${NC} $name (expected to contain [$expected] got [$actual])"; failed=$((failed+1))
    fi
}

MK="dc_mk@test.com"; CK="dc_ck@test.com"; U="dc_u@test.com"
setup() {
    q "DELETE FROM maker_requests WHERE request_id > 0;
       DELETE FROM dual_control_operations WHERE operation = 'CHANGE_ROLE';
       DELETE FROM users WHERE email IN ('$MK','$CK','$U');
       INSERT INTO users (email,password_hash,full_name,dob,status,role) VALUES
       ('$MK','x','Dual Maker','1990-01-01','VERIFIED','SUPER_ADMIN'),
       ('$CK','x','Dual Checker','1990-01-01','VERIFIED','SUPER_ADMIN'),
       ('$U','x','Dual User','1990-01-01','VERIFIED','USER');"
}

teardown() {
    q "DELETE FROM maker_requests WHERE request_id > 0;
       DELETE FROM dual_control_operations WHERE operation = 'CHANGE_ROLE';
       DELETE FROM audit_trail WHERE action IN ('REQUEST_PLACED','REQUEST_REJECTED') AND user_id IN (SELECT id FROM users WHERE email LIKE 'dc_%@test.com');
       DELETE FROM audit_trail WHERE action = 'CHANGE_ROLE' AND actor_id IN (SELECT id FROM users WHERE email LIKE 'dc_%@test.com');
       DELETE FROM users WHERE email IN ('$MK','$CK','$U');"
}
trap teardown EXIT

echo "======================================================================"
echo "  DUAL CONTROL SUITE"
echo "======================================================================"

setup

# --- undesignated operations cannot be requested --------------------------------
check "request for an ungated operation is refused" "ERROR|INVALID_INPUT" "$(run REQUEST_OPERATION CHANGE_ROLE $U MANAGER $MK)"

# --- designation switches the operation to the request path ----------------------
q "INSERT INTO dual_control_operations (operation) VALUES ('CHANGE_ROLE');"
check "request by a non-admin is refused" "ERROR|FORBIDDEN" "$(run REQUEST_OPERATION CHANGE_ROLE $U MANAGER $U)"
REQ="$(run REQUEST_OPERATION CHANGE_ROLE $U MANAGER $MK)"
check_contains "maker places a request" "SUCCESS|REQUEST_PLACED|" "$REQ"
RID="${REQ##*|}"
RID="${REQ##*|}"
check "request row is PENDING" "CHANGE_ROLE|$U|MANAGER|$MK|PENDING" "$(q "SELECT CONCAT(operation, '|', target_email, '|', detail, '|', maker_email, '|', state) FROM maker_requests WHERE request_id='$RID';")"
check "direct execution is refused while designated" "ERROR|DUAL_CONTROL_REQUIRED" "$(run CHANGE_ROLE $U MANAGER $MK)"
check "refused direct change moved nothing" "USER" "$(q "SELECT role FROM users WHERE email='$U';")"
check "self-approval is forbidden" "ERROR|FORBIDDEN" "$(run APPROVE_REQUEST "$RID" $MK)"
check "non-admin cannot approve" "ERROR|FORBIDDEN" "$(run APPROVE_REQUEST "$RID" $U)"
check "checker approves" "SUCCESS|REQUEST_APPROVED" "$(run APPROVE_REQUEST "$RID" $CK)"
check "approval executed the change" "MANAGER" "$(q "SELECT role FROM users WHERE email='$U';")"
check "request is APPROVED by the checker" "APPROVED|$CK" "$(q "SELECT CONCAT(state, '|', checker_email) FROM maker_requests WHERE request_id='$RID';")"
check "effect is audited to the checker" "1" "$(q "SELECT COUNT(*) FROM audit_trail WHERE action='CHANGE_ROLE' AND entity_id=(SELECT id FROM users WHERE email='$U') AND actor_id=(SELECT id FROM users WHERE email='$CK');")"
check "re-approve is refused" "ERROR|UNKNOWN_TRANSACTION" "$(run APPROVE_REQUEST "$RID" $CK)"

# --- rejection --------------------------------------------------------------------
REQ2="$(run REQUEST_OPERATION CHANGE_ROLE $U USER $MK)"
RID2="${REQ2##*|}"
check "second request placed" "SUCCESS" "$(echo "$REQ2" | cut -d'|' -f1)"
check "non-admin cannot reject" "ERROR|FORBIDDEN" "$(run REJECT_REQUEST "$RID2" $U)"
check "maker cannot reject own request" "ERROR|FORBIDDEN" "$(run REJECT_REQUEST "$RID2" $MK)"
check "checker rejects" "SUCCESS|REQUEST_REJECTED" "$(run REJECT_REQUEST "$RID2" $CK)"
check "rejected request cannot be approved" "ERROR|UNKNOWN_TRANSACTION" "$(run APPROVE_REQUEST "$RID2" $CK)"
check "rejected change did not happen" "MANAGER" "$(q "SELECT role FROM users WHERE email='$U';")"

# --- validation ---------------------------------------------------------------------
check "bad request id" "ERROR|INVALID_INPUT" "$(run APPROVE_REQUEST abc $CK)"
check "unknown request" "ERROR|UNKNOWN_TRANSACTION" "$(run APPROVE_REQUEST 999999999 $CK)"
check "bad list filter" "ERROR|INVALID_INPUT" "$(run LIST_REQUESTS $CK BOGUS)"
check "non-admin cannot list" "ERROR|FORBIDDEN" "$(run LIST_REQUESTS $U)"
check_contains "list shows the flows" "REQUESTS|" "$(run LIST_REQUESTS $CK)"

# --- last-admin protection holds through approval ------------------------------------
# Isolate: suspend every other active SUPER_ADMIN (restored below) so the
# target is genuinely the last one; the approver stays SUPER_ADMIN by role.
OTHERS="$(q "SELECT GROUP_CONCAT(email SEPARATOR \"','\") FROM users WHERE role='SUPER_ADMIN' AND status='VERIFIED' AND email NOT IN ('$MK','$CK');")"
[ -n "$OTHERS" ] && q "UPDATE users SET status='SUSPENDED' WHERE email IN ('$OTHERS');"
q "UPDATE users SET status='SUSPENDED' WHERE email='$CK';"
REQL="$(run REQUEST_OPERATION CHANGE_ROLE $MK USER $MK)"
RIDL="${REQL##*|}"
check "last-admin demotion requested" "SUCCESS" "$(echo "$REQL" | cut -d'|' -f1)"
check "approval is refused for the last admin" "ERROR|LAST_ADMIN" "$(run APPROVE_REQUEST "$RIDL" $CK)"
check "last admin is untouched" "SUPER_ADMIN" "$(q "SELECT role FROM users WHERE email='$MK';")"
check "refused request stays PENDING" "PENDING" "$(q "SELECT state FROM maker_requests WHERE request_id='$RIDL';")"
q "UPDATE users SET status='VERIFIED' WHERE email='$CK';"
[ -n "$OTHERS" ] && q "UPDATE users SET status='VERIFIED' WHERE email IN ('$OTHERS');"

# --- undesignating restores direct use ----------------------------------------------
teardown
setup
check "direct change works when ungated" "SUCCESS|ROLE_CHANGED" "$(run CHANGE_ROLE $U MANAGER $MK)"

echo "======================================================================"
echo "Tests Completed: ${GREEN}${passed} passed${NC}, ${RED}${failed} failed${NC}"
echo "======================================================================"
[ "$failed" -eq 0 ]
