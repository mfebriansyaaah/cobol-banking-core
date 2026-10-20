#!/bin/bash
# Dormant account lifecycle suite (ADR 0080): MARK_DORMANT flags accounts
# whose last sign-in is older than DORMANT_AFTER_DAYS and queues a notice;
# SUSPEND_DORMANT suspends them only after DORMANT_GRACE_DAYS and only if
# they still have not signed in; REACTIVATE_DORMANT clears a dormant
# suspension. SUPER_ADMIN accounts are never auto-suspended, and the policy
# ships disabled. Per-call environment is required, so this suite uses the
# file-mode invocation.
# Usage: ./tests/test_dormancy.sh

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

runp() {
    local envs=()
    while [ "${1:-}" != "" ] && [[ "$1" == *=* ]]; do envs+=("$1"); shift; done
    printf "%s|%s|%s|%s|%s\n" "$1" "$2" "$3" "$4" "$5" > input.txt
    env "${envs[@]}" "$BIN" >/dev/null 2>&1
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

OLD="dorm_old@test.com"; NEW="dorm_new@test.com"; ADM="dorm_admin@test.com"; ACT="dorm_actor@test.com"

setup() {
    q "DELETE FROM users WHERE email IN ('$OLD','$NEW','$ADM','$ACT');
       DELETE FROM notification_outbox WHERE recipient IN ('$OLD','$NEW','$ADM','$ACT');
       INSERT INTO users (id,email,password_hash,full_name,dob,status,role,last_login_at) VALUES
       (2031,'$OLD','x','Dorm Old','1990-01-01','VERIFIED','USER', DATE_SUB(NOW(), INTERVAL 100 DAY)),
       (2032,'$NEW','x','Dorm New','1990-01-01','VERIFIED','USER', NOW()),
       (2033,'$ADM','x','Dorm Admin','1990-01-01','VERIFIED','SUPER_ADMIN', DATE_SUB(NOW(), INTERVAL 100 DAY)),
       (2034,'$ACT','x','Dorm Actor','1990-01-01','VERIFIED','SUPER_ADMIN', NOW());
       INSERT INTO refresh_sessions (jti,family,email,expires_at) VALUES
       ('dormjti','dormfam','$OLD', DATE_ADD(NOW(), INTERVAL 7 DAY));"
}

teardown() {
    q "DELETE FROM users WHERE email IN ('$OLD','$NEW','$ADM','$ACT');
       DELETE FROM notification_outbox WHERE recipient IN ('$OLD','$NEW','$ADM','$ACT');
       DELETE FROM audit_trail WHERE action LIKE 'DORMANT%';"
}
trap teardown EXIT

echo "======================================================================"
echo "  DORMANT LIFECYCLE SUITE"
echo "======================================================================"

setup

# --- the policy ships disabled -----------------------------------------------------
check "mark refuses while the policy is disabled" "ERROR|POLICY_DISABLED" \
    "$(run MARK_DORMANT "$ACT" "" "" "")"
check "suspend refuses while the policy is disabled" "ERROR|POLICY_DISABLED" \
    "$(run SUSPEND_DORMANT "$ACT" "" "" "")"
check "a non-admin cannot mark accounts" "ERROR|FORBIDDEN" \
    "$(runp DORMANT_AFTER_DAYS=90 MARK_DORMANT "$NEW" "" "" "")"

# --- phase one: flag and notify ----------------------------------------------------
check "mark notifies the dormant account" "SUCCESS|DORMANT_NOTIFIED|00001" \
    "$(runp DORMANT_AFTER_DAYS=90 MARK_DORMANT "$ACT" "" "" "")"
check "a second mark is idempotent" "SUCCESS|DORMANT_NOTIFIED|00000" \
    "$(runp DORMANT_AFTER_DAYS=90 MARK_DORMANT "$ACT" "" "" "")"
check "the recent account is not flagged" "0" \
    "$(q "SELECT COUNT(*) FROM users WHERE email='$NEW' AND dormant_notified_at IS NOT NULL;")"
check "a SUPER_ADMIN is never auto-flagged" "0" \
    "$(q "SELECT COUNT(*) FROM users WHERE email='$ADM' AND dormant_notified_at IS NOT NULL;")"
check "the notice is queued without a code" "1" \
    "$(q "SELECT COUNT(*) FROM notification_outbox WHERE recipient='$OLD' AND purpose='DORMANT_NOTICE' AND code='';")"
check "the notice is audited" "1" \
    "$(q "SELECT COUNT(*) FROM audit_trail WHERE action='DORMANT_NOTICE' AND status='SUCCESS';")"

# --- phase two: suspend after the grace window -------------------------------------
check "suspend waits for the grace window" "SUCCESS|DORMANT_SUSPENDED|00000" \
    "$(runp DORMANT_AFTER_DAYS=90 DORMANT_GRACE_DAYS=14 SUSPEND_DORMANT "$ACT" "" "" "")"
q "UPDATE users SET dormant_notified_at=DATE_SUB(NOW(), INTERVAL 20 DAY) WHERE email='$OLD';"
check "suspend acts after the grace window" "SUCCESS|DORMANT_SUSPENDED|00001" \
    "$(runp DORMANT_AFTER_DAYS=90 DORMANT_GRACE_DAYS=14 SUSPEND_DORMANT "$ACT" "" "" "")"
check "the account is suspended" "SUSPENDED|null" \
    "$(q "SELECT CONCAT(status, '|', IFNULL(dormant_notified_at,'null')) FROM users WHERE email='$OLD';")"
check "the suspension revoked the sessions" "1" \
    "$(q "SELECT revoked FROM refresh_sessions WHERE jti='dormjti';")"
check "the suspension is audited" "1" \
    "$(q "SELECT COUNT(*) FROM audit_trail WHERE action='DORMANT_SUSPENDED' AND status='SUCCESS';")"

# --- reactivation ------------------------------------------------------------------
check "an admin reactivates the account" "SUCCESS|DORMANT_REACTIVATED" \
    "$(run REACTIVATE_DORMANT "$OLD" "$ACT" "" "")"
check "the account is verified again" "VERIFIED" \
    "$(q "SELECT status FROM users WHERE email='$OLD';")"
check "reactivating a verified account is refused" "ERROR|INVALID_STATUS" \
    "$(run REACTIVATE_DORMANT "$NEW" "$ACT" "" "")"
check "a non-admin cannot reactivate" "ERROR|FORBIDDEN" \
    "$(run REACTIVATE_DORMANT "$OLD" "$NEW" "" "")"
check "reactivation is audited" "1" \
    "$(q "SELECT COUNT(*) FROM audit_trail WHERE action='DORMANT_REACTIVATED' AND status='SUCCESS';")"

echo "======================================================================"
echo -e "Tests Completed: ${GREEN}${passed} passed${NC}, ${RED}${failed} failed${NC}"
echo "======================================================================"
[ "$failed" -eq 0 ]
