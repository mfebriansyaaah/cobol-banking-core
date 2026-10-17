#!/bin/bash
# Statement suite: read-only per-account statements with opening/closing
# balances, one row per posting (posting/value dates, ref, source, side,
# amount, balance after the row, reversal flag, description), date-range
# filter, paging, and owner-or-admin visibility.
# Usage: ./tests/test_statements.sh
#
# Fixture ids 975-978 are reserved for this suite (see teardown).

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

U=stmt_u@test.com; O=stmt_o@test.com; A=stmt_a@test.com
setup() {
    q "DELETE FROM ledger WHERE account_id IN (975,976,978);
       DELETE FROM pending_transactions WHERE txn_ref LIKE 'STMT%';
       DELETE FROM transfer_reversals WHERE orig_ref LIKE 'STMT%';
       DELETE FROM journal_entries WHERE txn_ref LIKE 'STMT%' AND journal_id NOT IN (SELECT journal_id FROM ledger WHERE journal_id IS NOT NULL);
       DELETE FROM accounts WHERE account_id IN (975,976,978);
       DELETE FROM users WHERE email IN ('$U','$O','$A');
       DELETE FROM fee_schedule WHERE currency_id = 1;
       INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES
       (975,'$U','x','Stmt User','1990-01-01','VERIFIED','USER'),
       (976,'$O','x','Stmt Other','1990-01-01','VERIFIED','USER'),
       (977,'$A','x','Stmt Admin','1990-01-01','VERIFIED','SUPER_ADMIN');
       INSERT INTO accounts (account_id,user_id,currency_id,balance,account_type) VALUES
       (975,975,1,0,'SAVINGS'),
       (976,976,1,0,'SAVINGS'),
       (978,977,1,0,'FEE_INCOME');
       INSERT INTO fee_schedule (currency_id, fee_amount) VALUES (1, 2.50);"
}

teardown() {
    q "DELETE FROM ledger WHERE account_id IN (975,976,978);
       DELETE FROM pending_transactions WHERE txn_ref LIKE 'STMT%';
       DELETE FROM transfer_reversals WHERE orig_ref LIKE 'STMT%';
       DELETE FROM journal_entries WHERE txn_ref LIKE 'STMT%';
       DELETE FROM accounts WHERE account_id IN (975,976,978);
       DELETE FROM users WHERE email IN ('$U','$O','$A');
       DELETE FROM fee_schedule WHERE currency_id = 1;"
}
trap teardown EXIT

echo "======================================================================"
echo "  STATEMENTS SUITE"
echo "======================================================================"

setup

# --- authorization and input validation -----------------------------------------
check "non-owner non-admin is refused" "ERROR|FORBIDDEN" "$(run STATEMENT $U $O USD , 50 0)"
check "missing currency is refused" "ERROR|INVALID_INPUT" "$(run STATEMENT $U $U '' , 50 0)"
check "bad range shape is refused" "ERROR|INVALID_INPUT" "$(run STATEMENT $U $U USD zzz 50 0)"
check "inverted range is refused" "ERROR|INVALID_INPUT" "$(run STATEMENT $U $U USD 2026-10-18,2026-10-17 50 0)"
check "non-numeric limit is refused" "ERROR|INVALID_INPUT" "$(run STATEMENT $U $U USD , abc 0)"
check "unknown currency has no account" "ERROR|ACCOUNT_NOT_FOUND" "$(run STATEMENT $U $U XXX , 50 0)"

# --- activity: funding, a fee-bearing transfer, and its reversal ------------------
q "INSERT INTO ledger (txn_ref,account_id,amount,type,currency_id,description) VALUES ('STMT_FUND',975,1000,'CREDIT',1,'Suite funding');
   UPDATE accounts SET balance=1000 WHERE account_id=975;"
check "transfer ok" "SUCCESS|TRANSFER_OK" "$(run TRANSFER $U $O 100.00 STMT001)"
check "reversal ok" "SUCCESS|TRANSFER_REVERSED" "$(run REVERSE_TRANSFER STMT001 $A $U)"

