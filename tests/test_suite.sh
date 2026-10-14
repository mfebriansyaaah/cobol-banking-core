#!/bin/bash
# Comprehensive Test Suite for COBOL Banking Core

BIN="./cobol/bin/main_logic"

# Load DB credentials override (tests/.dbenv is gitignored)
if [ -f ./tests/.dbenv ]; then
    . ./tests/.dbenv
fi
DB_USER="${DB_USER:-cobol_user}"
DB_PASS="${DB_PASS:-cobol_pass}"
DB_NAME="${DB_NAME:-cobol_db}"

# Reset seed data so tests are order-independent
reset_test_db() {
    mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "
        UPDATE accounts SET balance=1000.00 WHERE account_id=1;
        UPDATE accounts SET balance=0.00 WHERE account_id=2;
        DELETE FROM ledger WHERE txn_ref NOT LIKE 'INIT_%';
        INSERT INTO users (id,email,password_hash,full_name,dob,status,role)
        VALUES (3,'admin@test.com','hash3','Admin User','1990-01-03','VERIFIED','SUPER_ADMIN')
        ON DUPLICATE KEY UPDATE role='SUPER_ADMIN', status='VERIFIED';" >/dev/null 2>&1
}
ADMIN="admin@test.com"
reset_test_db

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

passed=0
failed=0

assert_output() {
    local action=$1
    local p1=$2
    local p2=$3
    local p3=$4
    local p4=$5
    local expected=$6
    reset_test_db
    local test_name=$7

    # Run the binary using file-based I/O
    printf "%s|%s|%s|%s|%s\n" "$action" "$p1" "$p2" "$p3" "$p4" > input.txt
    $BIN
    output=$(cat output.txt | tr -d ' ')

    if [[ "$output" == *"$expected"* ]]; then
        echo -e "${GREEN}[PASS]${NC} $test_name"
        ((passed++))
    else
        echo -e "${RED}[FAIL]${NC} $test_name"
        echo "  Expected: $expected"
        echo "  Actual:   $output"
        ((failed++))
    fi
}

echo "Running Banking Core Test Suite..."
echo "=========================================="

# --- Unit Tests: Basic Input Validation ---
assert_output "" "" "" "" "" "ERROR|MISSING_ACTION" "Missing action should error"
assert_output "INVALID_OP" "" "" "" "" "ERROR|INVALID_ACTION" "Invalid action should error"

# --- Feature Tests: GET_USER ---
assert_output "GET_USER" "sender@test.com" "$ADMIN" "" "" "1|sender@test.com" "Get existing user (sender)"
assert_output "GET_USER" "receiver@test.com" "$ADMIN" "" "" "2|receiver@test.com" "Get existing user (receiver)"
assert_output "GET_USER" "unknown@test.com" "$ADMIN" "" "" "ERROR|NOT_FOUND" "Get non-existent user"
assert_output "GET_USER" "sender@test.com" "receiver@test.com" "" "" "ERROR|FORBIDDEN" "Get another user's record is forbidden"

# --- Feature Tests: LIST_USERS ---
assert_output "LIST_USERS" "" "" "$ADMIN" "" "SUCCESS|LIST_DONE" "List users success (admin)"
assert_output "LIST_USERS" "" "" "sender@test.com" "" "ERROR|FORBIDDEN" "List users forbidden for non-admin"

# --- Feature Tests: CHECK_BALANCE ---
assert_output "CHECK_BALANCE" "sender@test.com" "$ADMIN" "" "" "SUCCESS|BALANCES|USD:1000.00:ACTIVE" "Check balance for sender"
assert_output "CHECK_BALANCE" "receiver@test.com" "$ADMIN" "" "" "SUCCESS|BALANCES|USD:0.00:ACTIVE" "Check balance for receiver"
assert_output "CHECK_BALANCE" "unknown@test.com" "$ADMIN" "" "" "ERROR|ACCOUNT_NOT_FOUND" "Check balance for unknown user"
assert_output "CHECK_BALANCE" "sender@test.com" "receiver@test.com" "" "" "ERROR|FORBIDDEN" "Check another user's balance is forbidden"

# --- Feature Tests: TRANSFER ---
# Test 1: Valid Transfer
assert_output "TRANSFER" "sender@test.com" "receiver@test.com" "100.00" "" "SUCCESS|TRANSFER_OK" "Valid transfer sender to receiver"

# Test 2: Insufficient Funds
# Since the binary restarts every time (SIM DB), we can test this independently
assert_output "TRANSFER" "receiver@test.com" "sender@test.com" "100.00" "" "ERROR|INSUFFICIENT_FUNDS" "Transfer with insufficient funds"

# Test 3: Target not found
assert_output "TRANSFER" "sender@test.com" "unknown@test.com" "100.00" "" "ERROR|TARGET_NOT_FOUND" "Transfer to unknown target"

# Test 4: Sender not found
assert_output "TRANSFER" "unknown@test.com" "receiver@test.com" "100.00" "" "ERROR|ACCOUNT_NOT_FOUND" "Transfer from unknown sender"

echo "=========================================="
echo -e "Tests Completed: ${GREEN}$passed passed${NC}, ${RED}$failed failed${NC}"

if [ $failed -ne 0 ]; then
    exit 1
fi
