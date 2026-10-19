#!/bin/bash
# Transfer reversal + status suite: a SUPER_ADMIN can reverse a transfer once
# (compensating ledger entries, balances restored), reversing again is refused,
# and TX_STATUS reports COMMITTED/REVERSED to the sender or an admin only.
# Usage: ./tests/test_transfer_reversal.sh

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
    local name="$1" needle="$2" actual="$3"
    if [[ "$actual" == *"$needle"* ]]; then
        echo -e "${GREEN}PASS${NC} $name"; passed=$((passed+1))
    else
        echo -e "${RED}FAIL${NC} $name (expected to contain [$needle] got [$actual])"; failed=$((failed+1))
    fi
}

ADM="rev_admin@test.com"
setup() {
    q "DELETE FROM users WHERE id=990;
       INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES
       (990,'$ADM','x','Rev Admin','1990-01-01','VERIFIED','SUPER_ADMIN');
       UPDATE accounts SET balance=1000.00,status='ACTIVE' WHERE account_id=1;
       UPDATE accounts SET balance=0.00,status='ACTIVE' WHERE account_id=2;
       DELETE FROM ledger; DELETE FROM pending_transactions; DELETE FROM transfer_reversals;"
}
teardown() { q "DELETE FROM users WHERE id=990;"; }

echo "======================================================================"
echo "  TRANSFER REVERSAL SUITE"
echo "======================================================================"

setup
check "transfer" "SUCCESS|TRANSFER_OK" "$(run TRANSFER sender@test.com receiver@test.com 100.00 rev-1)"
check "moved once" "900.0000" "$(q "SELECT balance FROM accounts WHERE account_id=1;")"

# --- status --------------------------------------------------------------
check_contains "status for the owner" "COMMITTED" "$(run TX_STATUS rev-1 sender@test.com)"
check_contains "status shows parties" "receiver@test.com" "$(run TX_STATUS rev-1 sender@test.com)"
check "status hidden from a stranger" "ERROR|UNKNOWN_TRANSACTION" "$(run TX_STATUS rev-1 ghost@test.com)"
check "status unknown ref" "ERROR|UNKNOWN_TRANSACTION" "$(run TX_STATUS nope sender@test.com)"

# --- reversal ------------------------------------------------------------
check "reversal is admin-only" "ERROR|FORBIDDEN" "$(run REVERSE_TRANSFER rev-1 sender@test.com)"
check "unknown ref is not reversible" "ERROR|UNKNOWN_TRANSACTION" "$(run REVERSE_TRANSFER nope "$ADM" "" "BANK_ERROR")"
check "missing reason rejected" "ERROR|INVALID_INPUT" "$(run REVERSE_TRANSFER rev-1 "$ADM")"
check "unknown reason rejected" "ERROR|INVALID_INPUT" "$(run REVERSE_TRANSFER rev-1 "$ADM" "" "BOGUS")"
check "no marker on invalid reason" "0" "$(q "SELECT COUNT(*) FROM transfer_reversals WHERE orig_ref='rev-1';")"
check "admin reverses" "SUCCESS|TRANSFER_REVERSED" "$(run REVERSE_TRANSFER rev-1 "$ADM" "" "BANK_ERROR")"
check "sender restored" "1000.0000" "$(q "SELECT balance FROM accounts WHERE account_id=1;")"
check "target clawed back" "0.0000" "$(q "SELECT balance FROM accounts WHERE account_id=2;")"
check "compensating ledger rows" "4" "$(q "SELECT COUNT(*) FROM ledger WHERE txn_ref='rev-1';")"
check "reversal audited" "1" "$(q "SELECT COUNT(*) FROM audit_trail WHERE action='REVERSE_TRANSFER' AND entity_id='rev-1';")"
check "reversal audit names the sender" "sender@test.com" "$(q "SELECT detail FROM audit_trail WHERE action='REVERSE_TRANSFER' AND entity_id='rev-1' ORDER BY audit_id DESC LIMIT 1")"
check "reversal reason recorded" "BANK_ERROR" "$(q "SELECT reason FROM transfer_reversals WHERE orig_ref='rev-1';")"
check_contains "status is now REVERSED" "REVERSED" "$(run TX_STATUS rev-1 sender@test.com)"
check "second reversal refused" "ERROR|ALREADY_REVERSED" "$(run REVERSE_TRANSFER rev-1 "$ADM" "" "BANK_ERROR")"

