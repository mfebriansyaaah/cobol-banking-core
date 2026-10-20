#!/bin/bash
# Password policy suite (ADR 0077): the owner-controlled deny list refuses
# common passwords (case-insensitively) at signup, change, and reset; the
# bounded history refuses the current password and the last N; setting
# PASSWORD_HISTORY_COUNT=0 disables the history check; the history is trimmed
# to the configured bound. Per-call environment is required, so this suite
# uses the file-mode invocation rather than the serve harness.
# Usage: ./tests/test_password_policy.sh

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

# Per-call environment: the policy knobs are read by the core at request time.
runenv() {
    local assignment="$1"; shift
    printf "%s|%s|%s|%s|%s\n" "$1" "$2" "$3" "$4" "$5" > input.txt
    env "$assignment" "$BIN" >/dev/null 2>&1
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

U="pwpol_u@test.com"; N="pwpol_new@test.com"

setup() {
    q "DELETE FROM password_history WHERE user_id IN (SELECT id FROM users WHERE email IN ('$U','$N'));
       DELETE FROM verification_logs WHERE email IN ('$U','$N');
       DELETE FROM users WHERE email IN ('$U','$N');
       INSERT INTO users (id,email,password_hash,full_name,dob,status,role) VALUES
       (2011,'$U',CONCAT('SHA256_',SHA2('secret123',256)),'PW Policy','1990-01-01','VERIFIED','USER');"
}

teardown() {
    q "DELETE FROM password_history WHERE user_id IN (SELECT id FROM users WHERE email IN ('$U','$N'));
       DELETE FROM verification_logs WHERE email IN ('$U','$N');
       DELETE FROM audit_trail WHERE user_id IN (SELECT id FROM users WHERE email IN ('$U','$N'));
       DELETE FROM users WHERE email IN ('$U','$N');"
}
trap teardown EXIT

echo "======================================================================"
echo "  PASSWORD POLICY SUITE"
echo "======================================================================"

setup

# --- the deny list -----------------------------------------------------------------
check "signup refuses a blocklisted password" "ERROR|PASSWORD_BLOCKED" \
    "$(run REQUEST_SIGNUP "$N" password "PW New" 1990-01-01)"
check "the deny list is case-insensitive" "ERROR|PASSWORD_BLOCKED" \
    "$(run REQUEST_SIGNUP "$N" PassWord "PW New" 1990-01-01)"
check_contains "signup accepts a non-blocklisted password" "SUCCESS|USER_CREATED" \
    "$(run REQUEST_SIGNUP "$N" goodpass123 "PW New" 1990-01-01)"
check "change refuses a blocklisted password" "ERROR|PASSWORD_BLOCKED" \
    "$(run CHANGE_PASSWORD "$U" secret123 password "$U")"
# The reset path needs a fresh code; fetch it with the cooldown disabled.
CODE="$(RESEND_COOLDOWN_SECONDS=0 bash -c 'printf "FORGOT_PASSWORD|'"$U"'||||\n" > input.txt; ./cobol/bin/main_logic >/dev/null 2>&1; cat output.txt' | cut -d'|' -f3)"
check "reset refuses a blocklisted password" "ERROR|PASSWORD_BLOCKED" \
    "$(run RESET_PASSWORD "$U" "$CODE" password)"

# --- the bounded history -----------------------------------------------------------
check "change to a fresh password" "SUCCESS|PASSWORD_CHANGED" \
    "$(run CHANGE_PASSWORD "$U" secret123 newpass111 "$U")"
check "change to a second fresh password" "SUCCESS|PASSWORD_CHANGED" \
    "$(run CHANGE_PASSWORD "$U" newpass111 newpass222 "$U")"
check "the previous password is refused" "ERROR|PASSWORD_REUSED" \
    "$(run CHANGE_PASSWORD "$U" newpass222 newpass111 "$U")"
check "the current password is refused" "ERROR|PASSWORD_REUSED" \
    "$(run CHANGE_PASSWORD "$U" newpass222 newpass222 "$U")"
check "the history is bounded to the configured count" "2" \
    "$(q "SELECT COUNT(*) FROM password_history WHERE user_id=(SELECT id FROM users WHERE email='$U');")"
check "zero disables the history check" "SUCCESS|PASSWORD_CHANGED" \
    "$(runenv PASSWORD_HISTORY_COUNT=0 CHANGE_PASSWORD "$U" newpass222 newpass222 "$U")"
check "the disabled check records no history row" "2" \
    "$(q "SELECT COUNT(*) FROM password_history WHERE user_id=(SELECT id FROM users WHERE email='$U');")"

# Trim: with a count of 2, a password outside the last two entries is allowed.
q "DELETE FROM password_history WHERE user_id=(SELECT id FROM users WHERE email='$U');"
runenv PASSWORD_HISTORY_COUNT=2 CHANGE_PASSWORD "$U" newpass222 trimA111 "$U" >/dev/null
runenv PASSWORD_HISTORY_COUNT=2 CHANGE_PASSWORD "$U" trimA111 trimB222 "$U" >/dev/null
runenv PASSWORD_HISTORY_COUNT=2 CHANGE_PASSWORD "$U" trimB222 trimC333 "$U" >/dev/null
check "the trim keeps exactly the configured count" "2" \
    "$(q "SELECT COUNT(*) FROM password_history WHERE user_id=(SELECT id FROM users WHERE email='$U');")"
check "a password outside the window is allowed" "SUCCESS|PASSWORD_CHANGED" \
    "$(runenv PASSWORD_HISTORY_COUNT=2 CHANGE_PASSWORD "$U" trimC333 trimA111 "$U")"

# --- the reset path uses the same policy -------------------------------------------
CODE="$(RESEND_COOLDOWN_SECONDS=0 bash -c 'printf "FORGOT_PASSWORD|'"$U"'||||\n" > input.txt; ./cobol/bin/main_logic >/dev/null 2>&1; cat output.txt' | cut -d'|' -f3)"
check "reset refuses the current password" "ERROR|PASSWORD_REUSED" \
    "$(run RESET_PASSWORD "$U" "$CODE" trimA111)"
CODE="$(RESEND_COOLDOWN_SECONDS=0 bash -c 'printf "FORGOT_PASSWORD|'"$U"'||||\n" > input.txt; ./cobol/bin/main_logic >/dev/null 2>&1; cat output.txt' | cut -d'|' -f3)"
check "reset accepts a fresh password" "SUCCESS|PASSWORD_RESET" \
    "$(run RESET_PASSWORD "$U" "$CODE" resetpass999)"
check "the reset uses the configured bound (default 5)" "3" \
    "$(q "SELECT COUNT(*) FROM password_history WHERE user_id=(SELECT id FROM users WHERE email='$U');")"
check "the stored hash is PBKDF2" "PBKDF2\$" \
    "$(q "SELECT LEFT(password_hash,7) FROM users WHERE email='$U';")"

echo "======================================================================"
echo -e "Tests Completed: ${GREEN}${passed} passed${NC}, ${RED}${failed} failed${NC}"
echo "======================================================================"
[ "$failed" -eq 0 ]
