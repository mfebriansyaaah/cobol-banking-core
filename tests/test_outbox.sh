#!/bin/bash
# Notification outbox suite: transactional enqueue on signup/resend/
# forgot-password/email-change, worker dispatch with retries, dead-letter
# after the attempt budget, stale-claim reaping, redaction, and the
# read-only list view. Counts are scoped to this suite's addresses so
# shared-database residue cannot flake the assertions.
# Usage: ./tests/test_outbox.sh

BIN="./cobol/bin/main_logic"
WORKER="./scripts/outbox_worker.sh"

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
    local name="$1" expected="$2" actual="$3"
    if [[ "$actual" == *"$expected"* ]]; then
        echo -e "${GREEN}PASS${NC} $name"; passed=$((passed+1))
    else
        echo -e "${RED}FAIL${NC} $name (expected to contain [$expected] got [$actual])"; failed=$((failed+1))
    fi
}

check_absent() {
    local name="$1" unexpected="$2" actual="$3"
    if [[ "$actual" != *"$unexpected"* ]]; then
        echo -e "${GREEN}PASS${NC} $name"; passed=$((passed+1))
    else
        echo -e "${RED}FAIL${NC} $name (unexpected [$unexpected] in output)"; failed=$((failed+1))
    fi
}

LOG="$(mktemp)"
trap 'rm -f "$LOG"; q "DELETE FROM notification_outbox WHERE recipient LIKE '\''ob_%@test.com'\''; DELETE FROM verification_logs WHERE email LIKE '\''ob_%@test.com'\''; DELETE FROM users WHERE email LIKE '\''ob_%@test.com'\'';" >/dev/null 2>&1' EXIT

echo "======================================================================"
echo "  NOTIFICATION OUTBOX SUITE"
echo "======================================================================"

# --- signup enqueues durably ------------------------------------------------
check "signup ok" "SUCCESS|USER_CREATED" "$(run REQUEST_SIGNUP ob_signup@test.com secret123 ObSignup 1990-01-01 | cut -d'|' -f1-2)"
check "signup queued PENDING" "PENDING" "$(q "SELECT state FROM notification_outbox WHERE recipient='ob_signup@test.com';")"
CODE1="$(q "SELECT code FROM notification_outbox WHERE recipient='ob_signup@test.com';")"
check "queued code matches the verification log" "$(q "SELECT code FROM verification_logs WHERE email='ob_signup@test.com' AND purpose='SIGNUP' AND is_used=0 ORDER BY id DESC LIMIT 1;")" "$CODE1"

# --- log transport delivers and marks SENT ------------------------------------
export OUTBOX_TRANSPORT=log OUTBOX_LOG_FILE="$LOG"
OUT1="$($WORKER --once --limit 50 2>&1)"
unset OUTBOX_TRANSPORT OUTBOX_LOG_FILE
check_contains "worker reports the send" "outbox_sent" "$OUT1"
check "row is SENT" "SENT" "$(q "SELECT state FROM notification_outbox WHERE recipient='ob_signup@test.com';")"
check_contains "delivery file carries the code" "$CODE1" "$(cat "$LOG")"
check_absent "stdout never carries the code" "$CODE1" "$OUT1"

# --- without SMTP the send fails, retries, then dead-letters --------------------
export OUTBOX_MAX_ATTEMPTS=2
run REQUEST_SIGNUP ob_fail@test.com secret123 ObFail 1990-01-01 >/dev/null
OUT2="$(node middleware/src/outbox_worker.js --once --limit 50 2>&1)"
check_contains "failed send is reported" "outbox_failed" "$OUT2"
check "row is FAILED with attempts" "FAILED|1" "$(q "SELECT CONCAT(state, '|', attempts) FROM notification_outbox WHERE recipient='ob_fail@test.com';")"
check "retry is scheduled" "1" "$(q "SELECT next_attempt_at IS NOT NULL FROM notification_outbox WHERE recipient='ob_fail@test.com';")"
check "not-yet-due rows are skipped" "FAILED|1" "$(node middleware/src/outbox_worker.js --once --limit 50 >/dev/null 2>&1; q "SELECT CONCAT(state, '|', attempts) FROM notification_outbox WHERE recipient='ob_fail@test.com';")"
q "UPDATE notification_outbox SET next_attempt_at = DATE_SUB(NOW(), INTERVAL 1 MINUTE) WHERE recipient='ob_fail@test.com';"
OUT3="$(node middleware/src/outbox_worker.js --once --limit 50 2>&1)"
check_contains "exhausted budget dead-letters" "outbox_dead_letter" "$OUT3"
check "row is DEAD" "DEAD" "$(q "SELECT state FROM notification_outbox WHERE recipient='ob_fail@test.com';")"
unset OUTBOX_MAX_ATTEMPTS

