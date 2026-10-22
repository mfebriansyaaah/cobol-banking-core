#!/bin/bash
# Import reconciliation suite (Phase 1, Sprint 1 slice 14).
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
ADM="irc_admin@test.com"; USR="irc_user@test.com"; BATCH="IRC_BATCH"; TODAY="$(date +%F)"
cleanup() {
    q "DELETE FROM import_audit WHERE actor_email IN ('$ADM','$USR');
       DELETE FROM import_recon_run WHERE batch_id IN (SELECT id FROM import_batch WHERE batch_code LIKE 'IRC_%');
       DELETE FROM import_posting WHERE batch_id IN (SELECT id FROM import_batch WHERE batch_code LIKE 'IRC_%');
       DELETE FROM gl_journal WHERE description LIKE 'IRC%';
       DELETE FROM import_batch WHERE batch_code LIKE 'IRC_%';"
}
setup() {
    cleanup
    q "DELETE FROM users WHERE email IN ('$ADM','$USR');
       INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES
       (1140,'$ADM','x','IRC Admin','1990-01-01','VERIFIED','SUPER_ADMIN'),
       (1141,'$USR','x','IRC User','1990-01-01','VERIFIED','USER')
       ON DUPLICATE KEY UPDATE role=VALUES(role),status='VERIFIED';
       INSERT IGNORE INTO gl_period (period_code,status) VALUES (LEFT('$TODAY',7),'OPEN');"
}
teardown() { cleanup; q "DELETE FROM audit_trail WHERE action='AUTHZ_DENIED' AND actor_id=1141; DELETE FROM users WHERE email IN ('$ADM','$USR');"; }
trap 'core_stop; teardown' EXIT
core_start
echo "======================================================================"
echo "  IMPORT RECONCILIATION SUITE (PHASE 1)"
echo "======================================================================"
setup

check_contains "create ledger batch" "SUCCESS|IMP_BATCH_CREATED|" \
    "$(run IMP_BATCH_CREATE $BATCH ledger.csv LEDGER '' '' "$ADM")"
check "stage debit row" "SUCCESS|IMP_ROW_STAGED" "$(run IMP_ROW_STAGE $BATCH 1 '1000:100:0' '' '' "$ADM")"
check "stage credit row" "SUCCESS|IMP_ROW_STAGED" "$(run IMP_ROW_STAGE $BATCH 2 '4000:0:100' '' '' "$ADM")"
check "validate ledger batch" "SUCCESS|IMP_VALIDATED|2|0" "$(run IMP_BATCH_VALIDATE $BATCH '' '' '' '' "$ADM")"
check_contains "post ledger batch" "SUCCESS|IMP_LEDGER_POSTED|" \
    "$(run IMPP_LEDGER $BATCH $TODAY 'IRC posting' IDR '' "$ADM")"
check_contains "start import recon" "SUCCESS|IRC_STARTED|" \
    "$(run IRC_START $BATCH '' '' '' '' "$ADM")"
RID="$(q "SELECT id FROM import_recon_run WHERE batch_id=(SELECT id FROM import_batch WHERE batch_code='$BATCH') ORDER BY id DESC LIMIT 1;")"
check_contains "match import to ledger" "SUCCESS|IRC_MATCHED|2|2|0|0" \
    "$(run IRC_MATCH "$RID" '' '' '' '' "$ADM")"
check_contains "items list" "1000" "$(run IRC_ITEMS "$RID" '' 50 0 '' "$ADM")"
check_contains "export recon items" "1000" "$(run IRC_EXPORT "$RID" CSV '' '' '' "$ADM")"
check_contains "finish recon" "SUCCESS|IRC_FINISHED|2|2|0|0" \
    "$(run IRC_FINISH "$RID" '' '' '' '' "$ADM")"
check_contains "get recon run" "COMPLETED" "$(run IRC_GET "$RID" '' '' '' '' "$ADM")"
check_contains "list recon runs" "$RID" "$(run IRC_LIST 50 0 '' '' '' "$ADM")"
check_contains "summary" "IRC_SUMMARY|$RID|COMPLETED" "$(run IRC_SUMMARY $BATCH '' '' '' '' "$ADM")"
check "retry finished rejected" "ERROR|INVALID_STATUS" "$(run IRC_RETRY "$RID" '' '' '' '' "$ADM")"
check "missing batch rejected" "ERROR|NOT_FOUND" "$(run IRC_START MISSING '' '' '' '' "$ADM")"
check "non-admin forbidden" "ERROR|FORBIDDEN" "$(run IRC_LIST 50 0 '' '' '' "$USR")"
check "import recon audit rows recorded" "4" \
    "$(q "SELECT COUNT(*) FROM import_audit WHERE actor_email IN ('$ADM','$USR') AND action IN ('IMPORT_RECON_START','IMPORT_RECON_MATCH','IMPORT_RECON_FINISH','IMPORT_RECON_RETRY','AUTHZ_DENIED');")"
echo "----------------------------------------------------------------------"; echo "PASSED: $passed  FAILED: $failed"; echo "----------------------------------------------------------------------"; [ "$failed" -eq 0 ]
