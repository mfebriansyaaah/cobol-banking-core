#!/bin/bash
# Balance/ledger reconciliation suite (Phase 2).
# Verifies RECONCILE reports SUCCESS only when every account's stored balance
# equals its ledger sum (CREDIT - DEBIT), and ERROR|MISMATCH otherwise.
# Usage: ./tests/test_reconciliation.sh

BIN="./cobol/bin/main_logic"

if [ -f ./tests/.dbenv ]; then . ./tests/.dbenv; fi
DB_USER="${DB_USER:-cobol_user}"
DB_PASS="${DB_PASS:-cobol_pass}"
DB_NAME="${DB_NAME:-cobol_db}"

GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
passed=0; failed=0

q() { mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -N -B -e "$1" 2>/dev/null; }

reset() {
    # A clean, self-contained state: remove every user (cascades to accounts,
    # ledger, audit, sessions) and re-seed the known rows plus the admin actor.
    q "DELETE FROM users;
       INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES
         (1,'sender@test.com','hash1','Sender User','1990-01-01','VERIFIED','USER'),
         (2,'receiver@test.com','hash2','Receiver User','1990-01-02','VERIFIED','USER'),
         (930,'recon_admin@test.com',CONCAT('SHA256_',SHA2('secret123',256)),'Recon Admin','1990-01-01','VERIFIED','SUPER_ADMIN');
       INSERT INTO accounts (account_id,user_id,currency_id,account_type,balance,status) VALUES
         (1,1,1,'SAVINGS',1000.00,'ACTIVE'),
         (2,2,1,'SAVINGS',0.00,'ACTIVE');
       INSERT INTO ledger (txn_ref,account_id,amount,type,currency_id,description) VALUES
         ('INIT_001',1,1000.00,'CREDIT',1,'Initial Deposit'),
         ('INIT_002',2,0.00,'CREDIT',1,'Initial Deposit');"
}

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
echo "  BALANCE / LEDGER RECONCILIATION SUITE"
echo "======================================================================"

# A SUPER_ADMIN actor is required to run the diagnostic; reset() seeds it.
ADMIN="recon_admin@test.com"

# --- A: fresh ledger-consistent state reconciles ---
reset
check "fresh state reconciled" "SUCCESS|RECONCILED" "$(run RECONCILE "$ADMIN" "" "" "")"

# --- A2: the actor gate rejects non-admins, unknown and blank actors ---
check "non-admin actor forbidden" "ERROR|FORBIDDEN" "$(run RECONCILE sender@test.com "" "" "")"
check "unknown actor forbidden" "ERROR|FORBIDDEN" "$(run RECONCILE ghost@test.com "" "" "")"
check "blank actor forbidden" "ERROR|FORBIDDEN" "$(run RECONCILE "" "" "" "")"

# --- B: a real transfer keeps the invariant ---
out=$(run TRANSFER sender@test.com receiver@test.com 100.00 "")
check "transfer ok" "SUCCESS|TRANSFER_OK" "$out"
check "reconciled after transfer" "SUCCESS|RECONCILED" "$(run RECONCILE "$ADMIN" "" "" "")"

# --- C: a balance drift is detected ---
reset
q "UPDATE accounts SET balance = balance + 5.00 WHERE account_id=2;"
check "drift detected" "ERROR|MISMATCH|2|5.00|0.00" "$(run RECONCILE "$ADMIN" "" "" "")"

# --- D: a ledger sum that no longer matches the stored balance is detected ---
reset
q "UPDATE accounts SET balance=900.00 WHERE account_id=1;"
check "mismatch detected" "ERROR|MISMATCH|1|900.00|1000.00" "$(run RECONCILE "$ADMIN" "" "" "")"

# --- E: surviving a rolled-back transfer leaves no drift ---
reset
out=$(run TRANSFER sender@test.com nobody@test.com 100.00 "")
check "failed transfer did not drift" "ERROR|TARGET_NOT_FOUND" "$out"
check "reconciled after rollback" "SUCCESS|RECONCILED" "$(run RECONCILE "$ADMIN" "" "" "")"

echo "======================================================================"
echo -e "Tests Completed: ${GREEN}${passed} passed${NC}, ${RED}${failed} failed${NC}"
echo "======================================================================"
[ "$failed" -eq 0 ]
