#!/bin/bash
# Journal suite: every posting writes one journal_entries header (business
# date, source, reference, initiator); legs and audit rows point at it;
# each journal holds exactly one balanced DEBIT/CREDIT pair. A kill -9
# mid-posting (blocked on a table lock) rolls everything back and the same
# key retries cleanly.
# Usage: ./tests/test_journal.sh

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

setup_users() {
    # Drop orphan journals first: other suites wipe ledger/pending globally,
    # which would otherwise leave journals with no legs behind.
    q "DELETE FROM journal_entries WHERE journal_id NOT IN (SELECT journal_id FROM ledger WHERE journal_id IS NOT NULL);"
    q "DELETE FROM accounts WHERE account_id IN (981,982,983);
       DELETE FROM users WHERE email IN ('j_a@test.com','j_b@test.com','j_fx@test.com','j_adm@test.com');
       INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES
       (981,'j_a@test.com','x','Journal A','1990-01-01','VERIFIED','USER'),
       (982,'j_b@test.com','x','Journal B','1990-01-01','VERIFIED','USER'),
       (983,'j_fx@test.com','x','Journal FX','1990-01-01','VERIFIED','USER'),
       (984,'j_adm@test.com','x','Journal Admin','1990-01-01','VERIFIED','SUPER_ADMIN');
       INSERT INTO accounts (account_id,user_id,currency_id,balance,account_type) VALUES
       (981,981,1,100000,'SAVINGS'),
       (982,982,1,0,'SAVINGS'),
       (983,983,3,0,'SAVINGS');"
}

cleanup_ref() {
    q "DELETE FROM ledger WHERE txn_ref='$1';
       DELETE FROM pending_transactions WHERE txn_ref='$1';
       DELETE FROM transfer_reversals WHERE orig_ref='$1';
       DELETE FROM audit_trail WHERE detail LIKE '%$1%' OR entity_id='$1';
       DELETE FROM journal_entries WHERE txn_ref='$1';"
}

teardown_users() {
    for p in ${LOCKER_PID:-} ${TXN_PID:-}; do kill -9 "$p" 2>/dev/null || true; done
    cleanup_ref j1; cleanup_ref jfx; cleanup_ref jkill
    q "DELETE FROM ledger WHERE account_id IN (981,982,983);
       DELETE FROM pending_transactions WHERE from_email LIKE 'j_%@test.com' OR to_email LIKE 'j_%@test.com';
       DELETE FROM accounts WHERE account_id IN (981,982,983);
       DELETE FROM users WHERE id IN (981,982,983,984);"
}
trap teardown_users EXIT

echo "======================================================================"
echo "  JOURNAL SUITE"
echo "======================================================================"

setup_users

# --- a transfer opens exactly one TRANSFER journal ---------------------------
check "transfer ok" "SUCCESS|TRANSFER_OK" "$(run TRANSFER j_a@test.com j_b@test.com 250.00 j1)"
check "one journal for the ref" "1" "$(q "SELECT COUNT(*) FROM journal_entries WHERE txn_ref='j1';")"
check "journal source" "TRANSFER" "$(q "SELECT source FROM journal_entries WHERE txn_ref='j1';")"
check "journal actor is the sender" "j_a@test.com" "$(q "SELECT actor_email FROM journal_entries WHERE txn_ref='j1';")"
check "journal value date is today" "$(q "SELECT CURRENT_DATE();")" "$(q "SELECT value_date FROM journal_entries WHERE txn_ref='j1';")"
check "two legs" "2" "$(q "SELECT COUNT(*) FROM ledger WHERE txn_ref='j1';")"
check "one debit one credit" "1|1" "$(q "SELECT CONCAT(SUM(type='DEBIT'), '|', SUM(type='CREDIT')) FROM ledger WHERE txn_ref='j1';")"
check "same-currency legs agree" "1" "$(q "SELECT (SELECT amount FROM ledger WHERE txn_ref='j1' AND type='DEBIT') = (SELECT amount FROM ledger WHERE txn_ref='j1' AND type='CREDIT');")"
check "legs carry the journal" "0" "$(q "SELECT COUNT(*) FROM ledger WHERE txn_ref='j1' AND journal_id IS NULL;")"
check "audit row carries the journal" "1" "$(q "SELECT COUNT(*) FROM audit_trail WHERE action='TRANSFER' AND detail LIKE 'j_b@test.com:250.00%' AND journal_id = (SELECT journal_id FROM journal_entries WHERE txn_ref='j1');")"

# --- a reversal opens its own REVERSAL journal ---------------------------------
check "reversal ok" "SUCCESS|TRANSFER_REVERSED" "$(run REVERSE_TRANSFER j1 j_adm@test.com j_a@test.com)"
check "two journals for the ref" "2" "$(q "SELECT COUNT(*) FROM journal_entries WHERE txn_ref='j1';")"
check "reversal journal source and actor" "REVERSAL|j_adm@test.com" "$(q "SELECT CONCAT(source, '|', actor_email) FROM journal_entries WHERE txn_ref='j1' AND source='REVERSAL';")"
check "four legs total" "4" "$(q "SELECT COUNT(*) FROM ledger WHERE txn_ref='j1';")"
check "reversal legs are journal-linked" "2" "$(q "SELECT COUNT(*) FROM ledger WHERE txn_ref='j1' AND journal_id = (SELECT journal_id FROM journal_entries WHERE txn_ref='j1' AND source='REVERSAL');")"
check "reversal audit carries the journal" "1" "$(q "SELECT COUNT(*) FROM audit_trail WHERE action='REVERSE_TRANSFER' AND entity_id='j1' AND journal_id = (SELECT journal_id FROM journal_entries WHERE txn_ref='j1' AND source='REVERSAL');")"

