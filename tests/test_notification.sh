#!/bin/bash
# Notification templates/preferences suite (Sprint 1 slice 6).
BIN="./cobol/bin/main_logic"
. ./tests/serve_harness.sh
if [ -f ./tests/.dbenv ]; then . ./tests/.dbenv; fi
DB_USER="${DB_USER:-cobol_user}"; DB_PASS="${DB_PASS:-cobol_pass}"; DB_NAME="${DB_NAME:-cobol_db}"
GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
passed=0; failed=0
q() { mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -N -B -e "$1" 2>/dev/null; }
run() { core_run "$@"; }
check() { local n="$1" e="$2" a="$3"; if [ "$a" = "$e" ]; then echo -e "${GREEN}PASS${NC} $n"; passed=$((passed+1)); else echo -e "${RED}FAIL${NC} $n (expected [$e] got [$a])"; failed=$((failed+1)); fi; }
check_contains() { local n="$1" x="$2" a="$3"; if [[ "$a" == *"$x"* ]]; then echo -e "${GREEN}PASS${NC} $n"; passed=$((passed+1)); else echo -e "${RED}FAIL${NC} $n (expected [$x] got [$a])"; failed=$((failed+1)); fi; }
ADM="notif_admin@test.com"; USR="notif_user@test.com"; TPL="NTF_TEST"
cleanup() {
 q "DELETE FROM notification_audit WHERE actor_email IN ('$ADM','$USR');
    DELETE FROM notification_preference WHERE user_email='$USR';
    DELETE FROM notification_outbox WHERE recipient='$USR';
    DELETE FROM notification_template WHERE template_code='$TPL';
    DELETE FROM users WHERE email IN ('$ADM','$USR');"
}
setup() {
 cleanup
 q "INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES (1003,'$ADM','x','Notif Admin','1990-01-01','VERIFIED','SUPER_ADMIN'),(1004,'$USR','x','Notif User','1990-01-01','VERIFIED','USER') ON DUPLICATE KEY UPDATE role=VALUES(role),status='VERIFIED';"
}
teardown() { cleanup; q "DELETE FROM audit_trail WHERE action='AUTHZ_DENIED' AND actor_id=1004;"; }
trap 'core_stop; teardown' EXIT
core_start
echo "======================================================================"
echo "  NOTIFICATION CENTER SUITE (PHASE 1)"
echo "======================================================================"
setup

check "set template" "SUCCESS|NTF_TEMPLATE_SET" \
 "$(run NTF_TEMPLATE_SET "$TPL" LOGIN EMAIL 'Login alert' 'Hello' "$ADM")"
check_contains "list templates" "$TPL:LOGIN:EMAIL" \
 "$(run NTF_TEMPLATE_LIST 50 0 LOGIN EMAIL '' "$ADM")"
check_contains "get template" "Login alert" \
 "$(run NTF_TEMPLATE_GET "$TPL" '' '' '' '' "$ADM")"
check "set preference" "SUCCESS|NTF_PREF_SET" \
 "$(run NTF_PREF_SET "$USR" LOGIN EMAIL 0 '' "$ADM")"
check_contains "list preferences" "LOGIN:EMAIL:0" \
 "$(run NTF_PREF_LIST "$USR" 50 0 '' '' "$ADM")"
check "preference check disabled" "SUCCESS|NTF_PREF|$USR:LOGIN:EMAIL:0" \
 "$(run NTF_PREF_CHECK "$USR" LOGIN EMAIL '' '' "$ADM")"
check "send suppressed" "SUCCESS|NTF_SUPPRESSED" \
 "$(run NTF_SEND "$USR" LOGIN CODE1 detail '' "$ADM")"
check "enable preference" "SUCCESS|NTF_PREF_SET" \
 "$(run NTF_PREF_SET "$USR" LOGIN EMAIL 1 '' "$ADM")"
check "send queued" "SUCCESS|NTF_QUEUED" \
 "$(run NTF_SEND "$USR" LOGIN CODE2 detail '' "$ADM")"
check "delete template" "SUCCESS|NTF_TEMPLATE_DELETED" \
 "$(run NTF_TEMPLATE_DELETE "$TPL" '' '' '' '' "$ADM")"
check "non-admin forbidden" "ERROR|FORBIDDEN" \
 "$(run NTF_TEMPLATE_LIST 50 0 '' '' '' "$USR")"
check "notification audit rows recorded" "6" \
 "$(q "SELECT COUNT(*) FROM notification_audit WHERE actor_email IN ('$ADM','$USR');")"
echo "----------------------------------------------------------------------"
echo "PASSED: $passed  FAILED: $failed"
echo "----------------------------------------------------------------------"
[ "$failed" -eq 0 ]
