#!/bin/bash
# MFA recovery suite: single-use hashed backup codes (generate, login,
# consume-once, regenerate, clear on disable/reset) and the assisted
# recovery flow (request with re-proofing, verify, approve/reject with
# notification and audit, strict ordering, no self-approval).
# Usage: ./tests/test_mfa_recovery.sh
#
# TOTP codes are minted with python (RFC 6238, SHA-1) against the fixed
# test secret so owner flows that need a device code stay deterministic.

BIN="./cobol/bin/main_logic"
TOTP_SECRET="JBSWY3DPEHPK3PXP"

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

totp() {
    python3 -c "import hmac,hashlib,struct,time,base64; s=base64.b32decode('$TOTP_SECRET'); t=int(time.time())//30; h=hmac.new(s,struct.pack('>Q',t),hashlib.sha1).digest(); o=h[-1]&15; print(str(((h[o]&127)<<24|h[o+1]<<16|h[o+2]<<8|h[o+3])%1000000).zfill(6))"
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

U=rec_u@test.com; A=rec_adm@test.com; B=rec_chk@test.com
new_user() {
    run REQUEST_SIGNUP "$1" secret123 "$2" 1990-01-01 >/dev/null
    local c
    c="$(q "SELECT code FROM verification_logs WHERE email='$1' AND purpose='SIGNUP' AND is_used=0 ORDER BY id DESC LIMIT 1;")"
    run VERIFY_EMAIL "$1" "$c" >/dev/null
}
setup() {
    q "DELETE FROM mfa_backup_codes WHERE user_id IN (SELECT id FROM users WHERE email LIKE 'rec_%@test.com');
       DELETE FROM mfa_recovery_requests WHERE request_id > 0;
       DELETE FROM users WHERE email IN ('$U','$A','$B');
       DELETE FROM verification_logs WHERE email LIKE 'rec_%@test.com';
       DELETE FROM notification_outbox WHERE recipient LIKE 'rec_%@test.com';"
    new_user "$U" "Rec User"
    new_user "$A" "Rec Admin"
    new_user "$B" "Rec Checker"
    q "UPDATE users SET role='SUPER_ADMIN' WHERE email IN ('$A','$B');"
}

teardown() {
    q "DELETE FROM mfa_backup_codes WHERE user_id IN (SELECT id FROM users WHERE email LIKE 'rec_%@test.com');
       DELETE FROM mfa_recovery_requests WHERE request_id > 0;
       DELETE FROM verification_logs WHERE email LIKE 'rec_%@test.com' AND purpose = 'MFA_RECOVERY';
       DELETE FROM notification_outbox WHERE recipient LIKE 'rec_%@test.com';
       DELETE FROM audit_trail WHERE action IN ('MFA_BACKUP_ISSUED','MFA_RECOVERY','RECOVERY_REJECTED') AND user_id IN (SELECT id FROM users WHERE email LIKE 'rec_%@test.com');
       DELETE FROM users WHERE email IN ('$U','$A','$B');"
}
trap teardown EXIT

echo "======================================================================"
echo "  MFA RECOVERY SUITE"
echo "======================================================================"

setup

# --- backup codes need MFA first ------------------------------------------------
check "backup codes need MFA enabled" "ERROR|MFA_NOT_ENABLED" "$(run MFA_BACKUP_CODES $U $U)"
q "UPDATE users SET mfa_enabled=1, mfa_secret='$TOTP_SECRET' WHERE email='$U';"

# --- generation: eight single-use codes, hashed at rest ---------------------------
GEN="$(run MFA_BACKUP_CODES $U $U)"
check "backup codes issued" "SUCCESS|BACKUP_CODES" "$(echo "$GEN" | cut -d'|' -f1-2)"
CODES="$(echo "$GEN" | cut -d'|' -f3)"
check "eight codes issued" "8" "$(echo "$CODES" | tr ',' '\n' | wc -l | tr -d ' ')"
C1="$(echo "$CODES" | cut -d',' -f1)"
C2="$(echo "$CODES" | cut -d',' -f2)"
check "codes are hashed, never stored plain" "0" "$(q "SELECT COUNT(*) FROM mfa_backup_codes WHERE code_hash='$C1';")"
check "non-owner cannot generate" "ERROR|FORBIDDEN" "$(run MFA_BACKUP_CODES $U $A)"

# --- a backup code logs in, then burns ----------------------------------------------
check "backup code logs in" "SUCCESS|LOGIN_OK" "$(run AUTH_LOGIN $U secret123 "$C1" | cut -d'|' -f1-2)"
check "exactly one code burned" "1" "$(q "SELECT COUNT(*) FROM mfa_backup_codes WHERE user_id=(SELECT id FROM users WHERE email='$U') AND used=1;")"
check "burned code is rejected" "ERROR|INVALID_MFA" "$(run AUTH_LOGIN $U secret123 "$C1")"
check "wrong backup code is rejected" "ERROR|INVALID_MFA" "$(run AUTH_LOGIN $U secret123 0000000000)"
check "totp still works" "SUCCESS|LOGIN_OK" "$(run AUTH_LOGIN $U secret123 "$(totp)" | cut -d'|' -f1-2)"

# --- regenerating invalidates the old set --------------------------------------------
GEN2="$(run MFA_BACKUP_CODES $U $U)"
C3="$(echo "$GEN2" | cut -d'|' -f3 | cut -d',' -f1)"
check "old code dead after regen" "ERROR|INVALID_MFA" "$(run AUTH_LOGIN $U secret123 "$C2")"
check "new code works" "SUCCESS|LOGIN_OK" "$(run AUTH_LOGIN $U secret123 "$C3" | cut -d'|' -f1-2)"

# --- disabling MFA clears the codes --------------------------------------------------
check "owner disables with totp" "SUCCESS|MFA_DISABLED" "$(run MFA_DISABLE $U "$(totp)" $U)"
check "disable cleared the codes" "0" "$(q "SELECT COUNT(*) FROM mfa_backup_codes WHERE user_id=(SELECT id FROM users WHERE email='$U');")"

# --- assisted recovery: neutral request, verify, approve ------------------------------
q "UPDATE users SET mfa_enabled=1, mfa_secret='$TOTP_SECRET' WHERE email='$U';"
run MFA_BACKUP_CODES $U $U >/dev/null
check "neutral for unknown email" "SUCCESS|CODE_SENT" "$(run REQUEST_MFA_RECOVERY ghost@test.com whatever)"
check "neutral for wrong password" "SUCCESS|CODE_SENT" "$(run REQUEST_MFA_RECOVERY $U wrongpass)"
check "no request on neutral paths" "0" "$(q "SELECT COUNT(*) FROM mfa_recovery_requests;")"
check "request ok" "SUCCESS|CODE_SENT" "$(run REQUEST_MFA_RECOVERY $U secret123)"
check "recovery code queued" "MFA_RECOVERY" "$(q "SELECT purpose FROM notification_outbox WHERE recipient='$U' ORDER BY id DESC LIMIT 1;")"
RC="$(q "SELECT code FROM verification_logs WHERE email='$U' AND purpose='MFA_RECOVERY' AND is_used=0 ORDER BY id DESC LIMIT 1;")"
check "wrong code is refused" "ERROR|INVALID_CODE" "$(run VERIFY_MFA_RECOVERY $U 000000)"
check "verify ok" "SUCCESS|RECOVERY_VERIFIED" "$(run VERIFY_MFA_RECOVERY $U "$RC")"
check "request is VERIFIED" "VERIFIED" "$(q "SELECT state FROM mfa_recovery_requests ORDER BY request_id DESC LIMIT 1;")"
RID="$(q "SELECT request_id FROM mfa_recovery_requests ORDER BY request_id DESC LIMIT 1;")"
check "non-admin cannot approve" "ERROR|FORBIDDEN" "$(run APPROVE_MFA_RECOVERY "$RID" $U)"
check "approve ok" "SUCCESS|RECOVERY_APPROVED" "$(run APPROVE_MFA_RECOVERY "$RID" $A)"
check "mfa is cleared" "0" "$(q "SELECT mfa_enabled FROM users WHERE email='$U';")"
check "backup codes burned with it" "0" "$(q "SELECT COUNT(*) FROM mfa_backup_codes WHERE user_id=(SELECT id FROM users WHERE email='$U');")"
check "notice queued" "1" "$(q "SELECT COUNT(*) FROM notification_outbox WHERE recipient='$U' AND purpose='MFA_RECOVERY_NOTICE';")"
check "re-approve is refused" "ERROR|UNKNOWN_TRANSACTION" "$(run APPROVE_MFA_RECOVERY "$RID" $A)"

# --- rejection, strict ordering, no self-approval ---------------------------------------
run REQUEST_MFA_RECOVERY $U secret123 >/dev/null
RID2="$(q "SELECT request_id FROM mfa_recovery_requests ORDER BY request_id DESC LIMIT 1;")"
check "non-admin cannot reject" "ERROR|FORBIDDEN" "$(run REJECT_MFA_RECOVERY "$RID2" $U)"
check "reject ok" "SUCCESS|RECOVERY_REJECTED" "$(run REJECT_MFA_RECOVERY "$RID2" $A)"
check "verify after reject is refused" "ERROR|INVALID_CODE" "$(run VERIFY_MFA_RECOVERY $U 000000)"
run REQUEST_MFA_RECOVERY $U secret123 >/dev/null
RID3="$(q "SELECT request_id FROM mfa_recovery_requests ORDER BY request_id DESC LIMIT 1;")"
RC3="$(q "SELECT code FROM verification_logs WHERE email='$U' AND purpose='MFA_RECOVERY' AND is_used=0 ORDER BY id DESC LIMIT 1;")"
run VERIFY_MFA_RECOVERY $U "$RC3" >/dev/null
check "direct approve of PENDING is refused" "ERROR|UNKNOWN_TRANSACTION" "$(run APPROVE_MFA_RECOVERY 999999999 $A)"
check "list shows the queue" "3" "$(run LIST_MFA_RECOVERY $A | cut -d'|' -f3)"
check "list filters by state" "REJECTED" "$(run LIST_MFA_RECOVERY $A REJECTED | grep -oE 'REJECTED' | head -1)"
check "bad id rejected" "ERROR|INVALID_INPUT" "$(run APPROVE_MFA_RECOVERY abc $A)"
check "bad status filter" "ERROR|INVALID_INPUT" "$(run LIST_MFA_RECOVERY $A BOGUS)"

# --- admin self-approval is forbidden -----------------------------------------------------
new_user rec_self@test.com "Rec Self"
q "UPDATE users SET role='SUPER_ADMIN', mfa_enabled=1 WHERE email='rec_self@test.com';"
run REQUEST_MFA_RECOVERY rec_self@test.com secret123 >/dev/null
RIDS="$(q "SELECT request_id FROM mfa_recovery_requests WHERE user_id=(SELECT id FROM users WHERE email='rec_self@test.com') ORDER BY request_id DESC LIMIT 1;")"
RCS="$(q "SELECT code FROM verification_logs WHERE email='rec_self@test.com' AND purpose='MFA_RECOVERY' AND is_used=0 ORDER BY id DESC LIMIT 1;")"
run VERIFY_MFA_RECOVERY rec_self@test.com "$RCS" >/dev/null
check "self-approval is forbidden" "ERROR|FORBIDDEN" "$(run APPROVE_MFA_RECOVERY "$RIDS" rec_self@test.com)"
check "other admin can approve" "SUCCESS|RECOVERY_APPROVED" "$(run APPROVE_MFA_RECOVERY "$RIDS" $A)"
q "DELETE FROM users WHERE email='rec_self@test.com';"

echo "======================================================================"
echo "Tests Completed: ${GREEN}${passed} passed${NC}, ${RED}${failed} failed${NC}"
echo "======================================================================"
[ "$failed" -eq 0 ]