# --- cross-currency journal legs follow the snapshotted rate -------------------
check "fx transfer ok" "SUCCESS|TRANSFER_OK" "$(run TRANSFER j_a@test.com j_fx@test.com 100.00 jfx)"
check "fx legs agree through the rate" "1" "$(q "SELECT (SELECT amount FROM ledger WHERE txn_ref='jfx' AND type='CREDIT') = ROUND((SELECT amount FROM ledger WHERE txn_ref='jfx' AND type='DEBIT') * (SELECT exchange_rate FROM ledger WHERE txn_ref='jfx' AND type='CREDIT'), 0);")"
check "fx journal exists" "TRANSFER" "$(q "SELECT source FROM journal_entries WHERE txn_ref='jfx';")"

# --- structural invariant across every journal in the database ------------------
check "no journal without exactly two legs" "0" "$(q "SELECT COUNT(*) FROM journal_entries j WHERE (SELECT COUNT(*) FROM ledger l WHERE l.journal_id = j.journal_id) <> 2;")"
check "no journal without one debit and one credit" "0" "$(q "SELECT COUNT(*) FROM journal_entries j WHERE (SELECT SUM(l.type='DEBIT') FROM ledger l WHERE l.journal_id = j.journal_id) <> 1 OR (SELECT SUM(l.type='CREDIT') FROM ledger l WHERE l.journal_id = j.journal_id) <> 1;")"
check "no journal with disagreeing legs" "0" "$(q "SELECT COUNT(*) FROM journal_entries j WHERE NOT ((SELECT MAX(CASE WHEN l.type='CREDIT' THEN l.amount END) FROM ledger l WHERE l.journal_id = j.journal_id) = ROUND((SELECT MAX(CASE WHEN l.type='DEBIT' THEN l.amount END) FROM ledger l WHERE l.journal_id = j.journal_id) * (SELECT MAX(CASE WHEN l.type='CREDIT' THEN l.exchange_rate END) FROM ledger l WHERE l.journal_id = j.journal_id), (SELECT c.prec_val FROM ledger l JOIN currencies c ON c.currency_id = l.currency_id WHERE l.journal_id = j.journal_id AND l.type='CREDIT')) OR (SELECT MAX(CASE WHEN l.type='DEBIT' THEN l.amount END) FROM ledger l WHERE l.journal_id = j.journal_id) = ROUND((SELECT MAX(CASE WHEN l.type='CREDIT' THEN l.amount END) FROM ledger l WHERE l.journal_id = j.journal_id) * (SELECT MAX(CASE WHEN l.type='CREDIT' THEN l.exchange_rate END) FROM ledger l WHERE l.journal_id = j.journal_id), (SELECT c.prec_val FROM ledger l JOIN currencies c ON c.currency_id = l.currency_id WHERE l.journal_id = j.journal_id AND l.type='CREDIT')));")"

# --- kill -9 mid-posting rolls back; the same key retries cleanly ---------------
# Hold a WRITE lock on ledger so the transfer blocks inside its transaction
# (on the journal insert, before any leg or balance change is durable).
mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "LOCK TABLES ledger WRITE; SELECT SLEEP(25); UNLOCK TABLES;" >/dev/null 2>&1 &
LOCKER_PID=$!
sleep 2
before_kill="$(q "SELECT balance FROM accounts WHERE account_id=981;")"
printf "TRANSFER|j_a@test.com|j_b@test.com|50.00|jkill\n" > input.txt
"$BIN" >/dev/null 2>&1 &
TXN_PID=$!
blocked=0
for _ in $(seq 1 20); do
    if [ "$(q "SELECT COUNT(*) FROM information_schema.processlist WHERE DB='$DB_NAME' AND COMMAND='Execute' AND INFO LIKE '%journal_entries%' AND (STATE LIKE '%lock%' OR STATE LIKE '%Waiting%');")" != "0" ]; then blocked=1; break; fi
    sleep 1
done
check "transfer blocked inside its transaction" "1" "$blocked"
if kill -9 "$TXN_PID" 2>/dev/null; then in_flight=1; else in_flight=0; fi
check "binary was in flight at kill time" "1" "$in_flight"
wait "$TXN_PID" 2>/dev/null || true
TXN_PID=""
kill -9 "$LOCKER_PID" 2>/dev/null || true
wait "$LOCKER_PID" 2>/dev/null || true
LOCKER_PID=""
check "crashed posting left no journal" "0" "$(q "SELECT COUNT(*) FROM journal_entries WHERE txn_ref='jkill';")"
check "crashed posting left no legs" "0" "$(q "SELECT COUNT(*) FROM ledger WHERE txn_ref='jkill';")"
check "crashed posting left no intent" "0" "$(q "SELECT COUNT(*) FROM pending_transactions WHERE txn_ref='jkill';")"
check "crashed posting moved no money" "$before_kill" "$(q "SELECT balance FROM accounts WHERE account_id=981;")"
check "retry after crash succeeds" "SUCCESS|TRANSFER_OK" "$(run TRANSFER j_a@test.com j_b@test.com 50.00 jkill)"
check "retry posted exactly one journal" "1" "$(q "SELECT COUNT(*) FROM journal_entries WHERE txn_ref='jkill';")"

echo "======================================================================"
echo "Tests Completed: ${GREEN}${passed} passed${NC}, ${RED}${failed} failed${NC}"
echo "======================================================================"
[ "$failed" -eq 0 ]
