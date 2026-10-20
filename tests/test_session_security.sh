#!/bin/bash
# Session-security suite (ADR 0075): revoke every other device while keeping
# the caller's own family, the administrator idle bound on refresh, the
# first-sighting device notice, and the authentication audit taxonomy.
# Usage: ./tests/test_session_security.sh

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

A="ss2_admin@test.com"; U="ss2_user@test.com"

setup() {
    q "DELETE FROM refresh_sessions WHERE email IN ('$A','$U');
       DELETE FROM known_devices WHERE email IN ('$A','$U');
       DELETE FROM notification_outbox WHERE recipient IN ('$A','$U');
       DELETE FROM verification_logs WHERE email IN ('$A','$U');
       DELETE FROM audit_trail WHERE user_id IN (SELECT id FROM users WHERE email IN ('$A','$U'));
       DELETE FROM users WHERE email IN ('$A','$U');
       INSERT INTO users (id,email,password_hash,full_name,dob,status,role,mfa_enabled) VALUES
       (1991,'$A',CONCAT('SHA256_',SHA2('secret',256)),'SS Admin','1990-01-01','VERIFIED','SUPER_ADMIN',1),
       (1992,'$U',CONCAT('SHA256_',SHA2('secret',256)),'SS User','1990-01-01','VERIFIED','USER',0);"
}

teardown() {
    q "DELETE FROM refresh_sessions WHERE email IN ('$A','$U');
       DELETE FROM known_devices WHERE email IN ('$A','$U');
       DELETE FROM notification_outbox WHERE recipient IN ('$A','$U');
       DELETE FROM verification_logs WHERE email IN ('$A','$U');
       DELETE FROM audit_trail WHERE user_id IN (SELECT id FROM users WHERE email IN ('$A','$U'));
       DELETE FROM users WHERE email IN ('$A','$U');"
}
trap teardown EXIT

echo "======================================================================"
echo "  SESSION SECURITY SUITE"
echo "======================================================================"

setup

# --- revoke every other device --------------------------------------------------
run STORE_SESSION famA1 "$U" 7 famA "UA-ONE" 10.0.0.1 >/dev/null
run STORE_SESSION famB1 "$U" 7 famB "UA-TWO" 10.0.0.2 >/dev/null
check "a missing family is refused" "ERROR|INVALID_INPUT" \
    "$(run REVOKE_OTHER_DEVICES "$U" "$U" "")"
check "the owner revokes the other devices" "SUCCESS|OTHER_SESSIONS_REVOKED" \
    "$(run REVOKE_OTHER_DEVICES "$U" "$U" famA)"
check "the current family survives" "0" \
    "$(q "SELECT revoked FROM refresh_sessions WHERE jti='famA1';")"
check "the other family is revoked" "1" \
    "$(q "SELECT revoked FROM refresh_sessions WHERE jti='famB1';")"
check "a plain user cannot manage a higher-ranked account" "ERROR|FORBIDDEN" \
    "$(run REVOKE_OTHER_DEVICES "$A" "$U" famA)"
check "the revocation is audited" "1" \
    "$(q "SELECT COUNT(*) FROM audit_trail WHERE action='SESSIONS_REVOKED_OTHERS' AND entity_type='USER';")"

# --- the administrator idle bound ------------------------------------------------
run STORE_SESSION idleA "$A" 7 famIA "UA-ADM" 10.1.1.1 >/dev/null
run STORE_SESSION idleU "$U" 7 famIU "UA-USR" 10.1.1.2 >/dev/null
q "UPDATE refresh_sessions SET last_seen_at = DATE_SUB(NOW(), INTERVAL 2 HOUR) WHERE jti IN ('idleA','idleU');"
V_BEFORE="$(q "SELECT token_version FROM users WHERE email='$A';")"
check "an idle administrator refresh is refused" "ERROR|SESSION_EXPIRED" \
    "$(run CONSUME_SESSION idleA "" "" "")"
check "the idle family is revoked" "1" \
    "$(q "SELECT revoked FROM refresh_sessions WHERE jti='idleA';")"
check "the idle account's tokens are killed" "$((V_BEFORE + 1))" \
    "$(q "SELECT token_version FROM users WHERE email='$A';")"
check "the idle refusal is audited" "1" \
    "$(q "SELECT COUNT(*) FROM audit_trail WHERE action='SESSION_IDLE_TIMEOUT' AND status='FAILED';")"