# --- stale claims are reaped --------------------------------------------------------
run REQUEST_SIGNUP ob_stale@test.com secret123 ObStale 1990-01-01 >/dev/null
STALE_ID="$(q "SELECT id FROM notification_outbox WHERE recipient='ob_stale@test.com';")"
q "UPDATE notification_outbox SET state='SENDING', claimed_by='dead-worker', claimed_at=DATE_SUB(NOW(), INTERVAL 31 MINUTE) WHERE id='$STALE_ID';"
export OUTBOX_TRANSPORT=log OUTBOX_LOG_FILE="$LOG"
"$WORKER" --once --limit 50 >/dev/null 2>&1
unset OUTBOX_TRANSPORT OUTBOX_LOG_FILE
check "stale claim is reaped and delivered" "SENT" "$(q "SELECT state FROM notification_outbox WHERE id='$STALE_ID';")"

# --- unknown purposes fail closed instead of vanishing --------------------------------
q "INSERT INTO notification_outbox (recipient, purpose, code) VALUES ('ob_bogus@test.com','BOGUS','');"
export OUTBOX_TRANSPORT=log OUTBOX_LOG_FILE="$LOG"
OUT4="$("$WORKER" --once --limit 50 2>&1)"
unset OUTBOX_TRANSPORT OUTBOX_LOG_FILE
check_contains "unknown purpose is reported" "outbox_failed" "$OUT4"
check "unknown purpose stays FAILED within budget" "FAILED" "$(q "SELECT state FROM notification_outbox WHERE recipient='ob_bogus@test.com';")"

# --- resend within cooldown sends nothing new -------------------------------------------
run REQUEST_SIGNUP ob_cool@test.com secret123 ObCool 1990-01-01 >/dev/null
run RESEND_VERIFICATION ob_cool@test.com >/dev/null
check "cooldown resend issues nothing new" "1" "$(q "SELECT COUNT(*) FROM notification_outbox WHERE recipient='ob_cool@test.com';")"

# --- resend and forgot-password enqueue (cooldown off for determinism) ------------------
export RESEND_COOLDOWN_SECONDS=0
run RESEND_VERIFICATION ob_cool@test.com >/dev/null
check "fresh resend enqueues" "2" "$(q "SELECT COUNT(*) FROM notification_outbox WHERE recipient='ob_cool@test.com';")"
unset RESEND_COOLDOWN_SECONDS
run FORGOT_PASSWORD ob_cool@test.com >/dev/null
check "forgot-password enqueues" "PASSWORD_RESET" "$(q "SELECT purpose FROM notification_outbox WHERE recipient='ob_cool@test.com' ORDER BY id DESC LIMIT 1;")"

# --- email change enqueues the new-address code ----------------------------------------------
run REQUEST_SIGNUP ob_owner@test.com secret123 ObOwner 1990-01-01 >/dev/null
run REQ_EMAIL_CHANGE ob_owner@test.com ob_new@test.com ob_owner@test.com secret123 >/dev/null
check "email-change code queued for the new address" "1" "$(q "SELECT COUNT(*) FROM notification_outbox WHERE recipient='ob_new@test.com' AND purpose='EMAIL_CHANGE';")"
CODE2="$(q "SELECT code FROM notification_outbox WHERE recipient='ob_new@test.com';")"
run CONFIRM_EMAIL_CHANGE ob_owner@test.com ob_new@test.com "$CODE2" ob_owner@test.com >/dev/null
check "abandoned address gets a notice" "1" "$(q "SELECT COUNT(*) FROM notification_outbox WHERE recipient='ob_owner@test.com' AND purpose='EMAIL_CHANGED';")"
q "INSERT INTO users (email,password_hash,full_name,dob,status,role) VALUES ('ob_adm@test.com','x','Ob Admin','1990-01-01','VERIFIED','SUPER_ADMIN') ON DUPLICATE KEY UPDATE status='VERIFIED',role='SUPER_ADMIN';"

# --- list view never exposes codes ----------------------------------------------------------
run REQUEST_SIGNUP ob_list@test.com secret123 ObList 1990-01-01 >/dev/null
CODE3="$(q "SELECT code FROM notification_outbox WHERE recipient='ob_list@test.com';")"
LISTED="$(run LIST_OUTBOX ob_adm@test.com)"
check_contains "list shows queued rows" "ob_list@test.com" "$LISTED"
check_absent "list carries no code" "$CODE3" "$LISTED"

echo "======================================================================"
echo "Tests Completed: ${GREEN}${passed} passed${NC}, ${RED}${failed} failed${NC}"
echo "======================================================================"
[ "$failed" -eq 0 ]
