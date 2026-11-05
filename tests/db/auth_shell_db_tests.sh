#!/usr/bin/env bash
# Auth/session/MFA shell coverage: every inline app.js auth action invoked
# via run_cobol at least once (HTTP-only coverage is not shell coverage).
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/tests/lib/db.sh"
# shellcheck disable=SC1091
. "$ROOT/tests/lib/cobol.sh"
require_db

T_PASS=0; T_FAIL=0; T_TOTAL=0
# shellcheck disable=SC1091
. "$ROOT/tests/lib/assert.sh"

db_seed
db_exec "DELETE FROM users WHERE email LIKE 'authshell%@test.com';"

# RFC 6238 TOTP (SHA1, 30s, 6 digits) from stdlib only; prints current and
# previous window codes so a window rollover mid-suite cannot flake.
totp_now() {
    python3 -c "import hmac,hashlib,struct,time,base64,sys
s=base64.b32decode(sys.argv[1])
for t in (int(time.time())//30, int(time.time())//30-1):
    c=struct.pack('>Q',t)
    h=hmac.new(s,c,hashlib.sha1).digest()
    o=h[19]&0x0F
    print('%06d'%((struct.unpack('>I',h[o:o+4])[0]&0x7fffffff)%1000000))" "$1"
}
mfa_confirm() {
    local email="$1" secret="$2" out code
    for code in $(totp_now "$secret"); do
        out="$(run_cobol "MFA_ENROLL_CONFIRM|${email}|${code}|${email}")"
        case "$out" in SUCCESS*) printf '%s' "$out"; return 0;; esac
    done
    printf '%s' "$out"
    return 0
}
mfa_code() {
    totp_now "$1" | head -1
}

A="authshellA@test.com"
B="authshellB@test.com"

# Signup -> verify -> login happy path.
assert_match "REQUEST_SIGNUP ok" "$(run_cobol "REQUEST_SIGNUP|${A}|Passw0rd!|Auth Shell|1990-01-01")" "SUCCESS\|USER_CREATED"
assert_match "duplicate signup neutral (anti-enumeration)" "$(run_cobol "REQUEST_SIGNUP|${A}|Passw0rd!|Auth Shell|1990-01-01")" "SUCCESS\|USER_CREATED"
code="$(db_query "SELECT code FROM verification_logs WHERE email='${A}' AND is_used=0 ORDER BY id DESC LIMIT 1;")"
assert_match "signup code stored" "$code" "^[0-9]+$"
assert_match "VERIFY_EMAIL ok" "$(run_cobol "VERIFY_EMAIL|${A}|${code}")" "SUCCESS\|EMAIL_VERIFIED"
assert_match "AUTH_LOGIN ok" "$(run_cobol "AUTH_LOGIN|${A}|Passw0rd!|")" "SUCCESS\|LOGIN_OK"
assert_match "login wrong password" "$(run_cobol "AUTH_LOGIN|${A}|Wrongpass1!|")" "ERROR\|INVALID_CREDENTIALS"

# Resend + forgot/reset flow on a second user.
assert_match "second SIGNUP ok" "$(run_cobol "REQUEST_SIGNUP|${B}|Passw0rd!|Auth Bee|1991-02-02")" "SUCCESS\|USER_CREATED"
assert_match "RESEND_VERIFICATION ok" "$(run_cobol "RESEND_VERIFICATION|${B}")" "SUCCESS\|"
assert_match "FORGOT_PASSWORD ok" "$(run_cobol "FORGOT_PASSWORD|${B}")" "SUCCESS\|"
rcode="$(db_query "SELECT code FROM verification_logs WHERE email='${B}' AND is_used=0 ORDER BY id DESC LIMIT 1;")"
assert_match "RESET_PASSWORD ok" "$(run_cobol "RESET_PASSWORD|${B}|${rcode}|Newpass1!")" "SUCCESS\|"
bcode="$(db_query "SELECT code FROM verification_logs WHERE email='${B}' AND is_used=0 ORDER BY id DESC LIMIT 1;")"
assert_match "VERIFY_EMAIL ok (B)" "$(run_cobol "VERIFY_EMAIL|${B}|${bcode}")" "SUCCESS\|EMAIL_VERIFIED"
assert_match "login with new password" "$(run_cobol "AUTH_LOGIN|${B}|Newpass1!|")" "SUCCESS\|LOGIN_OK"

# Password change + re-auth proof.
assert_match "CHANGE_PASSWORD ok" "$(run_cobol "CHANGE_PASSWORD|${A}|Passw0rd!|Changed1!|${A}")" "SUCCESS\|"
assert_match "login with changed password" "$(run_cobol "AUTH_LOGIN|${A}|Changed1!|")" "SUCCESS\|LOGIN_OK"
assert_match "VERIFY_REAUTH ok" "$(run_cobol "VERIFY_REAUTH|${A}|Changed1!|")" "SUCCESS\|"

