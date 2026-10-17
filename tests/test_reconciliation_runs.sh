#!/bin/bash
# Reconciliation runs suite: RUN_RECONCILIATION records immutable runs with
# per-account findings; ack claims ownership, resolve closes with a note;
# both scripts (scheduled runner, CSV export) work. Counts are relative so
# pre-existing residue in the shared database cannot flake the suite.
# Usage: ./tests/test_reconciliation_runs.sh

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

ADM="r_adm@test.com"
setup() {
    q "DELETE FROM reconciliation_findings WHERE finding_id > 0;
       DELETE FROM reconciliation_runs WHERE run_id > 0;
       DELETE FROM accounts WHERE account_id IN (981,982);
       DELETE FROM users WHERE email IN ('r_a@test.com','r_b@test.com','$ADM');
       INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES
       (981,'r_a@test.com','x','Recon A','1990-01-01','VERIFIED','USER'),
       (982,'r_b@test.com','x','Recon B','1990-01-01','VERIFIED','USER'),
       (983,'$ADM','x','Recon Admin','1990-01-01','VERIFIED','SUPER_ADMIN');
       INSERT INTO accounts (account_id,user_id,currency_id,balance,account_type) VALUES
       (981,981,1,500,'SAVINGS'),
       (982,982,1,50,'SAVINGS'),
       (983,983,1,0,'SAVINGS');
       DELETE FROM ledger WHERE account_id IN (981,982,983);
       INSERT INTO ledger (txn_ref,account_id,amount,type,currency_id,description) VALUES
       ('RCON_INIT',981,500,'CREDIT',1,'Suite opening');
       DELETE FROM pending_transactions WHERE from_email LIKE 'r_%@test.com' OR to_email LIKE 'r_%@test.com';"
}

teardown() {
    q "DELETE FROM reconciliation_findings WHERE run_id IN (SELECT run_id FROM reconciliation_runs WHERE actor_email LIKE 'r_%@test.com');
       DELETE FROM reconciliation_runs WHERE actor_email LIKE 'r_%@test.com';
       DELETE FROM audit_trail WHERE action IN ('RECONCILE_ACK','RECONCILE_RESOLVE');
       DELETE FROM ledger WHERE account_id IN (981,982,983);
       DELETE FROM pending_transactions WHERE from_email LIKE 'r_%@test.com' OR to_email LIKE 'r_%@test.com';
       DELETE FROM accounts WHERE account_id IN (981,982,983);
       DELETE FROM users WHERE id IN (981,982,983);"
}
trap teardown EXIT

echo "======================================================================"
echo "  RECONCILIATION RUNS SUITE"
echo "======================================================================"

setup

# --- a recorded run reports its id and mismatch count -------------------------
OUT1="$(run RUN_RECONCILIATION $ADM MANUAL)"
check_contains "run records" "SUCCESS|RUN_RECORDED|" "$OUT1"
RUN1="$(echo "$OUT1" | cut -d'|' -f3)"
C1="$(echo "$OUT1" | cut -d'|' -f4)"
check "first run is stored" "$RUN1" "$(q "SELECT run_id FROM reconciliation_runs WHERE actor_email='$ADM' AND trigger_src='MANUAL' ORDER BY run_id DESC LIMIT 1;")"
check "run status follows the count" "$([ "$C1" = "0" ] && echo CLEAN || echo MISMATCH)" "$(q "SELECT status FROM reconciliation_runs WHERE run_id='$RUN1';")"

# --- drift in one account grows the next count by exactly one -------------------
q "UPDATE accounts SET balance=600 WHERE account_id=981;"
OUT2="$(run RUN_RECONCILIATION $ADM MANUAL)"
C2="$(echo "$OUT2" | cut -d'|' -f4)"
RUN2="$(echo "$OUT2" | cut -d'|' -f3)"
check "second run records" "SUCCESS" "$(echo "$OUT2" | cut -d'|' -f1)"
check "drift adds exactly one mismatch" "$((C1 + 1))" "$C2"
FID="$(q "SELECT finding_id FROM reconciliation_findings WHERE run_id='$RUN2' AND account_id=981 AND status='OPEN' ORDER BY finding_id DESC LIMIT 1;")"
check "finding names the drifted account" "981|600.0000" "$(q "SELECT CONCAT(account_id, '|', balance) FROM reconciliation_findings WHERE finding_id='$FID';")"
check "non-admin cannot run" "ERROR|FORBIDDEN" "$(run RUN_RECONCILIATION r_a@test.com MANUAL)"
check "bad trigger is rejected" "ERROR|INVALID_INPUT" "$(run RUN_RECONCILIATION $ADM WEEKLY)"

