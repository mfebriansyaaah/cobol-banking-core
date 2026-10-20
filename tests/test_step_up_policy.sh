#!/bin/bash
# Customer step-up policy suite (ADR 0079): STEP_UP_REQUIRED reads the
# owner-controlled step_up_policy table. Email change and MFA disable are
# required by default; transfer is catalogued but disabled until a threshold
# is set; the comparison is exact at the threshold; unknown actions and
# disabled rows do not require a proof.
# Usage: ./tests/test_step_up_policy.sh

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

U="stepup_u@test.com"

teardown() {
    q "UPDATE step_up_policy SET min_amount=0, enabled=TRUE WHERE action='REQ_EMAIL_CHANGE';
       UPDATE step_up_policy SET min_amount=0, enabled=FALSE WHERE action='TRANSFER';
       UPDATE step_up_policy SET enabled=TRUE WHERE action='MFA_DISABLE';
       DELETE FROM users WHERE email='$U';"
}
trap teardown EXIT

echo "======================================================================"
echo "  CUSTOMER STEP-UP POLICY SUITE"
echo "======================================================================"

q "DELETE FROM users WHERE email='$U';
   INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES
   (2021,'$U',CONCAT('SHA256_',SHA2('secret123',256)),'Step Up','1990-01-01','VERIFIED','USER');"
# Baseline: the seeded policy is intact even if another suite ran before.
q "UPDATE step_up_policy SET min_amount=0, enabled=TRUE WHERE action='REQ_EMAIL_CHANGE';
   UPDATE step_up_policy SET enabled=TRUE WHERE action='MFA_DISABLE';
   UPDATE step_up_policy SET min_amount=0, enabled=FALSE WHERE action='TRANSFER';"

# --- the seeded policy -------------------------------------------------------------
check "email change requires a step-up" "SUCCESS|STEP_UP_REQUIRED" \
    "$(run STEP_UP_REQUIRED "$U" REQ_EMAIL_CHANGE "")"
check "MFA disable requires a step-up" "SUCCESS|STEP_UP_REQUIRED" \
    "$(run STEP_UP_REQUIRED "$U" MFA_DISABLE "")"
check "transfer is not required while disabled" "SUCCESS|STEP_UP_NOT_REQUIRED" \
    "$(run STEP_UP_REQUIRED "$U" TRANSFER 100000.00)"
check "an uncatalogued action is not required" "SUCCESS|STEP_UP_NOT_REQUIRED" \
    "$(run STEP_UP_REQUIRED "$U" CHECK_BALANCE "")"
check "an unknown account is refused" "ERROR|ACCOUNT_NOT_FOUND" \
    "$(run STEP_UP_REQUIRED ghost@test.com REQ_EMAIL_CHANGE "")"
check "an absent amount on a required action is still required" "SUCCESS|STEP_UP_REQUIRED" \
    "$(run STEP_UP_REQUIRED "$U" MFA_DISABLE "")"

# --- the threshold is exact --------------------------------------------------------
q "UPDATE step_up_policy SET min_amount=500, enabled=TRUE WHERE action='TRANSFER';"
check "below the threshold is not required" "SUCCESS|STEP_UP_NOT_REQUIRED" \
    "$(run STEP_UP_REQUIRED "$U" TRANSFER 499.99)"
check "at the threshold is required" "SUCCESS|STEP_UP_REQUIRED" \
    "$(run STEP_UP_REQUIRED "$U" TRANSFER 500)"
check "above the threshold is required" "SUCCESS|STEP_UP_REQUIRED" \
    "$(run STEP_UP_REQUIRED "$U" TRANSFER 1000.00)"
check "a disabled action ignores its threshold" "SUCCESS|STEP_UP_NOT_REQUIRED" \
    "$(q "UPDATE step_up_policy SET enabled=FALSE WHERE action='TRANSFER';"; run STEP_UP_REQUIRED "$U" TRANSFER 100000.00)"

# --- the policy is data ------------------------------------------------------------
q "UPDATE step_up_policy SET enabled=FALSE WHERE action='REQ_EMAIL_CHANGE';"
check "disabling the policy drops the requirement" "SUCCESS|STEP_UP_NOT_REQUIRED" \
    "$(run STEP_UP_REQUIRED "$U" REQ_EMAIL_CHANGE "")"
q "UPDATE step_up_policy SET enabled=TRUE WHERE action='REQ_EMAIL_CHANGE';"
check "re-enabling restores the requirement" "SUCCESS|STEP_UP_REQUIRED" \
    "$(run STEP_UP_REQUIRED "$U" REQ_EMAIL_CHANGE "")"

# --- amount formats the gateway validates ------------------------------------------
check "a decimal amount is compared exactly" "SUCCESS|STEP_UP_REQUIRED" \
    "$(q "UPDATE step_up_policy SET min_amount=0.01, enabled=TRUE WHERE action='TRANSFER';"; run STEP_UP_REQUIRED "$U" TRANSFER 0.01)"
check "a zero amount is below a positive threshold" "SUCCESS|STEP_UP_NOT_REQUIRED" \
    "$(run STEP_UP_REQUIRED "$U" TRANSFER 0)"

echo "======================================================================"
echo -e "Tests Completed: ${GREEN}${passed} passed${NC}, ${RED}${failed} failed${NC}"
echo "======================================================================"
[ "$failed" -eq 0 ]