STMT="$(run STATEMENT $U $U USD , 50 0)"
check "statement ok" "SUCCESS|STATEMENT" "$(echo "$STMT" | cut -d'|' -f1-2 | cut -d'|' -f1-2)"
check "opening balance" "0.00" "$(echo "$STMT" | cut -d'|' -f3)"
check "closing balance" "997.50" "$(echo "$STMT" | cut -d'|' -f4)"
check "currency pinned" "USD" "$(echo "$STMT" | cut -d'|' -f5)"
check "four rows" "4" "$(echo "$STMT" | cut -d'|' -f6)"
check "funding leg present" "STMT_FUND:TRANSFER:CREDIT:1000.00:1000.00:0" "$(echo "$STMT" | cut -d'|' -f7 | tr ';' '\n' | grep STMT_FUND | cut -d':' -f4-9)"
check "principal leg flagged reversed" "STMT001:TRANSFER:DEBIT:100.00:900.00:1" "$(echo "$STMT" | cut -d'|' -f7 | tr ';' '\n' | grep 'Transfer out' | cut -d':' -f4-9)"
check "fee leg posted" "STMT001:FEE:DEBIT:2.50:897.50:1" "$(echo "$STMT" | cut -d'|' -f7 | tr ';' '\n' | grep 'Fee out' | cut -d':' -f4-9)"
check "reversal leg posted" "STMT001:REVERSAL:CREDIT:100.00:997.50:1" "$(echo "$STMT" | cut -d'|' -f7 | tr ';' '\n' | grep 'Reversal in' | cut -d':' -f4-9)"
check "last balance equals closing" "997.50" "$(echo "$STMT" | cut -d'|' -f7 | tr ';' '\n' | tail -1 | cut -d':' -f8)"

# --- counterparty sees only their own side -----------------------------------------
OSTMT="$(run STATEMENT $O $O USD , 50 0)"
check "counterparty closing is zero after clawback" "0.00" "$(echo "$OSTMT" | cut -d'|' -f4)"
check "counterparty has the credit" "STMT001:TRANSFER:CREDIT:100.00:100.00:1" "$(echo "$OSTMT" | cut -d'|' -f7 | tr ';' '\n' | grep 'Transfer in' | cut -d':' -f4-9)"

# --- admins may read, strangers may not ----------------------------------------------
check "admin may read" "997.50" "$(run STATEMENT $U $A USD , 50 0 | cut -d'|' -f4)"

# --- date ranges ------------------------------------------------------------------------
check "future range is empty" "SUCCESS|STATEMENT|997.50|997.50|USD|0" "$(run STATEMENT $U $U USD 2099-01-01,2099-12-31 50 0)"
check "open-ended from works" "4" "$(run STATEMENT $U $U USD 2020-01-01, 50 0 | cut -d'|' -f6)"
check "open-ended to works" "4" "$(run STATEMENT $U $U USD ,2026-12-31 50 0 | cut -d'|' -f6)"

# --- paging ---------------------------------------------------------------------------------
check "limit slices rows" "2" "$(run STATEMENT $U $U USD , 2 0 | cut -d'|' -f7 | tr ';' '\n' | wc -l | tr -d ' ')"
check "total ignores paging" "4" "$(run STATEMENT $U $U USD , 2 0 | cut -d'|' -f6)"
check "offset skips rows" "FEE" "$(run STATEMENT $U $U USD , 2 2 | cut -d'|' -f7 | cut -d':' -f5)"
check "page ends with the reversal" "REVERSAL" "$(run STATEMENT $U $U USD , 2 2 | cut -d'|' -f7 | tr ';' '\n' | tail -1 | cut -d':' -f5)"
check "offset past the end is empty" "SUCCESS|STATEMENT|0.00|997.50|USD|4" "$(run STATEMENT $U $U USD , 50 99)"

echo "======================================================================"
echo "Tests Completed: ${GREEN}${passed} passed${NC}, ${RED}${failed} failed${NC}"
echo "======================================================================"
[ "$failed" -eq 0 ]
