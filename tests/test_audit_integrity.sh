#!/bin/bash
# Audit integrity suite: refused authorization attempts are recorded
# (AUTHZ_DENIED), unknown actors are not attributed, the audit read indexes
# exist, and deleting a user preserves their live audit rows in the immutable
# archive (the pre-delete trigger) instead of destroying them via the FK cascade.
# Usage: ./tests/test_audit_integrity.sh

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
echo "  AUDIT INTEGRITY SUITE"
echo "======================================================================"

SA="ai_super@test.com"; MG="ai_mgr@test.com"; U="ai_user@test.com"; V="ai_victim@test.com"
q "DELETE FROM users WHERE email IN ('$SA','$MG','$U','$V');
   DELETE FROM audit_trail WHERE action='AUTHZ_DENIED';
   INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES
   (830,'$SA','x','S','1990-01-01','VERIFIED','SUPER_ADMIN'),
   (831,'$MG','x','M','1990-01-01','VERIFIED','MANAGER'),
   (832,'$U','x','U','1990-01-01','VERIFIED','USER'),
   (833,'$V','x','V','1990-01-01','VERIFIED','USER');"

# --- refused authorization attempts are recorded --------------------------
run SET_USER_STATUS "$U" SUSPENDED "$U" >/dev/null
check "role denial is audited" "1" "$(q "SELECT COUNT(*) FROM audit_trail a JOIN users u ON u.id=a.user_id WHERE a.action='AUTHZ_DENIED' AND u.email='$U' AND a.entity_id='SET_USER_STATUS'")"

run GET_USER "$V" "$U" >/dev/null
check "read denial is audited" "1" "$(q "SELECT COUNT(*) FROM audit_trail a JOIN users u ON u.id=a.user_id WHERE a.action='AUTHZ_DENIED' AND u.email='$U' AND a.entity_id='GET_USER' AND a.detail='$V'")"

run SET_USER_STATUS "$SA" SUSPENDED "$MG" >/dev/null
check "rank denial is audited" "1" "$(q "SELECT COUNT(*) FROM audit_trail a JOIN users u ON u.id=a.user_id WHERE a.action='AUTHZ_DENIED' AND u.email='$MG'")"

before=$(q "SELECT COUNT(*) FROM audit_trail WHERE action='AUTHZ_DENIED'")
run SET_USER_STATUS "$U" SUSPENDED ghost_ai@test.com >/dev/null
check "unknown actor is not attributed" "$before" "$(q "SELECT COUNT(*) FROM audit_trail WHERE action='AUTHZ_DENIED'")"

# --- wallet-side denials (RECONCILE / REVERSE / balance read) -------------
run RECONCILE "$U" >/dev/null
check "RECONCILE denial is audited" "1" "$(q "SELECT COUNT(*) FROM audit_trail a JOIN users u ON u.id=a.user_id WHERE a.action='AUTHZ_DENIED' AND u.email='$U' AND a.entity_id='RECONCILE'")"
run REVERSE_TRANSFER NOSUCH "$U" >/dev/null
check "REVERSE denial is audited" "1" "$(q "SELECT COUNT(*) FROM audit_trail a JOIN users u ON u.id=a.user_id WHERE a.action='AUTHZ_DENIED' AND u.email='$U' AND a.entity_id='REVERSE_TRANSFER'")"
run CHECK_BALANCE "$V" "$U" >/dev/null
check "balance-read denial is audited" "1" "$(q "SELECT COUNT(*) FROM audit_trail a JOIN users u ON u.id=a.user_id WHERE a.action='AUTHZ_DENIED' AND u.email='$U' AND a.entity_id='CHECK_BALANCE' AND a.detail='$V'")"

# --- read-path indexes ----------------------------------------------------
check "action index exists" "1" "$(q "SELECT COUNT(*) FROM information_schema.statistics WHERE table_schema='$DB_NAME' AND table_name='audit_trail' AND index_name='idx_audit_action'")"
check "actor index exists" "1" "$(q "SELECT COUNT(*) FROM information_schema.statistics WHERE table_schema='$DB_NAME' AND table_name='audit_trail' AND index_name='idx_audit_actor'")"

# --- deleting a user preserves audit evidence in the archive ---------------
D="ai_del@test.com"
q "DELETE FROM users WHERE email='$D'; DELETE FROM audit_trail_archive WHERE action='AI_DELTEST';
   INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES (834,'$D','x','D','1990-01-01','VERIFIED','USER');
   INSERT INTO audit_trail (user_id, actor_id, action, entity_type, entity_id, status) VALUES (834,834,'AI_DELTEST','USER','x','SUCCESS');"
q "DELETE FROM users WHERE email='$D';"
check "live row removed by the delete" "0" "$(q "SELECT COUNT(*) FROM audit_trail WHERE action='AI_DELTEST'")"
check "evidence preserved in the archive" "1" "$(q "SELECT COUNT(*) FROM audit_trail_archive WHERE action='AI_DELTEST'")"

q "DELETE FROM users WHERE email IN ('$SA','$MG','$U','$V'); DELETE FROM audit_trail WHERE action='AUTHZ_DENIED'; DELETE FROM audit_trail_archive WHERE action IN ('AUTHZ_DENIED','AI_DELTEST');"

echo "======================================================================"
echo -e "Tests Completed: ${GREEN}${passed} passed${NC}, ${RED}${failed} failed${NC}"
echo "======================================================================"
[ "$failed" -eq 0 ]