# --- cannot reverse when the target spent the money ----------------------
setup
run TRANSFER sender@test.com receiver@test.com 100.00 rev-2 >/dev/null
q "UPDATE accounts SET balance=0.00 WHERE account_id=2;"
check "reversal needs the target to hold funds" "ERROR|INSUFFICIENT_FUNDS" "$(run REVERSE_TRANSFER rev-2 "$ADM" "" "BANK_ERROR")"
check "failed reversal left the sender" "900.0000" "$(q "SELECT balance FROM accounts WHERE account_id=1;")"
check "failed reversal wrote no marker" "0" "$(q "SELECT COUNT(*) FROM transfer_reversals WHERE orig_ref='rev-2';")"

# Admin status is deterministic across senders and can target one.
setup
q "UPDATE accounts SET balance=1000.00 WHERE account_id=2;"
run TRANSFER sender@test.com receiver@test.com 10.00 dup-k >/dev/null
run TRANSFER receiver@test.com sender@test.com 20.00 dup-k >/dev/null
check "admin sees the newest for an ambiguous ref" "20.00" "$(run TX_STATUS dup-k "$ADM" | cut -d'|' -f6)"
check "admin filters by sender" "10.00" "$(run TX_STATUS dup-k "$ADM" sender@test.com | cut -d'|' -f6)"
check "owner still sees their own with the shared ref" "10.00" "$(run TX_STATUS dup-k sender@test.com | cut -d'|' -f6)"

# Reversal of a shared ref needs the sender, and reverses only that transfer.
check "reversal of a shared ref is ambiguous" "ERROR|AMBIGUOUS_TRANSACTION" "$(run REVERSE_TRANSFER dup-k "$ADM" "" "BANK_ERROR")"
check "reversal with the sender succeeds" "SUCCESS|TRANSFER_REVERSED" "$(run REVERSE_TRANSFER dup-k "$ADM" receiver@test.com "BANK_ERROR")"
check "the same reversal is refused" "ERROR|ALREADY_REVERSED" "$(run REVERSE_TRANSFER dup-k "$ADM" receiver@test.com "BANK_ERROR")"
check "the other sender's transfer is untouched" "COMMITTED" "$(run TX_STATUS dup-k "$ADM" sender@test.com | cut -d'|' -f3)"
check "the other sender can still be reversed" "SUCCESS|TRANSFER_REVERSED" "$(run REVERSE_TRANSFER dup-k "$ADM" sender@test.com "BANK_ERROR")"

# --- fee refund by reason (D2) ------------------------------------------------
# A transfer carrying a per-currency flat fee posts separate FEE legs; a
# BANK_ERROR reversal refunds the fee, a CUSTOMER_ERROR reversal retains it.
setup
q "DELETE FROM fee_schedule WHERE currency_id = 1;
   INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES (995,'rev_bank@test.com','x','Fee Bank','1990-01-01','VERIFIED','USER') ON DUPLICATE KEY UPDATE status='VERIFIED';
   INSERT INTO accounts (account_id,user_id,currency_id,balance,account_type) VALUES (995,995,1,0,'FEE_INCOME') ON DUPLICATE KEY UPDATE account_type='FEE_INCOME',status='ACTIVE',balance=0;
   INSERT INTO fee_schedule (currency_id, fee_amount) VALUES (1, 2.50);"
check "fee transfer" "SUCCESS|TRANSFER_OK" "$(run TRANSFER sender@test.com receiver@test.com 100.00 feeref1)"
check "fee posted to income" "2.5000" "$(q "SELECT balance FROM accounts WHERE account_id=995;")"
check "sender debited principal plus fee" "897.5000" "$(q "SELECT balance FROM accounts WHERE account_id=1;")"
check "BANK_ERROR refunds the fee" "SUCCESS|TRANSFER_REVERSED" "$(run REVERSE_TRANSFER feeref1 "$ADM" "" "BANK_ERROR")"
check "fee returned to sender" "1000.0000" "$(q "SELECT balance FROM accounts WHERE account_id=1;")"
check "fee clawed back from income" "0.0000" "$(q "SELECT balance FROM accounts WHERE account_id=995;")"
check "refund legs posted" "2" "$(q "SELECT COUNT(*) FROM ledger WHERE txn_ref='feeref1' AND description LIKE 'Fee refund%';")"
check "refund reason recorded" "BANK_ERROR" "$(q "SELECT reason FROM transfer_reversals WHERE orig_ref='feeref1';")"

