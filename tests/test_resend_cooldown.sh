#!/bin/bash
# Resend cooldown suite: requesting a fresh signup or password-reset code
# inside the per-account window neutrally reuses the pending code (no new
# code, no new email), so the endpoints cannot flood a mailbox or the table.
# Usage: ./tests/test_resend_cooldown.sh

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

# Run an action with an explicit resend cooldown (seconds).
run_cd() {
    local cd="$1"; shift
    printf "%s|%s|%s|%s|%s\n" "$1" "$2" "$3" "$4" "$5" > input.txt
    RESEND_COOLDOWN_SECONDS="$cd" "$BIN" >/dev/null 2>&1
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

pending_code() { q "SELECT code FROM verification_logs WHERE email='$1' AND purpose='$2' AND is_used=0 ORDER BY id DESC LIMIT 1;"; }
pending_count() { q "SELECT COUNT(*) FROM verification_logs WHERE email='$1' AND purpose='$2' AND is_used=0;"; }

echo "======================================================================"
echo "  RESEND COOLDOWN SUITE"
echo "======================================================================"

# --- signup resends -------------------------------------------------------
R="rc_signup@test.com"
q "DELETE FROM verification_logs WHERE email='$R'; DELETE FROM users WHERE email='$R';"
run REQUEST_SIGNUP "$R" secret123 'Rc Signup' '1990-01-01' >/dev/null
C1="$(pending_code "$R" SIGNUP)"
check "immediate resend stays neutral" "SUCCESS|CODE_SENT" "$(run RESEND_VERIFICATION "$R" | cut -d'|' -f1-2)"
check "immediate resend reuses the pending code" "$C1" "$(pending_code "$R" SIGNUP)"
check "immediate resend stores no extra row" "1" "$(pending_count "$R" SIGNUP)"
C2="$(run_cd 0 RESEND_VERIFICATION "$R" | cut -d'|' -f3)"
[ -n "$C2" ] && [ "$C2" != "$C1" ] && check "cooldown zero reissues" "reissued" "reissued" \
    || check "cooldown zero reissues" "reissued" "reused"
q "DELETE FROM verification_logs WHERE email='$R'; DELETE FROM users WHERE email='$R';"

# --- password-reset re-requests -------------------------------------------
F="rc_forgot@test.com"
q "DELETE FROM verification_logs WHERE email='$F'; DELETE FROM users WHERE email='$F';"
run REQUEST_SIGNUP "$F" secret123 'Rc Forgot' '1990-01-01' >/dev/null
fc=$(pending_code "$F" SIGNUP)
run VERIFY_EMAIL "$F" "$fc" >/dev/null
run FORGOT_PASSWORD "$F" >/dev/null
F1="$(pending_code "$F" PASSWORD_RESET)"
check "immediate forgot stays neutral" "SUCCESS|CODE_SENT" "$(run FORGOT_PASSWORD "$F" | cut -d'|' -f1-2)"
check "immediate forgot reuses the pending code" "$F1" "$(pending_code "$F" PASSWORD_RESET)"
check "immediate forgot stores no extra row" "1" "$(pending_count "$F" PASSWORD_RESET)"
q "DELETE FROM verification_logs WHERE email='$F'; DELETE FROM users WHERE email='$F';"

echo "======================================================================"
echo -e "Tests Completed: ${GREEN}${passed} passed${NC}, ${RED}${failed} failed${NC}"
echo "======================================================================"
[ "$failed" -eq 0 ]
