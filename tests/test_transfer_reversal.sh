#!/bin/bash
# Transfer reversal + status suite: a SUPER_ADMIN can reverse a transfer once
# (compensating ledger entries, balances restored), reversing again is refused,
# and TRANSFER_STATUS reports COMMITTED/REVERSED to the sender or an admin only.
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
check_contains "status for the owner" "COMMITTED" "$(run TRANSFER_STATUS rev-1 sender@test.com)"
check_contains "status shows parties" "receiver@test.com" "$(run TRANSFER_STATUS rev-1 sender@test.com)"
check "status hidden from a stranger" "ERROR|UNKNOWN_TRANSACTION" "$(run TRANSFER_STATUS rev-1 ghost@test.com)"
check "status unknown ref" "ERROR|UNKNOWN_TRANSACTION" "$(run TRANSFER_STATUS nope sender@test.com)"

# --- reversal ------------------------------------------------------------
check "reversal is admin-only" "ERROR|FORBIDDEN" "$(run REVERSE_TRANSFER rev-1 sender@test.com)"
check "unknown ref is not reversible" "ERROR|UNKNOWN_TRANSACTION" "$(run REVERSE_TRANSFER nope "$ADM")"
check "admin reverses" "SUCCESS|TRANSFER_REVERSED" "$(run REVERSE_TRANSFER rev-1 "$ADM")"
check "sender restored" "1000.0000" "$(q "SELECT balance FROM accounts WHERE account_id=1;")"
check "target clawed back" "0.0000" "$(q "SELECT balance FROM accounts WHERE account_id=2;")"
check "compensating ledger rows" "4" "$(q "SELECT COUNT(*) FROM ledger WHERE txn_ref='rev-1';")"
check "reversal audited" "1" "$(q "SELECT COUNT(*) FROM audit_trail WHERE action='REVERSE_TRANSFER';")"
check_contains "status is now REVERSED" "REVERSED" "$(run TRANSFER_STATUS rev-1 sender@test.com)"
check "second reversal refused" "ERROR|ALREADY_REVERSED" "$(run REVERSE_TRANSFER rev-1 "$ADM")"

# --- cannot reverse when the target spent the money ----------------------
setup
run TRANSFER sender@test.com receiver@test.com 100.00 rev-2 >/dev/null
q "UPDATE accounts SET balance=0.00 WHERE account_id=2;"
check "reversal needs the target to hold funds" "ERROR|INSUFFICIENT_FUNDS" "$(run REVERSE_TRANSFER rev-2 "$ADM")"
check "failed reversal left the sender" "900.0000" "$(q "SELECT balance FROM accounts WHERE account_id=1;")"
check "failed reversal wrote no marker" "0" "$(q "SELECT COUNT(*) FROM transfer_reversals WHERE orig_ref='rev-2';")"

teardown
q "UPDATE accounts SET balance=1000.00 WHERE account_id=1; UPDATE accounts SET balance=0.00 WHERE account_id=2;
   DELETE FROM ledger; DELETE FROM pending_transactions; DELETE FROM transfer_reversals;"

echo "======================================================================"
echo -e "Tests Completed: ${GREEN}${passed} passed${NC}, ${RED}${failed} failed${NC}"
echo "======================================================================"
[ "$failed" -eq 0 ]
