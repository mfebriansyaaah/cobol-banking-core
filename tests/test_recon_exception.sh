#!/bin/bash
# Reconciliation exception workflow (Phase 1, Sprint 1 slice 15).
BIN="./cobol/bin/main_logic"
. ./tests/serve_harness.sh
if [ -f ./tests/.dbenv ]; then . ./tests/.dbenv; fi
DB_USER="${DB_USER:-cobol_user}"; DB_PASS="${DB_PASS:-cobol_pass}"; DB_NAME="${DB_NAME:-cobol_db}"
GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'; passed=0; failed=0
q() { mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -N -B -e "$1" 2>/dev/null; }
run() { core_run "$@"; }
check() { local n="$1" e="$2" a="$3"; if [ "$a" = "$e" ]; then echo -e "${GREEN}PASS${NC} $n"; passed=$((passed+1)); else echo -e "${RED}FAIL${NC} $n (expected [$e] got [$a])"; failed=$((failed+1)); fi; }
check_contains() { local n="$1" x="$2" a="$3"; if [[ "$a" == *"$x"* ]]; then echo -e "${GREEN}PASS${NC} $n"; passed=$((passed+1)); else echo -e "${RED}FAIL${NC} $n (expected [$x] got [$a])"; failed=$((failed+1)); fi; }
ADM="rex_admin@test.com"; OWNER="rex_owner@test.com"; CUST="rex_cust@test.com"
cleanup() {
    q "DELETE FROM recon_exception_audit WHERE actor_email IN ('$ADM','$CUST');
       DELETE FROM recon_exception WHERE created_by IN ('$ADM');
       DELETE FROM reconciliation_findings WHERE account_id IN (SELECT account_id FROM accounts WHERE user_id IN (SELECT id FROM users WHERE email='$CUST'));
       DELETE FROM reconciliation_runs WHERE actor_email='$ADM';
       DELETE FROM accounts WHERE user_id IN (SELECT id FROM users WHERE email='$CUST');
       DELETE FROM users WHERE email IN ('$ADM','$OWNER','$CUST');"
}
setup() {
    cleanup
    q "INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES
       (1150,'$ADM','x','REX Admin','1990-01-01','VERIFIED','SUPER_ADMIN'),
       (1151,'$OWNER','x','REX Owner','1990-01-01','VERIFIED','MANAGER'),
       (1152,'$CUST','x','REX Customer','1990-01-01','VERIFIED','USER')
       ON DUPLICATE KEY UPDATE role=VALUES(role),status='VERIFIED';
       INSERT INTO accounts (user_id,currency_id,balance,status) SELECT 1152,currency_id,0,'ACTIVE' FROM currencies WHERE iso_code='IDR' LIMIT 1;
       SET @aid=LAST_INSERT_ID();
       INSERT INTO reconciliation_runs (trigger_src,actor_email,status,mismatch_count) VALUES ('MANUAL','$ADM','MISMATCH',1);
       SET @rid=LAST_INSERT_ID();
       INSERT INTO reconciliation_findings (run_id,account_id,balance,ledger_sum,status) VALUES (@rid,@aid,10,5,'OPEN');"
}
teardown() { cleanup; q "DELETE FROM audit_trail WHERE action='AUTHZ_DENIED' AND actor_id=1152;"; }
trap 'core_stop; teardown' EXIT
core_start
echo "======================================================================"
echo "  RECONCILIATION EXCEPTION SUITE (PHASE 1)"
echo "======================================================================"
setup
FIND="$(q "SELECT finding_id FROM reconciliation_findings WHERE account_id IN (SELECT account_id FROM accounts WHERE user_id=1152) LIMIT 1;")"
check_contains "open exception" "SUCCESS|REX_OPENED" \
    "$(run REX_OPEN "$FIND" REXTEST NORMAL "$OWNER" 2026-11-01 "$ADM")"
EID="$(q "SELECT id FROM recon_exception WHERE exception_code='REXTEST' ORDER BY id DESC LIMIT 1;")"
check_contains "list exceptions" "REXTEST" "$(run REX_LIST '' '' 50 0 '' "$ADM")"
check_contains "get exception" "REX_EXCEPTION|$EID" "$(run REX_GET "$EID" '' '' '' '' "$ADM")"
check "assign exception" "SUCCESS|REX_ASSIGNED" "$(run REX_ASSIGN "$EID" "$OWNER" 'assigning' '' '' "$ADM")"
check "add exception note" "SUCCESS|REX_NOTED" "$(run REX_NOTE_ADD "$EID" 'note text' '' '' '' "$ADM")"
check "escalate exception" "SUCCESS|REX_ESCALATED" "$(run REX_ESCALATE "$EID" "$OWNER" 'escalating' '' '' "$ADM")"
check "resolve exception" "SUCCESS|REX_RESOLVED" "$(run REX_RESOLVE "$EID" 'resolved' '' '' '' "$ADM")"
check "close exception" "SUCCESS|REX_CLOSED" "$(run REX_CLOSE "$EID" 'closing' '' '' '' "$ADM")"
check_contains "exception history" "note text" "$(run REX_HISTORY "$EID" 50 0 '' '' "$ADM")"
check_contains "summary" "REX_SUMMARY|" "$(run REX_SUMMARY '' '' '' '' '' "$ADM")"
check_contains "overdue" "REX_OVERDUE|" "$(run REX_OVERDUE '' 50 0 '' '' "$ADM")"
check "open second exception" "SUCCESS|REX_OPENED" \
    "$(run REX_OPEN "$FIND" REXTEST2 HIGH '' '' "$ADM")"
EID2="$(q "SELECT id FROM recon_exception WHERE exception_code='REXTEST2' ORDER BY id DESC LIMIT 1;")"
check "reject second exception" "SUCCESS|REX_REJECTED" \
    "$(run REX_REJECT "$EID2" 'rejected' '' '' '' "$ADM")"
check "missing exception rejected" "ERROR|NOT_FOUND" "$(run REX_GET 999999 '' '' '' '' "$ADM")"
check "non-admin forbidden" "ERROR|FORBIDDEN" "$(run REX_SUMMARY '' '' '' '' '' "$CUST")"
check "recon exception audit rows recorded" "9" \
    "$(q "SELECT COUNT(*) FROM recon_exception_audit WHERE actor_email IN ('$ADM','$CUST') AND action IN ('EXCEPTION_OPEN','EXCEPTION_ASSIGN','EXCEPTION_NOTE','EXCEPTION_ESCALATE','EXCEPTION_RESOLVE','EXCEPTION_CLOSE','EXCEPTION_REJECT','EXCEPTION_OPEN','AUTHZ_DENIED');")"
echo "----------------------------------------------------------------------"; echo "PASSED: $passed  FAILED: $failed"; echo "----------------------------------------------------------------------"; [ "$failed" -eq 0 ]
