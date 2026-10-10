#!/bin/bash

# --- Configuration ---
# Load DB credentials override (tests/.dbenv is gitignored)
if [ -f ./tests/.dbenv ]; then
    . ./tests/.dbenv
fi
DB_USER="${DB_USER:-cobol_user}"
DB_PASS="${DB_PASS:-cobol_pass}"
DB_NAME="${DB_NAME:-cobol_db}"
COBOL_BIN="./cobol/bin/main_logic"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo "======================================================================"
echo "  CORE BANKING - ATOMIC TRANSACTION INTEGRATION TEST SUITE"
echo "======================================================================"

# Function to run a test case
run_test() {
    local name="$1"
    local action="$2"
    local p1="$3"
    local p2="$4"
    local p3="$5"
    local p4="$6"
    local expected="$7"

    echo -e "\nTesting: $name"
    echo "Action: $action | Params: $p1, $p2, $p3, $p4"
    
    # Main logic reads pipe-delimited input from input.txt and writes output.txt
    printf "%s|%s|%s|%s|%s\n" "$action" "$p1" "$p2" "$p3" "$p4" > input.txt
    $COBOL_BIN >/dev/null 2>&1
    RESULT=$(cat output.txt)
    
    echo "Result: $RESULT"
    
    if [[ "$RESULT" == *"$expected"* ]]; then
        echo -e "${GREEN}PASS${NC}"
    else
        echo -e "${RED}FAIL${NC} (Expected $expected)"
    fi
}

# --- Test Setup: Fresh Data ---
echo "Setting up test data..."
mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "USE $DB_NAME; 
    DELETE FROM ledger; 
    DELETE FROM audit_trail; 
    DELETE FROM accounts; 
    DELETE FROM users; 
    INSERT INTO users (id, email, password_hash, full_name, dob, status, role) VALUES 
    (1, 'sender@test.com', 'hash', 'Sender User', '1990-01-01', 'VERIFIED', 'USER'),
    (2, 'receiver@test.com', 'hash', 'Receiver User', '1990-01-01', 'VERIFIED', 'USER');
    INSERT INTO accounts (account_id, user_id, currency_id, balance, account_type) VALUES 
    (1, 1, 1, 1000.00, 'SAVINGS'),
    (2, 2, 1, 0.00, 'SAVINGS');
    INSERT INTO ledger (txn_ref, account_id, amount, type, currency_id, description) VALUES 
    ('INIT_001', 1, 1000.00, 'CREDIT', 1, 'Initial Deposit'),
    ('INIT_002', 2, 0.00, 'CREDIT', 1, 'Initial Deposit');"

# --- Test Cases ---

# 1. Happy Path: Same Currency Transfer
run_test "Happy Path: Same Currency" "TRANSFER" "sender@test.com" "receiver@test.com" "100.00" "" "SUCCESS|TRANSFER_OK"

# 2. Insufficient Funds
run_test "Insufficient Funds" "TRANSFER" "sender@test.com" "receiver@test.com" "5000.00" "" "ERROR|INSUFFICIENT_FUNDS"

# 3. Account Not Found (Sender)
run_test "Account Not Found (Sender)" "TRANSFER" "nonexistent@test.com" "receiver@test.com" "10.00" "" "ERROR|ACCOUNT_NOT_FOUND"

# 4. Target Not Found (Receiver)
run_test "Target Not Found (Receiver)" "TRANSFER" "sender@test.com" "nonexistent@test.com" "10.00" "" "ERROR|TARGET_NOT_FOUND"

# 5. Test User Core: Get User by Email
run_test "User Core: Get User" "GET_USER" "sender@test.com" "" "" "" "1|sender@test.com"

echo -e "\n======================================================================"
echo "  TEST SUITE COMPLETED"
echo "======================================================================"