# --- ownership and resolution -----------------------------------------------------
check "ack claims the finding" "SUCCESS|EXCEPTION_ACKNOWLEDGED" "$(run ACK_EXCEPTION "$FID" $ADM)"
check "ack records the owner" "$ADM|ACKNOWLEDGED" "$(q "SELECT CONCAT(owner_email, '|', status) FROM reconciliation_findings WHERE finding_id='$FID';")"
check "re-ack is refused" "ERROR|UNKNOWN_TRANSACTION" "$(run ACK_EXCEPTION "$FID" $ADM)"
check "direct resolve of an OPEN finding is refused" "ERROR|UNKNOWN_TRANSACTION" "$(run RESOLVE_EXCEPTION "$(q "SELECT finding_id FROM reconciliation_findings WHERE run_id='$RUN2' AND account_id <> 981 AND status='OPEN' ORDER BY finding_id DESC LIMIT 1;")" $ADM "x")"
check "resolve closes with a note" "SUCCESS|EXCEPTION_RESOLVED" "$(run RESOLVE_EXCEPTION "$FID" $ADM "opening balance corrected")"
check "resolution keeps owner and note" "$ADM|RESOLVED|opening balance corrected" "$(q "SELECT CONCAT(owner_email, '|', status, '|', resolution_note) FROM reconciliation_findings WHERE finding_id='$FID';")"
check "re-resolve is refused" "ERROR|UNKNOWN_TRANSACTION" "$(run RESOLVE_EXCEPTION "$FID" $ADM "again")"
check "bad finding id" "ERROR|INVALID_INPUT" "$(run ACK_EXCEPTION abc $ADM)"
check "non-admin cannot ack" "ERROR|FORBIDDEN" "$(run ACK_EXCEPTION "$FID" r_a@test.com)"
check "bad status filter" "ERROR|INVALID_INPUT" "$(run LIST_EXCEPTIONS $ADM BOGUS)"

# --- lists surface runs and findings ------------------------------------------------
check_contains "runs list the recorded run" "$RUN2:MANUAL" "$(run LIST_RECONCILIATIONS $ADM)"
check "runs list carries the total" "$(q "SELECT COUNT(*) FROM reconciliation_runs;")" "$(run LIST_RECONCILIATIONS $ADM 100 0 | cut -d'|' -f3)"
check "exceptions filter by status" "RESOLVED" "$(run LIST_EXCEPTIONS $ADM RESOLVED 1 0 | grep -oE 'RESOLVED' | head -1)"

# --- recorded runs are immutable -------------------------------------------------------
if q "UPDATE reconciliation_runs SET status='CLEAN' WHERE run_id='$RUN2';" >/dev/null 2>&1 && [ "$(q "SELECT status FROM reconciliation_runs WHERE run_id='$RUN2';")" = "CLEAN" ]; then
    check "runs refuse UPDATE" "immutable" "mutated"
else
    check "runs refuse UPDATE" "immutable" "immutable"
fi

# --- scheduled runner and CSV export ------------------------------------------------------
check "scheduled runner records a SCHEDULED run" "SUCCESS" "$(RECON_ACTOR=$ADM ./scripts/scheduled_reconcile.sh | cut -d'|' -f1)"
check "scheduled trigger is stored" "SCHEDULED" "$(q "SELECT trigger_src FROM reconciliation_runs WHERE actor_email='$ADM' ORDER BY run_id DESC LIMIT 1;")"
if RECON_ACTOR= ./scripts/scheduled_reconcile.sh >/dev/null 2>&1; then
    check "scheduled runner needs an actor" "exit 1" "exit 0"
else
    check "scheduled runner needs an actor" "exit 1" "exit 1"
fi
EXP_RUN="$(q "SELECT run_id FROM reconciliation_runs WHERE actor_email='$ADM' AND trigger_src='SCHEDULED' ORDER BY run_id DESC LIMIT 1;")"
check "export prints the run row" "run,$EXP_RUN,SCHEDULED,$ADM" "$(./scripts/export_reconciliation.sh "$EXP_RUN" | grep '^run,' | cut -d',' -f1-4)"
check "export prints finding rows" "finding" "$(./scripts/export_reconciliation.sh "$EXP_RUN" | grep -c '^finding,' >/dev/null && echo finding || echo none)"
if ./scripts/export_reconciliation.sh 999999999 >/dev/null 2>&1; then
    check "export refuses an unknown run" "exit 1" "exit 0"
else
    check "export refuses an unknown run" "exit 1" "exit 1"
fi

echo "======================================================================"
echo "Tests Completed: ${GREEN}${passed} passed${NC}, ${RED}${failed} failed${NC}"
echo "======================================================================"
[ "$failed" -eq 0 ]
