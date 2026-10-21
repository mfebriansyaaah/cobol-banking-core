#!/bin/bash
# Reconciliation auto-assignment suite (Phase 1, Sprint 1 slice 10).
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
ADM="rcp_admin@test.com"; OWNER="rcp_owner@test.com"; MGR="rcp_manager@test.com"; CUST="rcp_cust@test.com"; RULE="RCP_RULE_A"
cleanup() {
    q "DELETE FROM recon_audit WHERE actor_email IN ('$ADM','$OWNER','$CUST');
       DELETE FROM recon_assignment_rule WHERE rule_code LIKE 'RCP_RULE_%';
       DELETE FROM reconciliation_findings WHERE account_id IN (SELECT account_id FROM accounts WHERE user_id IN (SELECT id FROM users WHERE email='$CUST'));
       DELETE FROM reconciliation_runs WHERE actor_email='$ADM';
       DELETE FROM accounts WHERE user_id IN (SELECT id FROM users WHERE email='$CUST');
       DELETE FROM users WHERE email IN ('$ADM','$OWNER','$MGR','$CUST');"
}
setup() {
    cleanup
    q "INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES
       (1040,'$ADM','x','RCP Admin','1990-01-01','VERIFIED','SUPER_ADMIN'),
       (1041,'$OWNER','x','RCP Owner','1990-01-01','VERIFIED','MANAGER'),
       (1042,'$MGR','x','RCP Manager','1990-01-01','VERIFIED','MANAGER'),
       (1043,'$CUST','x','RCP Customer','1990-01-01','VERIFIED','USER')
       ON DUPLICATE KEY UPDATE role=VALUES(role),status='VERIFIED';
       INSERT INTO accounts (user_id,currency_id,balance,status) SELECT 1043,currency_id,0,'ACTIVE' FROM currencies WHERE iso_code='IDR' LIMIT 1;
       SET @aid=LAST_INSERT_ID();
       INSERT INTO reconciliation_runs (trigger_src,actor_email,status,mismatch_count) VALUES ('MANUAL','$ADM','MISMATCH',3);
       SET @rid=LAST_INSERT_ID();
       INSERT INTO reconciliation_findings (run_id,account_id,balance,ledger_sum,status,created_at) VALUES
       (@rid,@aid,10,5,'OPEN',DATE_SUB(NOW(), INTERVAL 48 HOUR)),
       (@rid,@aid,20,10,'ACKNOWLEDGED',DATE_SUB(NOW(), INTERVAL 100 HOUR)),
       (@rid,@aid,30,30,'RESOLVED',DATE_SUB(NOW(), INTERVAL 48 HOUR));"
}
teardown() { cleanup; q "DELETE FROM audit_trail WHERE action='AUTHZ_DENIED' AND actor_id=1043;"; }
trap 'core_stop; teardown' EXIT
core_start
echo "======================================================================"
echo "  RECONCILIATION AUTO-ASSIGNMENT SUITE (PHASE 1)"
echo "======================================================================"
setup
OPEN_ID="$(q "SELECT finding_id FROM reconciliation_findings WHERE status='OPEN' AND account_id IN (SELECT account_id FROM accounts WHERE user_id=1043) LIMIT 1;")"

check "set assignment rule" "SUCCESS|RCP_RULE_SET" \
    "$(run RCP_RULE_SET "$RULE" "$OWNER" ANY 0 '10,1' "$ADM")"
check_contains "get assignment rule" "$RULE|$OWNER|ANY|0|10|1" \
    "$(run RCP_RULE_GET "$RULE" '' '' '' '' "$ADM")"
check_contains "list assignment rules" "$RULE:$OWNER:ANY:0:10:1" \
    "$(run RCP_RULE_LIST 50 0 '' '' '' "$ADM")"
check_contains "preview rule matches" "$OPEN_ID" \
    "$(run RCP_RULE_PREVIEW "$RULE" 50 0 '' '' "$ADM")"
check_contains "dry-run auto assignment" "SUCCESS|RCP_AUTO_ASSIGN|2|0|1" \
    "$(run RCP_AUTO_ASSIGN 50 1 '' '' '' "$ADM")"
check "dry run did not assign" "0" \
    "$(q "SELECT COUNT(*) FROM reconciliation_findings WHERE owner_email='$OWNER';")"
check_contains "auto assignment applied" "SUCCESS|RCP_AUTO_ASSIGN|2|0|0" \
    "$(run RCP_AUTO_ASSIGN 50 0 '' '' '' "$ADM")"
check "assignments persisted" "2" \
    "$(q "SELECT COUNT(*) FROM reconciliation_findings WHERE owner_email='$OWNER';")"
check "assignment history recorded" "2" \
    "$(q "SELECT COUNT(*) FROM recon_assignment WHERE rule_code='$RULE';")"
check "manual assignment" "SUCCESS|RCP_ASSIGNED|$OWNER" \
    "$(run RCP_MANUAL_ASSIGN "$OPEN_ID" "$OWNER" 'manual note' '' '' "$ADM")"
check "manual note recorded" "1" \
    "$(q "SELECT COUNT(*) FROM recon_note WHERE finding_id=$OPEN_ID AND note='manual note';")"
check_contains "assignment history" "$OWNER" \
    "$(run RCP_HISTORY "$OPEN_ID" 50 0 '' '' "$ADM")"
check_contains "workload shows owner" "$OWNER" \
    "$(run RCP_WORKLOAD '' '' '' '' '' "$ADM")"
check "unassign finding" "SUCCESS|RCP_UNASSIGNED" \
    "$(run RCP_UNASSIGN "$OPEN_ID" 'unassign note' '' '' '' "$ADM")"
check "unassign cleared owner" "0" \
    "$(q "SELECT COUNT(*) FROM reconciliation_findings WHERE finding_id=$OPEN_ID AND owner_email IS NOT NULL;")"
check_contains "escalate overdue findings" "SUCCESS|RCP_ESCALATED|" \
    "$(run RCP_ESCALATE_OVERDUE 24 "$MGR" 50 '' '' "$ADM")"
check "manager owns overdue finding" "1" \
    "$(q "SELECT COUNT(*) FROM reconciliation_findings WHERE finding_id=$OPEN_ID AND owner_email='$MGR';")"
check "delete assignment rule" "SUCCESS|RCP_RULE_DELETED" \
    "$(run RCP_RULE_DELETE "$RULE" '' '' '' '' "$ADM")"
check "deleted rule missing" "ERROR|NOT_FOUND" \
    "$(run RCP_RULE_GET "$RULE" '' '' '' '' "$ADM")"
check "non-admin forbidden" "ERROR|FORBIDDEN" \
    "$(run RCP_WORKLOAD '' '' '' '' '' "$CUST")"
check "recon ops audit rows recorded" "7" \
    "$(q "SELECT COUNT(*) FROM recon_audit WHERE actor_email IN ('$ADM','$CUST') AND action IN ('RULE_SET','AUTO_ASSIGN','MANUAL_ASSIGN','UNASSIGN','ESCALATE_OVERDUE','RULE_DELETE','AUTHZ_DENIED');")"

echo "----------------------------------------------------------------------"
echo "PASSED: $passed  FAILED: $failed"
echo "----------------------------------------------------------------------"
[ "$failed" -eq 0 ]
