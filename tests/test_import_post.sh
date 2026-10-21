#!/bin/bash
# Import ledger posting suite (Phase 1, Sprint 1 slice 8).
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
ADM="import_post_admin@test.com"; USR="import_post_user@test.com"
cleanup() {
    q "DELETE FROM import_audit WHERE actor_email IN ('$ADM','$USR');
       DELETE FROM import_posting WHERE created_by IN ('$ADM','$USR');
       DELETE FROM gl_journal WHERE description LIKE 'IMPTEST%';
       DELETE FROM import_batch WHERE batch_code LIKE 'IMP_LEDGER%' OR batch_code LIKE 'IMP_UNBAL%' OR batch_code LIKE 'IMP_REF%';"
}
setup() {
    cleanup
    q "DELETE FROM users WHERE email IN ('$ADM','$USR');
       INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES
       (1010,'${ADM}','x','Import Post Admin','1990-01-01','VERIFIED','SUPER_ADMIN'),
       (1011,'${USR}','x','Import Post User','1990-01-01','VERIFIED','USER')
       ON DUPLICATE KEY UPDATE role=VALUES(role),status='VERIFIED';
       INSERT IGNORE INTO gl_period (period_code,status) VALUES ('2026-10','OPEN'),('2026-09','CLOSED');"
}
teardown() { cleanup; q "DELETE FROM gl_period WHERE period_code='2026-09'; DELETE FROM audit_trail WHERE action='AUTHZ_DENIED' AND actor_id=1011; DELETE FROM users WHERE email IN ('$ADM','$USR');"; }
trap 'core_stop; teardown' EXIT
core_start
echo "======================================================================"
echo "  IMPORT LEDGER POSTING SUITE (PHASE 1)"
echo "======================================================================"
setup

check_contains "create ledger batch" "SUCCESS|IMP_BATCH_CREATED|" \
    "$(run IMP_BATCH_CREATE IMP_LEDGER ledger.csv LEDGER '' '' "$ADM")"
check "stage debit row" "SUCCESS|IMP_ROW_STAGED" \
    "$(run IMP_ROW_STAGE IMP_LEDGER 1 '1000:100:0' '' '' "$ADM")"
check "stage credit row" "SUCCESS|IMP_ROW_STAGED" \
    "$(run IMP_ROW_STAGE IMP_LEDGER 2 '4000:0:100' '' '' "$ADM")"
check "validate ledger batch" "SUCCESS|IMP_VALIDATED|2|0" \
    "$(run IMP_BATCH_VALIDATE IMP_LEDGER '' '' '' '' "$ADM")"
check "parsed account stored" "1000" \
    "$(q "SELECT parsed_account FROM import_row WHERE batch_id=(SELECT id FROM import_batch WHERE batch_code='IMP_LEDGER') AND row_no=1;")"
check "parsed debit stored" "100.0000000000" \
    "$(q "SELECT debit_amount FROM import_row WHERE batch_id=(SELECT id FROM import_batch WHERE batch_code='IMP_LEDGER') AND row_no=1;")"
check "parsed credit stored" "100.0000000000" \
    "$(q "SELECT credit_amount FROM import_row WHERE batch_id=(SELECT id FROM import_batch WHERE batch_code='IMP_LEDGER') AND row_no=2;")"
check_contains "post ledger batch" "SUCCESS|IMP_LEDGER_POSTED|" \
    "$(run IMPP_LEDGER IMP_LEDGER 2026-10-21 'IMPTEST ledger posting' IDR '' "$ADM")"
JID="$(q "SELECT journal_id FROM import_posting p JOIN import_batch b ON b.id=p.batch_id WHERE b.batch_code='IMP_LEDGER';")"
check_contains "journal header created" "IMPTEST ledger posting" \
    "$(q "SELECT description FROM gl_journal WHERE id=$JID;")"
check "journal lines created" "2" \
    "$(q "SELECT COUNT(*) FROM gl_journal_line WHERE journal_id=$JID;")"
check "journal is balanced" "0.0000000000" \
    "$(q "SELECT ABS(SUM(debit_amount)-SUM(credit_amount)) FROM gl_journal_line WHERE journal_id=$JID;")"
check "import posting recorded" "1" \
    "$(q "SELECT COUNT(*) FROM import_posting WHERE batch_id=(SELECT id FROM import_batch WHERE batch_code='IMP_LEDGER');")"
check "batch completed" "COMPLETED" \
    "$(q "SELECT status FROM import_batch WHERE batch_code='IMP_LEDGER';")"
check "rows posted" "2" \
    "$(q "SELECT COUNT(*) FROM import_row WHERE batch_id=(SELECT id FROM import_batch WHERE batch_code='IMP_LEDGER') AND status='POSTED';")"