setup
q "DELETE FROM fee_schedule WHERE currency_id = 1;
   INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES (995,'rev_bank@test.com','x','Fee Bank','1990-01-01','VERIFIED','USER') ON DUPLICATE KEY UPDATE status='VERIFIED';
   INSERT INTO accounts (account_id,user_id,currency_id,balance,account_type) VALUES (995,995,1,0,'FEE_INCOME') ON DUPLICATE KEY UPDATE account_type='FEE_INCOME',status='ACTIVE',balance=0;
   INSERT INTO fee_schedule (currency_id, fee_amount) VALUES (1, 2.50);"
check "fee transfer again" "SUCCESS|TRANSFER_OK" "$(run TRANSFER sender@test.com receiver@test.com 100.00 feeref2)"
check "CUSTOMER_ERROR retains the fee" "SUCCESS|TRANSFER_REVERSED" "$(run REVERSE_TRANSFER feeref2 "$ADM" "" "CUSTOMER_ERROR")"
check "principal back but fee kept" "997.5000" "$(q "SELECT balance FROM accounts WHERE account_id=1;")"
check "fee retained in income" "2.5000" "$(q "SELECT balance FROM accounts WHERE account_id=995;")"
check "no refund legs posted" "0" "$(q "SELECT COUNT(*) FROM ledger WHERE txn_ref='feeref2' AND description LIKE 'Fee refund%';")"
check "retain reason recorded" "CUSTOMER_ERROR" "$(q "SELECT reason FROM transfer_reversals WHERE orig_ref='feeref2';")"
q "DELETE FROM fee_schedule WHERE currency_id = 1; UPDATE accounts SET balance=0 WHERE account_id=995;"

# --- FX residual reversal -----------------------------------------------------
# A cross-currency posting books its rounding residual to FX_PNL; reversal
# must unwind it atomically: pinned legs, mirrored residual, balanced journal.
setup
q "DELETE FROM fee_schedule WHERE currency_id IN (1,2);
   INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES (988,'fxp_rev_bank@test.com','x','FX Bank','1990-01-01','VERIFIED','USER'),(989,'eur_rev@test.com','x','EUR Rev','1990-01-01','VERIFIED','USER') ON DUPLICATE KEY UPDATE status='VERIFIED';
   INSERT INTO accounts (account_id,user_id,currency_id,balance,account_type) VALUES (988,988,2,1000.00,'FX_PNL'),(989,989,2,0.00,'SAVINGS') ON DUPLICATE KEY UPDATE status='ACTIVE';
   UPDATE accounts SET balance=1000.00 WHERE account_id=988; UPDATE accounts SET balance=0.00 WHERE account_id=989;"
check "fx loss transfer ok" "SUCCESS|TRANSFER_OK" "$(run TRANSFER sender@test.com eur_rev@test.com 1.01 fxrev-loss)"
check "fx loss leg posted" "0.0008" "$(q "SELECT amount FROM ledger WHERE txn_ref='fxrev-loss' AND description='FX loss';")"
check "fx loss pnl debited" "999.9992" "$(q "SELECT balance FROM accounts WHERE account_id=988;")"
check "fx loss reversal ok" "SUCCESS|TRANSFER_REVERSED" "$(run REVERSE_TRANSFER fxrev-loss "$ADM" "" "BANK_ERROR")"
check "fx loss sender restored" "1000.0000" "$(q "SELECT balance FROM accounts WHERE account_id=1;")"
check "fx loss target clawed back" "0.0000" "$(q "SELECT balance FROM accounts WHERE account_id=989;")"
check "fx loss pnl restored" "1000.0000" "$(q "SELECT balance FROM accounts WHERE account_id=988;")"
check "fx loss reversal leg posted" "1" "$(q "SELECT COUNT(*) FROM ledger WHERE txn_ref='fxrev-loss' AND description='FX reversal in';")"
check "fx loss reversal leg amount" "0.0008" "$(q "SELECT amount FROM ledger WHERE txn_ref='fxrev-loss' AND description='FX reversal in';")"
check "fx loss six legs total" "6" "$(q "SELECT COUNT(*) FROM ledger WHERE txn_ref='fxrev-loss';")"

