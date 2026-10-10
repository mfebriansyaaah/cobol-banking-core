#!/bin/bash

# --- Configuration ---
DB_USER="root"
DB_NAME="cobol_wallet"
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
    
    # We use printf to send each argument on a new line for the ACCEPT statements
    # We add a trailing newline to ensure the last ACCEPT is filled
    RESULT=$(printf "%s\n%s\n%s\n%s\n%s\n" "$action" "$p1" "$p2" "$p3" "$p4" | $COBOL_BIN)
    
    echo "Result: $RESULT"
    
    if [[ "$RESULT" == *"$expected"* ]]; then
        echo -e "${GREEN}PASS${NC}"
    else
        echo -e "${RED}FAIL${NC} (Expected $expected)"
    fi
}

# --- Test Setup: Fresh Data ---
echo "Setting up test data..."
echo "Febri126." | sudo -S mysql -u root -e "USE $DB_NAME; 
    DELETE FROM ledger; 
    DELETE FROM audit_trail; 
    DELETE FROM accounts; 
    DELETE FROM users; 
    INSERT INTO users (id, email, password_hash, full_name, dob, status, role) VALUES 
    (1, 'sender@test.com', 'hash', 'Sender User', '1990-01-01', 'VERIFIED', 'USER'),
    (2, 'receiver@test.com', 'hash', 'Receiver User', '1990-01-01', 'VERIFIED', 'USER');
    INSERT INTO accounts (account_id, user_id, currency_id, balance, account_type) VALUES 
    (1, 1, 1, 1000.00, 'SAVINGS'),
    (2, 2, 1, 0.00, 'SAVINGS');"

# --- Test Cases ---

# 1. Happy Path: Same Currency Transfer
run_test "Happy Path: Same Currency" "TRANSFER" "sender@test.com" "receiver@test.com" "100.00" "" "SUCCESS|TRANSFER_OK"

# 2. Insufficient Funds
run_test "Insufficient Funds" "TRANSFER" "sender@test.com" "receiver@test.com" "5000.00" "" "ERROR|INSUFFICIENT_FUNDS"

# 3. Account Not Found (Sender)
run_test "Account Not Found (Sender)" "TRANSFER" "nonexistent@test.com" "receiver@test.com" "10.00" "" "ERROR|ACCOUNT_NOT_FOUND"

# 4. Target Not Found (Receiver)
run_test "Target Not Found (Receiver)" "TRANSFER" "sender@test.com" "nonexistent@test.com" "10.00" "" "ERROR|ACCOUNT_NOT_FOUND"

# 5. Test User Core: Get User
run_test "User Core: Get User" "GET_USER" "1" "" "" "" "1|sender@test.com"

echo -e "\n======================================================================"
echo "  TEST SUITE COMPLETED"
echo "======================================================================"
