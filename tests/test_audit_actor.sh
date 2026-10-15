#!/bin/bash
# Audit actor-attribution suite: admin actions on another account record both the
# subject (user_id) and the acting administrator (actor_id). Self-service actions
# leave actor_id NULL (the subject performed them). The archive preserves it.
# Usage: ./tests/test_audit_actor.sh

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
echo "  AUDIT ACTOR-ATTRIBUTION SUITE"
echo "======================================================================"

A="aa_admin@test.com"; B="aa_user@test.com"
q "DELETE FROM users WHERE email IN ('$A','$B');
   DELETE FROM audit_trail WHERE action IN ('SET_USER_STATUS','SESSIONS_REVOKED','REVOKE_USER_SESSION','ARCHIVE_AUDIT','UPDATE_PROFILE','AA_OLD');
   DELETE FROM audit_trail_archive WHERE action='AA_OLD';
   INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES
   (790,'$A','x','Audit Admin','1990-01-01','VERIFIED','SUPER_ADMIN'),
   (791,'$B','x','Audit User','1990-01-01','VERIFIED','USER');"

# --- SET_USER_STATUS: subject vs actor ------------------------------------
run SET_USER_STATUS "$B" SUSPENDED "$A" >/dev/null
check "status change records the subject" "791" "$(q "SELECT user_id FROM audit_trail WHERE action='SET_USER_STATUS' ORDER BY audit_id DESC LIMIT 1")"
check "status change records the actor" "790" "$(q "SELECT actor_id FROM audit_trail WHERE action='SET_USER_STATUS' ORDER BY audit_id DESC LIMIT 1")"

# --- SESSIONS_REVOKED: subject vs actor -----------------------------------
run REVOKE_ALL_SESSIONS "$B" "$A" >/dev/null
check "revoke-all records the subject" "791" "$(q "SELECT user_id FROM audit_trail WHERE action='SESSIONS_REVOKED' ORDER BY audit_id DESC LIMIT 1")"
check "revoke-all records the actor" "790" "$(q "SELECT actor_id FROM audit_trail WHERE action='SESSIONS_REVOKED' ORDER BY audit_id DESC LIMIT 1")"

# --- REVOKE_USER_SESSION: audited, subject vs actor -----------------------
q "INSERT INTO refresh_sessions (jti,family,email,expires_at) VALUES ('aajti','aafam','$B', DATE_ADD(NOW(), INTERVAL 7 DAY));"
run REVOKE_USER_SESSION "$B" "$A" aajti >/dev/null
check "revoke-one is audited" "1" "$(q "SELECT COUNT(*) FROM audit_trail WHERE action='REVOKE_USER_SESSION'")"
check "revoke-one records subject/actor" "791/790" "$(q "SELECT CONCAT(user_id,'/',actor_id) FROM audit_trail WHERE action='REVOKE_USER_SESSION' ORDER BY audit_id DESC LIMIT 1")"
check "revoke-one records the session id" "aajti" "$(q "SELECT entity_id FROM audit_trail WHERE action='REVOKE_USER_SESSION' ORDER BY audit_id DESC LIMIT 1")"

# --- ARCHIVE_AUDIT is itself audited, and the archive keeps actor_id ------
q "INSERT INTO audit_trail (user_id,actor_id,action,entity_type,entity_id,status,created_at) VALUES (790,790,'AA_OLD','USER','x','SUCCESS', DATE_SUB(NOW(), INTERVAL 10 DAY));"
run ARCHIVE_AUDIT 1 "$A" >/dev/null
check "archive action is audited" "790" "$(q "SELECT actor_id FROM audit_trail WHERE action='ARCHIVE_AUDIT' ORDER BY audit_id DESC LIMIT 1")"
check "archive preserves actor_id" "790" "$(q "SELECT actor_id FROM audit_trail_archive WHERE action='AA_OLD' ORDER BY audit_id DESC LIMIT 1")"

# --- self-service leaves actor_id NULL ------------------------------------
run UPDATE_PROFILE "$B" Renamed "$B" >/dev/null
check "self-service has no separate actor" "1" "$(q "SELECT actor_id IS NULL FROM audit_trail WHERE action='UPDATE_PROFILE' ORDER BY audit_id DESC LIMIT 1")"

q "DELETE FROM users WHERE email IN ('$A','$B');
   DELETE FROM audit_trail WHERE action IN ('SET_USER_STATUS','SESSIONS_REVOKED','REVOKE_USER_SESSION','ARCHIVE_AUDIT','UPDATE_PROFILE','AA_OLD');
   DELETE FROM audit_trail_archive WHERE action='AA_OLD';"

echo "======================================================================"
echo -e "Tests Completed: ${GREEN}${passed} passed${NC}, ${RED}${failed} failed${NC}"
echo "======================================================================"
[ "$failed" -eq 0 ]