setup
q "UPDATE accounts SET balance=1000.00 WHERE account_id=988; UPDATE accounts SET balance=0.00 WHERE account_id=989;"
check "fx gain transfer ok" "SUCCESS|TRANSFER_OK" "$(run TRANSFER sender@test.com eur_rev@test.com 1.10 fxrev-gain)"
check "fx gain leg posted" "0.0020" "$(q "SELECT amount FROM ledger WHERE txn_ref='fxrev-gain' AND description='FX gain';")"
check "fx gain pnl credited" "1000.0020" "$(q "SELECT balance FROM accounts WHERE account_id=988;")"
check "fx gain reversal ok" "SUCCESS|TRANSFER_REVERSED" "$(run REVERSE_TRANSFER fxrev-gain "$ADM" "" "BANK_ERROR")"
check "fx gain sender restored" "1000.0000" "$(q "SELECT balance FROM accounts WHERE account_id=1;")"
check "fx gain target clawed back" "0.0000" "$(q "SELECT balance FROM accounts WHERE account_id=989;")"
check "fx gain pnl clawed back" "1000.0000" "$(q "SELECT balance FROM accounts WHERE account_id=988;")"
check "fx gain reversal leg posted" "1" "$(q "SELECT COUNT(*) FROM ledger WHERE txn_ref='fxrev-gain' AND description='FX reversal out';")"
check "fx gain reversal leg amount" "0.0020" "$(q "SELECT amount FROM ledger WHERE txn_ref='fxrev-gain' AND description='FX reversal out';")"
check "fx gain six legs total" "6" "$(q "SELECT COUNT(*) FROM ledger WHERE txn_ref='fxrev-gain';")"

setup
q "UPDATE accounts SET balance=1000.00 WHERE account_id=988; UPDATE accounts SET balance=0.00 WHERE account_id=989;"
check "fx underfunded transfer ok" "SUCCESS|TRANSFER_OK" "$(run TRANSFER sender@test.com eur_rev@test.com 1.10 fxrev-short)"
q "UPDATE accounts SET balance=0.00 WHERE account_id=988;"
check "underfunded fx clawback refused" "ERROR|INSUFFICIENT_FUNDS" "$(run REVERSE_TRANSFER fxrev-short "$ADM" "" "BANK_ERROR")"
check "failed reversal moved nothing" "998.9000" "$(q "SELECT balance FROM accounts WHERE account_id=1;")"
check "failed reversal kept target credit" "1.0100" "$(q "SELECT balance FROM accounts WHERE account_id=989;")"
check "failed reversal wrote no marker" "0" "$(q "SELECT COUNT(*) FROM transfer_reversals WHERE orig_ref='fxrev-short';")"
check "failed reversal wrote no legs" "0" "$(q "SELECT COUNT(*) FROM ledger WHERE txn_ref='fxrev-short' AND description IN ('Reversal in','Reversal out','FX reversal in','FX reversal out');")"

setup
q "UPDATE accounts SET balance=100.00 WHERE account_id=989;"
check "exact fx transfer ok" "SUCCESS|TRANSFER_OK" "$(run TRANSFER eur_rev@test.com receiver@test.com 92 fxrev-exact)"
check "exact posting writes no residual" "0" "$(q "SELECT COUNT(*) FROM ledger WHERE txn_ref='fxrev-exact' AND description IN ('FX gain','FX loss');")"
check "exact fx reversal ok" "SUCCESS|TRANSFER_REVERSED" "$(run REVERSE_TRANSFER fxrev-exact "$ADM" "" "BANK_ERROR")"
check "exact fx four legs total" "4" "$(q "SELECT COUNT(*) FROM ledger WHERE txn_ref='fxrev-exact';")"
check "exact fx sender restored" "100.0000" "$(q "SELECT balance FROM accounts WHERE account_id=989;")"
check "exact fx target clawed back" "0.0000" "$(q "SELECT balance FROM accounts WHERE account_id=2;")"
q "DELETE FROM ledger WHERE txn_ref LIKE 'fxrev-%'; DELETE FROM pending_transactions WHERE txn_ref LIKE 'fxrev-%'; DELETE FROM transfer_reversals WHERE orig_ref LIKE 'fxrev-%'; DELETE FROM audit_trail WHERE journal_id IN (SELECT journal_id FROM journal_entries WHERE txn_ref LIKE 'fxrev-%'); DELETE FROM journal_entries WHERE txn_ref LIKE 'fxrev-%'; DELETE FROM accounts WHERE account_id IN (988,989); DELETE FROM users WHERE id IN (988,989);"

teardown
q "UPDATE accounts SET balance=1000.00 WHERE account_id=1; UPDATE accounts SET balance=0.00 WHERE account_id=2;
   DELETE FROM ledger; DELETE FROM pending_transactions; DELETE FROM transfer_reversals;"

echo "======================================================================"
echo -e "Tests Completed: ${GREEN}${passed} passed${NC}, ${RED}${failed} failed${NC}"
echo "======================================================================"
[ "$failed" -eq 0 ]