check_contains "list postings" "IMP_LEDGER" \
    "$(run IMPP_LIST 50 0 '' '' '' "$ADM")"
check_contains "get posting" "$JID" \
    "$(run IMPP_GET "$(q "SELECT p.id FROM import_posting p JOIN import_batch b ON b.id=p.batch_id WHERE b.batch_code='IMP_LEDGER';")" '' '' '' '' "$ADM")"
check "duplicate posting rejected" "ERROR|INVALID_STATUS" \
    "$(run IMPP_LEDGER IMP_LEDGER 2026-10-21 'IMPTEST again' IDR '' "$ADM")"

check_contains "create unbalanced batch" "SUCCESS|IMP_BATCH_CREATED|" \
    "$(run IMP_BATCH_CREATE IMP_UNBAL unbal.csv LEDGER '' '' "$ADM")"
check "stage unbalanced row" "SUCCESS|IMP_ROW_STAGED" \
    "$(run IMP_ROW_STAGE IMP_UNBAL 1 '1000:100:0' '' '' "$ADM")"
check "validate unbalanced batch" "SUCCESS|IMP_VALIDATED|1|0" \
    "$(run IMP_BATCH_VALIDATE IMP_UNBAL '' '' '' '' "$ADM")"
check "unbalanced batch rejected" "ERROR|UNBALANCED" \
    "$(run IMPP_LEDGER IMP_UNBAL 2026-10-21 'IMPTEST unbal' IDR '' "$ADM")"

check_contains "create invalid ledger batch" "SUCCESS|IMP_BATCH_CREATED|" \
    "$(run IMP_BATCH_CREATE IMP_LEDGER_BAD bad.csv LEDGER '' '' "$ADM")"
check "stage invalid ledger row" "SUCCESS|IMP_ROW_STAGED" \
    "$(run IMP_ROW_STAGE IMP_LEDGER_BAD 1 '9999:100:0' '' '' "$ADM")"
check "invalid ledger validated" "SUCCESS|IMP_VALIDATED|0|1" \
    "$(run IMP_BATCH_VALIDATE IMP_LEDGER_BAD '' '' '' '' "$ADM")"
check "invalid ledger rejected" "ERROR|INVALID_ROWS" \
    "$(run IMPP_LEDGER IMP_LEDGER_BAD 2026-10-21 'IMPTEST bad' IDR '' "$ADM")"

check_contains "create reference batch" "SUCCESS|IMP_BATCH_CREATED|" \
    "$(run IMP_BATCH_CREATE IMP_REF_ONE ref.csv REFERENCE '' '' "$ADM")"
check "non-ledger batch rejected" "ERROR|INVALID_INPUT" \
    "$(run IMPP_LEDGER IMP_REF_ONE 2026-10-21 'IMPTEST ref' IDR '' "$ADM")"

check_contains "create closed-period batch" "SUCCESS|IMP_BATCH_CREATED|" \
    "$(run IMP_BATCH_CREATE IMP_LEDGER_CLOSED closed.csv LEDGER '' '' "$ADM")"
check "stage closed-period debit" "SUCCESS|IMP_ROW_STAGED" \
    "$(run IMP_ROW_STAGE IMP_LEDGER_CLOSED 1 '1000:100:0' '' '' "$ADM")"
check "stage closed-period credit" "SUCCESS|IMP_ROW_STAGED" \
    "$(run IMP_ROW_STAGE IMP_LEDGER_CLOSED 2 '4000:0:100' '' '' "$ADM")"
check "validate closed-period batch" "SUCCESS|IMP_VALIDATED|2|0" \
    "$(run IMP_BATCH_VALIDATE IMP_LEDGER_CLOSED '' '' '' '' "$ADM")"
check "closed period rejected" "ERROR|PERIOD_NOT_OPEN" \
    "$(run IMPP_LEDGER IMP_LEDGER_CLOSED 2026-09-15 'IMPTEST closed' IDR '' "$ADM")"
check "missing batch rejected" "ERROR|NOT_FOUND" \
    "$(run IMPP_LEDGER MISSING 2026-10-21 'IMPTEST missing' IDR '' "$ADM")"
check "non-admin forbidden" "ERROR|FORBIDDEN" \
    "$(run IMPP_LIST 50 0 '' '' '' "$USR")"
check "import posting audit recorded" "2" \
    "$(q "SELECT COUNT(*) FROM import_audit WHERE actor_email IN ('$ADM','$USR') AND action IN ('LEDGER_POST','AUTHZ_DENIED');")"

echo "----------------------------------------------------------------------"
echo "PASSED: $passed  FAILED: $failed"
echo "----------------------------------------------------------------------"
[ "$failed" -eq 0 ]
