#!/bin/bash
# General-ledger core suite (Phase 1).
# Covers chart-of-accounts creation, balanced manual journals, trial balance,
# validation, authorization, duplicate rejection, and GL audit rows.
# Usage: ./tests/test_gl.sh

BIN="./cobol/bin/main_logic"
. ./tests/serve_harness.sh

if [ -f ./tests/.dbenv ]; then . ./tests/.dbenv; fi
DB_USER="${DB_USER:-cobol_user}"
DB_PASS="${DB_PASS:-cobol_pass}"
DB_NAME="${DB_NAME:-cobol_db}"

GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
passed=0; failed=0

q() { mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -N -B -e "$1" 2>/dev/null; }
run() { core_run "$@"; }

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

ADM="gl_admin@test.com"
USR="gl_user@test.com"

setup() {
    q "DELETE FROM gl_audit WHERE actor_email='$ADM';
       DELETE FROM gl_journal_line WHERE gl_account_code='9000' OR journal_id IN (SELECT id FROM gl_journal WHERE description LIKE 'GL test%');
       DELETE FROM gl_journal WHERE description LIKE 'GL test%';
       DELETE FROM gl_account WHERE account_code='9000';
       DELETE FROM users WHERE email IN ('$ADM','$USR');
       INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES
       (982,'$ADM','x','GL Admin','1990-01-01','VERIFIED','SUPER_ADMIN'),
       (983,'$USR','x','GL User','1990-01-01','VERIFIED','USER')
       ON DUPLICATE KEY UPDATE role=VALUES(role), status='VERIFIED';"
}

teardown() {
    q "DELETE FROM gl_audit WHERE actor_email='$ADM';
       DELETE FROM gl_journal_line WHERE gl_account_code='9000' OR journal_id IN (SELECT id FROM gl_journal WHERE description LIKE 'GL test%');
       DELETE FROM gl_journal WHERE description LIKE 'GL test%';
       DELETE FROM gl_account WHERE account_code='9000';
       DELETE FROM audit_trail WHERE action='AUTHZ_DENIED' AND actor_id=983;
       DELETE FROM users WHERE email IN ('$ADM','$USR');"
}

trap 'core_stop; teardown' EXIT
core_start

echo "======================================================================"
echo "  GENERAL LEDGER SUITE (PHASE 1)"
echo "======================================================================"
setup

check "create account" "SUCCESS|GL_ACCOUNT_CREATED" \
    "$(run GL_ACCOUNT_CREATE 9000 'Test Asset' ASSET DEBIT '' "$ADM")"
check_contains "list accounts" "1000:Cash:ASSET:DEBIT:1" \
    "$(run GL_ACCOUNT_LIST 50 0 '' '' '' "$ADM")"
check_contains "post balanced journal" "SUCCESS|GL_POSTED|" \
    "$(run GL_JOURNAL_POST 2026-10-21 'GL test journal' 5000 1000 'IDR:100.00' "$ADM")"
check_contains "trial balance is balanced" "BALANCED" \
    "$(run GL_TRIAL_BALANCE 2026-10-01 2026-10-31 IDR '' '' "$ADM")"
check_contains "trial balance debit row" "5000:Operating expense:EXPENSE:100" \
    "$(run GL_TRIAL_BALANCE 2026-10-01 2026-10-31 IDR '' '' "$ADM")"
check_contains "trial balance credit row" "1000:Cash:ASSET:0" \
    "$(run GL_TRIAL_BALANCE 2026-10-01 2026-10-31 IDR '' '' "$ADM")"
check "same account rejected" "ERROR|SAME_ACCOUNT" \
    "$(run GL_JOURNAL_POST 2026-10-21 'GL test bad' 1000 1000 'IDR:10.00' "$ADM")"
check "unknown account rejected" "ERROR|ACCOUNT_NOT_FOUND" \
    "$(run GL_JOURNAL_POST 2026-10-21 'GL test bad' 9999 1000 'IDR:10.00' "$ADM")"
check "zero amount rejected" "ERROR|INVALID_AMOUNT" \
    "$(run GL_JOURNAL_POST 2026-10-21 'GL test bad' 5000 1000 'IDR:0' "$ADM")"
check "non-admin forbidden" "ERROR|FORBIDDEN" \
    "$(run GL_ACCOUNT_LIST 50 0 '' '' '' "$USR")"
check "duplicate account rejected" "ERROR|DUPLICATE" \
    "$(run GL_ACCOUNT_CREATE 9000 'Again' ASSET DEBIT '' "$ADM")"
check "GL audit rows recorded" "2" \
    "$(q "SELECT COUNT(*) FROM gl_audit WHERE actor_email='$ADM' AND action IN ('ACCOUNT_CREATE','JOURNAL_POST');")"

echo "----------------------------------------------------------------------"
echo "PASSED: $passed  FAILED: $failed"
echo "----------------------------------------------------------------------"
[ "$failed" -eq 0 ]
