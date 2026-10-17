#!/bin/bash
# Dispute suite: customer ticket lifecycle (open, notes, acknowledge, resolve,
# reject) linked to accounts/transactions, with controlled assignment, due
# dates, overdue flags, and an append-only message history.
# Usage: ./tests/test_disputes.sh
#
# Fixture ids 932-934 are reserved for this suite (see teardown).

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

U=dp_u@test.com; O=dp_o@test.com; A=dp_a@test.com; X=dp_x@test.com
setup() {
    q "DELETE FROM dispute_messages WHERE case_id IN (SELECT case_id FROM dispute_cases WHERE user_id IN (932,933,934));
       DELETE FROM dispute_cases WHERE user_id IN (932,933,934);
       DELETE FROM ledger WHERE account_id IN (932,933);
       DELETE FROM pending_transactions WHERE txn_ref LIKE 'DPCASE%';
       DELETE FROM accounts WHERE account_id IN (932,933);
       DELETE FROM users WHERE email IN ('$U','$O','$A','$X');
       INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES
       (932,'$U','x','Dispute User','1990-01-01','VERIFIED','USER'),
       (933,'$O','x','Dispute Other','1990-01-01','VERIFIED','USER'),
       (934,'$A','x','Dispute Admin','1990-01-01','VERIFIED','SUPER_ADMIN'),
       (935,'$X','x','Dispute Stranger','1990-01-01','VERIFIED','USER');
       INSERT INTO accounts (account_id,user_id,currency_id,balance,account_type) VALUES
       (932,932,1,1000,'SAVINGS'),
       (933,933,1,0,'SAVINGS');
       INSERT INTO ledger (txn_ref,account_id,amount,type,currency_id,description) VALUES
       ('DPCASE_FUND',932,1000,'CREDIT',1,'Suite funding');"
}

teardown() {
    q "DELETE FROM dispute_messages WHERE case_id IN (SELECT case_id FROM dispute_cases WHERE user_id IN (932,933,934));
       DELETE FROM dispute_cases WHERE user_id IN (932,933,934);
       DELETE FROM ledger WHERE account_id IN (932,933);
       DELETE FROM pending_transactions WHERE txn_ref LIKE 'DPCASE%';
       DELETE FROM audit_trail WHERE action LIKE 'DISPUTE%' AND user_id IN (932,933,934);
       DELETE FROM accounts WHERE account_id IN (932,933);
       DELETE FROM users WHERE email IN ('$U','$O','$A','$X');"
}
trap teardown EXIT

echo "======================================================================"
echo "  DISPUTES SUITE"
echo "======================================================================"

setup

# --- opening ------------------------------------------------------------------------
check "admin cannot open for a customer" "ERROR|FORBIDDEN" "$(run OPEN_DISPUTE $U $A Subject Detail)"
check "missing subject is refused" "ERROR|INVALID_INPUT" "$(run OPEN_DISPUTE $U $U '' Detail)"
check "unknown user is refused" "ERROR|ACCOUNT_NOT_FOUND" "$(run OPEN_DISPUTE ghost@test.com ghost@test.com Subject Detail)"
check "unknown ref is refused" "ERROR|UNKNOWN_TRANSACTION" "$(run OPEN_DISPUTE $U $U Subject Detail NOSUCHREF)"
check "open ok" "SUCCESS|DISPUTE_OPENED" "$(run OPEN_DISPUTE $U $U "Missing transfer" "Where is my money" | cut -d'|' -f1-2)"
C1="$(q "SELECT case_id FROM dispute_cases WHERE user_id=932 ORDER BY case_id DESC LIMIT 1;")"
check "open is audited" "1" "$(q "SELECT COUNT(*) FROM audit_trail WHERE action='DISPUTE_OPENED' AND user_id=932 AND entity_id=$C1;")"

# --- ref-linked opening ----------------------------------------------------------------
check "transfer ok" "SUCCESS|TRANSFER_OK" "$(run TRANSFER $U $O 10.00 DPCASE1)"
check "open with own ref ok" "SUCCESS|DISPUTE_OPENED" "$(run OPEN_DISPUTE $U $U "Bad charge" "Check this charge" DPCASE1 | cut -d'|' -f1-2)"
check "stranger cannot link the ref" "ERROR|UNKNOWN_TRANSACTION" "$(run OPEN_DISPUTE $X $X "Bad charge" "Check this charge" DPCASE1 | cut -d'|' -f1-2)"
C2="$(q "SELECT case_id FROM dispute_cases WHERE user_id=932 ORDER BY case_id DESC LIMIT 1;")"

