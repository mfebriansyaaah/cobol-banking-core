#!/bin/bash
# REQUEST_SIGNUP + VERIFY_EMAIL suite (Phase 3c).
# Verifies signup creates an UNVERIFIED user with a 6-digit code, enforces
# password strength and email uniqueness, and that VERIFY_EMAIL flips status to
# VERIFIED exactly once.
# Usage: ./tests/test_signup_verify.sh

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

echo "======================================================================"
echo "  SIGNUP + VERIFY EMAIL SUITE"
echo "======================================================================"

EMAIL="signup_ok@test.com"
q "DELETE FROM verification_logs WHERE email='$EMAIL'; DELETE FROM users WHERE email='$EMAIL';"

# Weak password is rejected before any row is written.
check "weak password rejected" "ERROR|WEAK_PASSWORD" \
    "$(run REQUEST_SIGNUP "$EMAIL" short 'Sign Up' '1990-01-01')"
check "no user written on weak password" "0" "$(q "SELECT COUNT(*) FROM users WHERE email='$EMAIL';")"

# Successful signup returns a code and leaves the user UNVERIFIED.
out=$(run REQUEST_SIGNUP "$EMAIL" secret123 'Sign Up' '1990-01-01')
code=$(echo "$out" | cut -d'|' -f3)
case "$out" in
    SUCCESS\|USER_CREATED\|[0-9][0-9][0-9][0-9][0-9][0-9]) check "signup returns code" "ok" "ok" ;;
    *) check "signup returns code" "SUCCESS|USER_CREATED|<6 digits>" "$out" ;;
esac
check "user status UNVERIFIED" "UNVERIFIED" "$(q "SELECT status FROM users WHERE email='$EMAIL';")"
check "password stored with slow KDF" "PBKDF2\$" "$(q "SELECT LEFT(password_hash,7) FROM users WHERE email='$EMAIL';")"
check "email stored without padding" "18" "$(q "SELECT CHAR_LENGTH(email) FROM users WHERE email='$EMAIL';")"
check "verification log written" "1" "$(q "SELECT COUNT(*) FROM verification_logs WHERE email='$EMAIL' AND purpose='SIGNUP' AND is_used=0;")"

# Duplicate email is neutral (anti-enumeration) and writes nothing new.
check "duplicate email is neutral" "SUCCESS|USER_CREATED" \
    "$(run REQUEST_SIGNUP "$EMAIL" secret123 'Sign Up' '1990-01-01')"
check "duplicate wrote no second user" "1" \
    "$(q "SELECT COUNT(*) FROM users WHERE email='$EMAIL';")"

# Wrong code rejected; correct code verifies; reuse rejected.
check "wrong code rejected" "ERROR|INVALID_CODE" "$(run VERIFY_EMAIL "$EMAIL" 000000)"
check "failed verify audited" "1" "$(q "SELECT COUNT(*) FROM audit_trail a JOIN users u ON u.id=a.user_id WHERE u.email='$EMAIL' AND a.action='VERIFY_EMAIL' AND a.status='FAILED';")"
check "correct code verifies" "SUCCESS|EMAIL_VERIFIED" "$(run VERIFY_EMAIL "$EMAIL" "$code")"
check "user status VERIFIED" "VERIFIED" "$(q "SELECT status FROM users WHERE email='$EMAIL';")"
check "code marked used" "1" "$(q "SELECT is_used FROM verification_logs WHERE email='$EMAIL' AND code='$code';")"
check "reused code rejected" "ERROR|INVALID_CODE" "$(run VERIFY_EMAIL "$EMAIL" "$code")"
check "second failed verify audited" "2" "$(q "SELECT COUNT(*) FROM audit_trail a JOIN users u ON u.id=a.user_id WHERE u.email='$EMAIL' AND a.action='VERIFY_EMAIL' AND a.status='FAILED';")"
check "signup audited" "1" "$(q "SELECT COUNT(*) FROM audit_trail a JOIN users u ON u.id=a.user_id WHERE u.email='$EMAIL' AND a.action='SIGNUP';")"
check "verify audited" "1" "$(q "SELECT COUNT(*) FROM audit_trail a JOIN users u ON u.id=a.user_id WHERE u.email='$EMAIL' AND a.action='VERIFY_EMAIL' AND a.status='SUCCESS';")"

# A failed attempt for an unknown email cannot be attributed, so it is not audited.
before_failed=$(q "SELECT COUNT(*) FROM audit_trail WHERE action='VERIFY_EMAIL' AND status='FAILED';")
check "unknown email rejected" "ERROR|INVALID_CODE" "$(run VERIFY_EMAIL unknown_audit@test.com 000000)"
check "unattributable verify not audited" "$before_failed" "$(q "SELECT COUNT(*) FROM audit_trail WHERE action='VERIFY_EMAIL' AND status='FAILED';")"

# --- RESEND VERIFICATION ---
RE="resend_ok@test.com"
q "DELETE FROM verification_logs WHERE email='$RE'; DELETE FROM users WHERE email='$RE';"
rout=$(run REQUEST_SIGNUP "$RE" secret123 'Resend Ok' '1990-01-01')
rcode1=$(echo "$rout" | cut -d'|' -f3)
rout2=$(run RESEND_VERIFICATION "$RE" '' '' '')
rcode2=$(echo "$rout2" | cut -d'|' -f3)
case "$rout2" in
    SUCCESS\|CODE_SENT\|[0-9][0-9][0-9][0-9][0-9][0-9]) check "resend returns a new code" "ok" "ok" ;;
    *) check "resend returns a new code" "SUCCESS|CODE_SENT|<6 digits>" "$rout2" ;;
esac
check "old code invalid after resend" "ERROR|INVALID_CODE" "$(run VERIFY_EMAIL "$RE" "$rcode1")"
check "new code verifies" "SUCCESS|EMAIL_VERIFIED" "$(run VERIFY_EMAIL "$RE" "$rcode2")"
check "resend for verified is neutral" "SUCCESS|CODE_SENT" "$(run RESEND_VERIFICATION "$RE" '' '' '')"
check "resend unknown is neutral" "SUCCESS|CODE_SENT" "$(run RESEND_VERIFICATION ghost_resend@test.com '' '' '')"
q "DELETE FROM verification_logs WHERE email='$RE'; DELETE FROM users WHERE email='$RE';"

# After verification, login works.
check "login after verify" "SUCCESS|LOGIN_OK" "$(run AUTH_LOGIN "$EMAIL" secret123)"

# Expired verification logs are pruned when a new signup happens.
q "INSERT INTO verification_logs (email,code,purpose,expires_at) VALUES ('prune_expired@test.com','000000','SIGNUP', DATE_SUB(NOW(), INTERVAL 1 DAY));"
run REQUEST_SIGNUP prune_another@test.com secret123 'Prune Another' '1990-01-01' >/dev/null
check "expired verification logs pruned" "0" "$(q "SELECT COUNT(*) FROM verification_logs WHERE email='prune_expired@test.com';")"
q "DELETE FROM verification_logs WHERE email IN ('prune_expired@test.com','prune_another@test.com'); DELETE FROM users WHERE email IN ('prune_expired@test.com','prune_another@test.com');"

echo "======================================================================"
echo -e "Tests Completed: ${GREEN}${passed} passed${NC}, ${RED}${failed} failed${NC}"
echo "======================================================================"
[ "$failed" -eq 0 ]
