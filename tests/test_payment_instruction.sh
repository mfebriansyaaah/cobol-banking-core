#!/bin/bash
# Standing payment instructions (Phase 1, Sprint 1 slice 13).
BIN="./cobol/bin/main_logic"
. ./tests/serve_harness.sh
if [ -f ./tests/.dbenv ]; then . ./tests/.dbenv; fi
DB_USER="${DB_USER:-cobol_user}"; DB_PASS="${DB_PASS:-cobol_pass}"; DB_NAME="${DB_NAME:-cobol_db}"
GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'; passed=0; failed=0
q() { mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -N -B -e "$1" 2>/dev/null; }
run() { core_run "$@"; }
check() { local n="$1" e="$2" a="$3"; if [ "$a" = "$e" ]; then echo -e "${GREEN}PASS${NC} $n"; passed=$((passed+1)); else echo -e "${RED}FAIL${NC} $n (expected [$e] got [$a])"; failed=$((failed+1)); fi; }
check_contains() { local n="$1" x="$2" a="$3"; if [[ "$a" == *"$x"* ]]; then echo -e "${GREEN}PASS${NC} $n"; passed=$((passed+1)); else echo -e "${RED}FAIL${NC} $n (expected [$x] got [$a])"; failed=$((failed+1)); fi; }
ADM="pi_admin@test.com"; SENDER="pi_sender@test.com"; RECV="pi_recv@test.com"; TODAY="$(date +%F)"; TOMORROW="$(date -d tomorrow +%F)"
cleanup() {
    q "DELETE FROM payment_instruction_run WHERE instruction_id IN (SELECT id FROM payment_instruction WHERE instruction_code LIKE 'PITEST%');
       DELETE FROM payment_instruction WHERE instruction_code LIKE 'PITEST%';
       DELETE FROM payment_audit WHERE actor_email IN ('$ADM','$SENDER');
       DELETE FROM ledger WHERE account_id IN (SELECT account_id FROM accounts WHERE user_id IN (SELECT id FROM users WHERE email IN ('$SENDER','$RECV')));
       DELETE FROM pending_transactions WHERE from_email='$SENDER' OR to_email='$RECV';
       DELETE FROM accounts WHERE user_id IN (SELECT id FROM users WHERE email IN ('$SENDER','$RECV'));
       DELETE FROM users WHERE email IN ('$ADM','$SENDER','$RECV');"
}
setup() { cleanup; q "INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES
 (1100,'$ADM','x','PI Admin','1990-01-01','VERIFIED','SUPER_ADMIN'),
 (1101,'$SENDER','x','PI Sender','1990-01-01','VERIFIED','USER'),
 (1102,'$RECV','x','PI Receiver','1990-01-01','VERIFIED','USER') ON DUPLICATE KEY UPDATE role=VALUES(role),status='VERIFIED';
 INSERT INTO accounts (user_id,currency_id,balance,status) SELECT 1101,currency_id,5000,'ACTIVE' FROM currencies WHERE iso_code='IDR' LIMIT 1;
 INSERT INTO accounts (user_id,currency_id,balance,status) SELECT 1102,currency_id,0,'ACTIVE' FROM currencies WHERE iso_code='IDR' LIMIT 1;"; }
teardown() { cleanup; q "DELETE FROM audit_trail WHERE action='AUTHZ_DENIED' AND actor_id=1102;"; }
trap 'core_stop; teardown' EXIT
core_start
echo "======================================================================"
echo "  STANDING PAYMENT INSTRUCTION SUITE (PHASE 1)"
echo "======================================================================"
setup
check "create once instruction" "SUCCESS|PIC_CREATED|PITEST1" \
    "$(run PIC_CREATE PITEST1 "$SENDER" "$RECV" '100.00,IDR' "ONCE,$TODAY" "$ADM")"
check "duplicate rejected" "ERROR|DUPLICATE" \
    "$(run PIC_CREATE PITEST1 "$SENDER" "$RECV" '100.00,IDR' "ONCE,$TODAY" "$ADM")"
check_contains "list instructions" "PITEST1" \
    "$(run PIC_LIST '' 50 0 '' '' "$ADM")"
check_contains "get instruction" "PITEST1|$SENDER|$RECV" \
    "$(run PIC_GET PITEST1 '' '' '' '' "$ADM")"
check_contains "due instruction listed" "PITEST1" \
    "$(run PIC_DUE '' 50 '' '' '' "$ADM")"
check_contains "execute instruction" "SUCCESS|PIC_EXECUTED|PITEST1|" \
    "$(run PIC_EXECUTE PITEST1 '' '' '' '' "$ADM")"
check "instruction completed" "COMPLETED" \
    "$(q "SELECT status FROM payment_instruction WHERE instruction_code='PITEST1';")"
check "recipient credited" "100.0000" \
    "$(q "SELECT balance FROM accounts WHERE user_id=1102;")"
check_contains "history completed" "COMPLETED" \
    "$(run PIC_HISTORY PITEST1 50 0 '' '' "$ADM")"
check "create recurring instruction" "SUCCESS|PIC_CREATED|PITEST2" \
    "$(run PIC_CREATE PITEST2 "$SENDER" "$RECV" '50.00,IDR' "DAILY,$TODAY" "$ADM")"
check "pause instruction" "SUCCESS|PIC_PAUSED" \
    "$(run PIC_PAUSE PITEST2 '' '' '' '' "$ADM")"
check "resume instruction" "SUCCESS|PIC_RESUMED" \
    "$(run PIC_RESUME PITEST2 '' '' '' '' "$ADM")"
check "cancel instruction" "SUCCESS|PIC_CANCELLED" \
    "$(run PIC_CANCEL PITEST2 '' '' '' '' "$ADM")"
check "missing instruction rejected" "ERROR|NOT_FOUND" \
    "$(run PIC_GET MISSING '' '' '' '' "$ADM")"
check "non-admin forbidden" "ERROR|FORBIDDEN" \
    "$(run PIC_LIST '' 50 0 '' '' "$SENDER")"
check "instruction audit rows recorded" "6" \
    "$(q "SELECT COUNT(*) FROM payment_audit WHERE actor_email IN ('$ADM','$SENDER') AND action LIKE 'INSTRUCTION%';")"
echo "----------------------------------------------------------------------"; echo "PASSED: $passed  FAILED: $failed"; echo "----------------------------------------------------------------------"; [ "$failed" -eq 0 ]