# --- notes ---------------------------------------------------------------------------------
check "stranger note is refused" "ERROR|FORBIDDEN" "$(run ADD_DISPUTE_NOTE $C1 $O "Stranger note")"
check "refused note is audited" "1" "$(q "SELECT COUNT(*) FROM audit_trail WHERE action='AUTHZ_DENIED' AND actor_id=933;")"
check "owner note ok" "SUCCESS|DISPUTE_NOTED" "$(run ADD_DISPUTE_NOTE $C1 $U "Extra info")"
check "admin note ok" "SUCCESS|DISPUTE_NOTED" "$(run ADD_DISPUTE_NOTE $C1 $A "Looking into it")"
check "bad case id" "ERROR|UNKNOWN_TRANSACTION" "$(run ADD_DISPUTE_NOTE 999999999 $U Nope)"
check "bad id shape" "ERROR|INVALID_INPUT" "$(run ADD_DISPUTE_NOTE abc $U Nope)"

# --- acknowledge ----------------------------------------------------------------------------
check "non-admin cannot ack" "ERROR|FORBIDDEN" "$(run ACK_DISPUTE $C1 $U 2099-01-31)"
check "bad due date" "ERROR|INVALID_INPUT" "$(run ACK_DISPUTE $C1 $A tomorrow)"
check "resolve before ack is refused" "ERROR|INVALID_STATUS" "$(run RESOLVE_DISPUTE $C1 $A "Too early")"
check "ack ok" "SUCCESS|DISPUTE_ACKNOWLEDGED" "$(run ACK_DISPUTE $C1 $A 2099-01-31)"
check "re-ack is refused" "ERROR|INVALID_STATUS" "$(run ACK_DISPUTE $C1 $A 2099-01-31)"
check "ack assigned the admin" "$A" "$(q "SELECT email FROM users WHERE id=(SELECT assigned_to FROM dispute_cases WHERE case_id=$C1);")"

# --- resolve ------------------------------------------------------------------------------------
check "resolve ok" "SUCCESS|DISPUTE_RESOLVED" "$(run RESOLVE_DISPUTE $C1 $A "Money returned")"
check "note after resolve is refused" "ERROR|INVALID_STATUS" "$(run ADD_DISPUTE_NOTE $C1 $U "Too late")"
check "resolve is audited" "1" "$(q "SELECT COUNT(*) FROM audit_trail WHERE action='DISPUTE_RESOLVED' AND entity_id=$C1;")"

# --- reject paths --------------------------------------------------------------------------------
check "direct reject of OPEN ok" "SUCCESS|DISPUTE_REJECTED" "$(run REJECT_DISPUTE $C2 $A "Out of scope")"
check "open third case" "SUCCESS|DISPUTE_OPENED" "$(run OPEN_DISPUTE $U $U "Another issue" "Please help" | cut -d'|' -f1-2)"
C3="$(q "SELECT case_id FROM dispute_cases WHERE user_id=932 ORDER BY case_id DESC LIMIT 1;")"
run ACK_DISPUTE $C3 $A 2020-01-01 >/dev/null
check "past-due case is overdue" "1" "$(run GET_DISPUTE $C3 $A | cut -d'|' -f3 | cut -d':' -f9)"
check "reject of ACKNOWLEDGED ok" "SUCCESS|DISPUTE_REJECTED" "$(run REJECT_DISPUTE $C3 $A "Cannot help")"

# --- read views --------------------------------------------------------------------------------------
GET="$(run GET_DISPUTE $C1 $U)"
check "get shows resolved state" "RESOLVED" "$(echo "$GET" | cut -d'|' -f3 | cut -d':' -f6)"
check "get shows resolution" "Money returned" "$(echo "$GET" | cut -d'|' -f3 | cut -d':' -f11)"
check "get shows two notes" "2" "$(echo "$GET" | cut -d'|' -f4)"
check "get shows admin reply" "Looking into it" "$(echo "$GET" | cut -d'|' -f5 | tr ';' '\n' | grep "$A" | cut -d':' -f3)"
check "stranger get is refused" "ERROR|FORBIDDEN" "$(run GET_DISPUTE $C1 $O)"
check "owner queue is pinned" "3" "$(run LIST_DISPUTES $U | cut -d'|' -f3)"
check "admin sees all three" "3" "$(run LIST_DISPUTES $A | cut -d'|' -f3)"
check "status filter works" "1" "$(run LIST_DISPUTES $A '' RESOLVED | cut -d'|' -f3)"
check "paging slices" "1" "$(run LIST_DISPUTES $A '' '' 1 2 | cut -d'|' -f3 | tr ';' '\n' | wc -l | tr -d ' ')"

# --- history is append-only ----------------------------------------------------------------------------
if mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "UPDATE dispute_messages SET body='tampered' WHERE msg_id=(SELECT MIN(msg_id) FROM dispute_messages);" 2>&1 | grep -q "append-only"; then
    echo -e "${GREEN}PASS${NC} messages resist UPDATE"; passed=$((passed+1))
else
    echo -e "${RED}FAIL${NC} messages resist UPDATE"; failed=$((failed+1))
fi

echo "======================================================================"
echo "Tests Completed: ${GREEN}${passed} passed${NC}, ${RED}${failed} failed${NC}"
echo "======================================================================"
[ "$failed" -eq 0 ]