check "an idle non-admin refresh is not bounded" "SUCCESS|SESSION_CONSUMED" \
    "$(run CONSUME_SESSION idleU "" "" "")"

run STORE_SESSION idleA2 "$A" 7 famIA2 "UA-ADM" 10.1.1.1 >/dev/null
q "UPDATE refresh_sessions SET last_seen_at = DATE_SUB(NOW(), INTERVAL 2 HOUR) WHERE jti='idleA2';"
printf 'CONSUME_SESSION|idleA2||||\n' > input.txt
ADMIN_IDLE_TIMEOUT_SECONDS=0 "$BIN" >/dev/null 2>&1
check "zero disables the idle bound" "SUCCESS|SESSION_CONSUMED" "$(cat output.txt)"

run STORE_SESSION freshA "$A" 7 famFA "UA-ADM" 10.1.1.1 >/dev/null
check "a fresh administrator session is consumed" "SUCCESS|SESSION_CONSUMED" \
    "$(run CONSUME_SESSION freshA "" "" "")"

# --- first-sighting device notice ------------------------------------------------
check "the first sighting is recorded" "SUCCESS|NOTICE_RECORDED" \
    "$(run LOGIN_NOTICE "$U" UA-NEW 10.9.9.1)"
check "the first sighting queues one notice" "1" \
    "$(q "SELECT COUNT(*) FROM notification_outbox WHERE recipient='$U' AND purpose='NEW_DEVICE' AND detail='10.9.9.1';")"
run LOGIN_NOTICE "$U" UA-NEW 10.9.9.1 >/dev/null
check "a repeat from the same device queues none" "1" \
    "$(q "SELECT COUNT(*) FROM notification_outbox WHERE recipient='$U' AND purpose='NEW_DEVICE' AND detail='10.9.9.1';")"
run LOGIN_NOTICE "$U" UA-NEW 10.9.9.2 >/dev/null
check "a new address queues another notice" "1" \
    "$(q "SELECT COUNT(*) FROM notification_outbox WHERE recipient='$U' AND purpose='NEW_DEVICE' AND detail='10.9.9.2';")"
check "the notice carries no code" "0" \
    "$(q "SELECT COUNT(*) FROM notification_outbox WHERE recipient='$U' AND purpose='NEW_DEVICE' AND code <> '';")"
check "an unknown account has no device record" "ERROR|ACCOUNT_NOT_FOUND" \
    "$(run LOGIN_NOTICE ghost@test.com UA 10.9.9.3)"

# --- the audit taxonomy ----------------------------------------------------------
check "a successful login is audited" "SUCCESS|LOGIN_OK" \
    "$(run AUTH_LOGIN "$U" secret "" "")"
check "the login success row is present" "1" \
    "$(q "SELECT COUNT(*) FROM audit_trail WHERE action='AUTH_LOGIN_SUCCESS' AND status='SUCCESS' AND user_id=(SELECT id FROM users WHERE email='$U');")"
check "a step-up success is audited" "SUCCESS|REAUTH_OK" \
    "$(run VERIFY_REAUTH "$U" secret "" "")"
check "the step-up success row is present" "1" \
    "$(q "SELECT COUNT(*) FROM audit_trail WHERE action='STEP_UP_OK' AND status='SUCCESS' AND user_id=(SELECT id FROM users WHERE email='$U');")"
check "a step-up failure is refused" "ERROR|INVALID_CREDENTIALS" \
    "$(run VERIFY_REAUTH "$U" wrong "" "")"
check "the step-up failure row is present" "1" \
    "$(q "SELECT COUNT(*) FROM audit_trail WHERE action='STEP_UP_FAILED' AND status='FAILED' AND user_id=(SELECT id FROM users WHERE email='$U');")"
check_contains "a reset request is audited" "SUCCESS|CODE_SENT" \
    "$(run FORGOT_PASSWORD "$U" "" "" "")"
check "the reset-request row is present" "1" \
    "$(q "SELECT COUNT(*) FROM audit_trail WHERE action='PASSWORD_RESET_REQUESTED' AND status='SUCCESS' AND user_id=(SELECT id FROM users WHERE email='$U');")"

echo "======================================================================"
echo -e "Tests Completed: ${GREEN}${passed} passed${NC}, ${RED}${failed} failed${NC}"
echo "======================================================================"
[ "$failed" -eq 0 ]
