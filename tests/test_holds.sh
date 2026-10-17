#!/bin/bash
# Holds and fees suite: PLACE_HOLD/RELEASE_HOLD lifecycle, spendable
# (available) balance enforcement in transfers and balances, lazy expiry,
# and scheduled per-currency fees as separate journals. Fee amounts and
# hold policy live in bank-owned data (Gate 0); the core only applies them.
# Usage: ./tests/test_holds.sh

BIN="./cobol/bin/main_logic"

if [ -f ./tests/.dbenv ]; then . ./tests/.dbenv; fi
DB_USER="${DB_USER:-cobol_user}"
DB_PASS="${DB_PASS:-cobol_pass}"
DB_NAME="${DB_NAME:-cobol_db}"

GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
passed=0; failed=0

q() { mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -N -B -e "$1" 2>/dev/null; }

run() {
    printf "%s|%s|%s|%s|%s|%s|%s\n" "$1" "$2" "$3" "$4" "$5" "$6" "$7" > input.txt
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

ADM="h_adm@test.com"
setup() {
    q "DELETE FROM account_holds WHERE hold_id > 0;
       DELETE FROM accounts WHERE account_id IN (991,992,993);
       DELETE FROM users WHERE email IN ('h_a@test.com','h_b@test.com','h_fx@test.com','$ADM');
       DELETE FROM fee_schedule WHERE currency_id = 1;
       INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES
       (991,'h_a@test.com','x','Hold A','1990-01-01','VERIFIED','USER'),
       (992,'h_b@test.com','x','Hold B','1990-01-01','VERIFIED','USER'),
       (993,'h_fx@test.com','x','Hold FX','1990-01-01','VERIFIED','USER'),
       (994,'$ADM','x','Hold Admin','1990-01-01','VERIFIED','SUPER_ADMIN');
       INSERT INTO accounts (account_id,user_id,currency_id,balance,account_type) VALUES
       (991,991,1,100000,'SAVINGS'),
       (992,992,1,0,'SAVINGS'),
       (993,993,3,50000,'SAVINGS');
       DELETE FROM ledger; DELETE FROM pending_transactions;"
}

teardown() {
    q "DELETE FROM account_holds WHERE hold_id > 0;
       DELETE FROM ledger WHERE account_id IN (991,992,993,995);
       DELETE FROM pending_transactions WHERE from_email LIKE 'h_%@test.com' OR to_email LIKE 'h_%@test.com';
       DELETE FROM transfer_reversals WHERE from_email LIKE 'h_%@test.com';
       DELETE FROM audit_trail WHERE action IN ('PLACE_HOLD','RELEASE_HOLD','FEE');
       DELETE FROM audit_trail WHERE detail LIKE 'h_b@test.com%' OR detail LIKE '%h_fx@test.com%' OR detail LIKE '%:IDR';
       DELETE FROM journal_entries WHERE actor_email LIKE 'h_%@test.com';
       DELETE FROM fee_schedule WHERE currency_id IN (1,3);
       DELETE FROM accounts WHERE account_id IN (991,992,993,995);
       DELETE FROM users WHERE id IN (991,992,993,994,995);"
}
trap teardown EXIT

echo "======================================================================"
echo "  HOLDS AND FEES SUITE"
echo "======================================================================"

setup

# --- place / release lifecycle ----------------------------------------------
HOLD_OUT="$(run PLACE_HOLD h_a@test.com 20000.00 $ADM "" "" "review hold")"
check_contains "hold placed" "SUCCESS|HOLD_PLACED|" "$HOLD_OUT"
HOLD_ID="${HOLD_OUT##*|}"
check "hold row is PLACED" "PLACED|20000.0000|$ADM" "$(q "SELECT CONCAT(state, '|', amount, '|', actor_email) FROM account_holds WHERE hold_id='$HOLD_ID';")"
check "place is audited" "1" "$(q "SELECT COUNT(*) FROM audit_trail WHERE action='PLACE_HOLD' AND entity_id='991' AND actor_id=(SELECT id FROM users WHERE email='$ADM');")"
check "non-admin cannot place" "ERROR|FORBIDDEN" "$(run PLACE_HOLD h_a@test.com 1.00 h_b@test.com "" "" "")"
check "unknown owner" "ERROR|ACCOUNT_NOT_FOUND" "$(run PLACE_HOLD ghost@test.com 1.00 $ADM "" "" "")"
check "malformed amount" "ERROR|INVALID_AMOUNT" "$(run PLACE_HOLD h_a@test.com abc $ADM "" "" "")"
check "too many decimals for IDR" "ERROR|INVALID_AMOUNT" "$(run PLACE_HOLD h_fx@test.com 10.50 $ADM "" "IDR" "")"
check "bad expiry" "ERROR|INVALID_INPUT" "$(run PLACE_HOLD h_a@test.com 1.00 $ADM 3x "" "")"
check "bad hold id" "ERROR|INVALID_INPUT" "$(run RELEASE_HOLD abc $ADM)"
check "release by non-admin forbidden" "ERROR|FORBIDDEN" "$(run RELEASE_HOLD "$HOLD_ID" h_b@test.com)"
check "release ok" "SUCCESS|HOLD_RELEASED" "$(run RELEASE_HOLD "$HOLD_ID" $ADM)"
check "hold row is RELEASED" "RELEASED" "$(q "SELECT state FROM account_holds WHERE hold_id='$HOLD_ID';")"
check "released hold cannot be released again" "ERROR|UNKNOWN_TRANSACTION" "$(run RELEASE_HOLD "$HOLD_ID" $ADM)"
check "unknown hold" "ERROR|UNKNOWN_TRANSACTION" "$(run RELEASE_HOLD 999999 $ADM)"

# --- holds reduce the spendable balance ---------------------------------------
HOLD2="$(run PLACE_HOLD h_a@test.com 20000.00 $ADM "" "" "")"
check "second hold placed" "SUCCESS" "$(echo "$HOLD2" | cut -d'|' -f1)"
check "balance shows hold as unavailable" "SUCCESS|BALANCES|USD:100000.00:80000.00:ACTIVE" "$(run CHECK_BALANCE h_a@test.com h_a@test.com)"
check "transfer over available is refused" "ERROR|INSUFFICIENT_FUNDS" "$(run TRANSFER h_a@test.com h_b@test.com 80000.01 hav1)"
check "refused transfer moved nothing" "100000.0000" "$(q "SELECT balance FROM accounts WHERE account_id=991;")"
check "transfer within available moves" "SUCCESS|TRANSFER_OK" "$(run TRANSFER h_a@test.com h_b@test.com 80000.00 hav2)"
check "hold survives the transfer" "20000.0000" "$(q "SELECT balance FROM accounts WHERE account_id=991;")"
teardown
setup

# --- expired holds are ignored (lazy expiry) -----------------------------------
q "INSERT INTO account_holds (account_id, amount, state, reason, actor_email, expires_at) VALUES (991, 60000, 'PLACED', 'stale', '$ADM', DATE_SUB(NOW(), INTERVAL 1 DAY));"
check "expired hold is ignored" "SUCCESS|TRANSFER_OK" "$(run TRANSFER h_a@test.com h_b@test.com 100000.00 hexp)"
check "expired hold is marked EXPIRED" "EXPIRED" "$(q "SELECT state FROM account_holds WHERE reason='stale';")"
teardown
setup

# --- multi-account owners pin the currency --------------------------------------
q "INSERT INTO accounts (account_id,user_id,currency_id,balance,account_type) VALUES (995,991,2,0,'SAVINGS');"
check "ambiguous without a pin" "ERROR|AMBIGUOUS_ACCOUNT" "$(run PLACE_HOLD h_a@test.com 1.00 $ADM "" "" "")"
check "pinned hold works" "SUCCESS" "$(run PLACE_HOLD h_a@test.com 1.00 $ADM "" USD "" | cut -d'|' -f1)"
q "DELETE FROM account_holds WHERE account_id=995; DELETE FROM accounts WHERE account_id=995;"

# --- scheduled fee posts as its own journal --------------------------------------
q "UPDATE accounts SET balance=0 WHERE account_id IN (991,992,995);
   DELETE FROM ledger WHERE account_id IN (991,992,995);
   INSERT INTO ledger (txn_ref,account_id,amount,type,currency_id,description) VALUES ('HOLD_INIT',991,100000,'CREDIT',1,'Hold suite opening');
   INSERT INTO ledger (txn_ref,account_id,amount,type,currency_id,description) VALUES ('HOLD_INIT',993,50000,'CREDIT',3,'Hold suite opening');
   UPDATE accounts SET balance=100000 WHERE account_id=991;
   INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES (995,'h_bank@test.com','x','Fee Bank','1990-01-01','VERIFIED','USER') ON DUPLICATE KEY UPDATE status='VERIFIED';
   INSERT INTO accounts (account_id,user_id,currency_id,balance,account_type) VALUES (995,995,1,0,'FEE_INCOME') ON DUPLICATE KEY UPDATE account_type='FEE_INCOME',status='ACTIVE';
   INSERT INTO fee_schedule (currency_id, fee_amount) VALUES (1, 2.50);"
check "fee transfer ok" "SUCCESS|TRANSFER_OK" "$(run TRANSFER h_a@test.com h_b@test.com 100.00 hfee)"
check "fee journal posted" "FEE" "$(q "SELECT source FROM journal_entries WHERE txn_ref='hfee' AND source='FEE';")"
check "fee legs exact" "2.5000|2.5000" "$(q "SELECT CONCAT((SELECT amount FROM ledger WHERE txn_ref='hfee' AND type='DEBIT' AND description='Fee out'), '|', (SELECT amount FROM ledger WHERE txn_ref='hfee' AND type='CREDIT' AND description='Fee in'));")"
check "fee reaches the income account" "2.5000" "$(q "SELECT balance FROM accounts WHERE account_id=995;")"
check "sender paid principal plus fee" "99897.5000" "$(q "SELECT balance FROM accounts WHERE account_id=991;")"
check "fee is audited" "1" "$(q "SELECT COUNT(*) FROM audit_trail WHERE action='FEE' AND detail LIKE '2.5000%' AND journal_id IS NOT NULL;")"
check "reconciliation flags none of the suite accounts" "" "$(run RECONCILE $ADM | grep -oE '99[1235]\|' | tr -d '\n')"
check "no over-held account" "0" "$(q "SELECT COUNT(*) FROM (SELECT a.account_id, a.balance - COALESCE((SELECT SUM(h.amount) FROM account_holds h WHERE h.account_id = a.account_id AND h.state='PLACED' AND (h.expires_at IS NULL OR h.expires_at > NOW())),0) AS avail FROM accounts a) t WHERE t.avail < 0;")"

echo "======================================================================"
echo "Tests Completed: ${GREEN}${passed} passed${NC}, ${RED}${failed} failed${NC}"
echo "======================================================================"
[ "$failed" -eq 0 ]