# Full MFA lifecycle with real TOTP codes.
secret="$(run_cobol "MFA_ENROLL_BEGIN|${A}|${A}" | awk -F'|' '{print $3}')"
assert_match "enroll secret issued" "$secret" "^[A-Z0-9]+$"
assert_match "MFA_ENROLL_CONFIRM ok" "$(mfa_confirm "$A" "$secret")" "SUCCESS\|MFA_ENABLED"
assert_match "login without MFA code refused" "$(run_cobol "AUTH_LOGIN|${A}|Changed1!|")" "ERROR\|MFA_REQUIRED"
assert_match "login with MFA code" "$(run_cobol "AUTH_LOGIN|${A}|Changed1!|$(mfa_code "$secret")")" "SUCCESS\|LOGIN_OK"
assert_match "MFA_BACKUP_CODES ok" "$(run_cobol "MFA_BACKUP_CODES|${A}|${A}")" "SUCCESS\|"
assert_match "MFA_DISABLE ok" "$(run_cobol "MFA_DISABLE|${A}|$(mfa_code "$secret")|${A}")" "SUCCESS\|MFA_DISABLED"
assert_match "login works after disable" "$(run_cobol "AUTH_LOGIN|${A}|Changed1!|")" "SUCCESS\|LOGIN_OK"

# MFA recovery request -> verify -> admin approve/reject.
assert_match "REQUEST_MFA_RECOVERY ok" "$(run_cobol "REQUEST_MFA_RECOVERY|${B}|Newpass1!")" "SUCCESS\|"
reccode="$(db_query "SELECT code FROM verification_logs WHERE email='${B}' AND is_used=0 ORDER BY id DESC LIMIT 1;")"
assert_match "VERIFY_MFA_RECOVERY ok" "$(run_cobol "VERIFY_MFA_RECOVERY|${B}|${reccode}")" "SUCCESS\|"
recid="$(db_query "SELECT request_id FROM mfa_recovery_requests WHERE user_id=(SELECT id FROM users WHERE email='${B}') ORDER BY request_id DESC LIMIT 1;")"
assert_match "recovery row present" "$recid" "^[0-9]+$"
assert_match "LIST_MFA_RECOVERY ok" "$(run_cobol "LIST_MFA_RECOVERY|admin@test.com|||50|0")" "SUCCESS\|"
assert_match "APPROVE_MFA_RECOVERY ok" "$(run_cobol "APPROVE_MFA_RECOVERY|${recid}|admin@test.com")" "SUCCESS\|"
assert_match "REQUEST_MFA_RECOVERY again" "$(run_cobol "REQUEST_MFA_RECOVERY|${B}|Newpass1!")" "SUCCESS\|"
recid2="$(db_query "SELECT request_id FROM mfa_recovery_requests WHERE user_id=(SELECT id FROM users WHERE email='${B}') ORDER BY request_id DESC LIMIT 1;")"
assert_match "REJECT_MFA_RECOVERY ok" "$(run_cobol "REJECT_MFA_RECOVERY|${recid2}|admin@test.com")" "SUCCESS\|"

# Sessions: store two families directly (AUTH_LOGIN does not mint refresh
# rows; the gateway does that via STORE_SESSION), then revoke selectively.
assert_match "STORE_SESSION ok (fam-a)" "$(run_cobol "STORE_SESSION|shell-jti-a|${B}|7|shell-fam-a|test-ua|127.0.0.1")" "SUCCESS\|SESSION_STORED"
assert_match "STORE_SESSION ok (fam-b)" "$(run_cobol "STORE_SESSION|shell-jti-b|${B}|7|shell-fam-b|test-ua|127.0.0.1")" "SUCCESS\|SESSION_STORED"
assert_match "LIST_SESSIONS ok" "$(run_cobol "LIST_SESSIONS|${B}|${B}|")" "SUCCESS\|SESSIONS\|"
assert_match "sessions listed" "$(run_cobol "LIST_SESSIONS|${B}|${B}|")" "shell-jti-a"
assert_match "REVOKE_USER_SESSION ok" "$(run_cobol "REVOKE_USER_SESSION|${B}|${B}|shell-jti-a")" "SUCCESS\|"
assert_match "session revoked" "$(db_query "SELECT revoked FROM refresh_sessions WHERE jti='shell-jti-a';")" "^1$"
assert_match "REVOKE_OTHER_DEVICES ok" "$(run_cobol "REVOKE_OTHER_DEVICES|${B}|${B}|shell-fam-b")" "SUCCESS\|OTHER_SESSIONS_REVOKED"
assert_match "other family intact" "$(db_query "SELECT revoked FROM refresh_sessions WHERE jti='shell-jti-b';")" "^0$"
assert_match "REVOKE_ALL_SESSIONS ok" "$(run_cobol "REVOKE_ALL_SESSIONS|${B}|${B}")" "SUCCESS\|"
assert_match "all revoked" "$(db_query "SELECT COUNT(*) FROM refresh_sessions WHERE email='${B}' AND revoked=0;")" "^0$"
db_exec "DELETE FROM refresh_sessions WHERE email='${B}'; DELETE FROM refresh_families WHERE email='${B}';"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
