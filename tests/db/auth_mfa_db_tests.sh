#!/usr/bin/env bash
# MFA lifecycle (PR-5a): enroll begin/confirm, backup codes, disable.
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
U="amfa@test.com"
db_exec "DELETE FROM mfa_backup_codes WHERE user_id IN (SELECT id FROM users WHERE email='${U}');"
db_exec "DELETE FROM verification_logs WHERE email='${U}';"
db_exec "DELETE FROM notification_outbox WHERE recipient='${U}';"
db_exec "DELETE FROM users WHERE email='${U}';"
run_cobol "REQUEST_SIGNUP|${U}|Passw0rd!|MFA Test|1990-01-01" >/dev/null
code="$(db_query "SELECT code FROM verification_logs WHERE email='${U}' AND is_used=0 ORDER BY id DESC LIMIT 1;")"
run_cobol "VERIFY_EMAIL|${U}|${code}" >/dev/null

totp_now() {
    python3 -c "import hmac,hashlib,struct,time,base64,sys
s=base64.b32decode(sys.argv[1])
c=struct.pack('>Q',int(time.time())//30)
h=hmac.new(s,c,hashlib.sha1).digest()
o=h[19]&0x0F
print('%06d'%((struct.unpack('>I',h[o:o+4])[0]&0x7fffffff)%1000000))" "$1"
}

begin_out="$(run_cobol "MFA_ENROLL_BEGIN|${U}|${U}||||")"
assert_match "enroll begin ok" "$begin_out" "SUCCESS\|MFA_SECRET"
sec="$(printf '%s' "$begin_out" | awk -F'|' '{print $3}')"
assert_match "secret shape" "$sec" "^[A-Z0-9]+$"
assert_match "owner-only refused" "$(run_cobol "MFA_ENROLL_BEGIN|${U}|sender@test.com||||")" "ERROR\|FORBIDDEN"

confirmed=""
for t in $(totp_now "$sec"); do
    confirmed="$(run_cobol "MFA_ENROLL_CONFIRM|${U}|${t}|${U}|||")"
    case "$confirmed" in SUCCESS*) break;; esac
done
assert_match "enroll confirmed" "$confirmed" "SUCCESS\|MFA_ENABLED"
assert_match "mfa enabled persisted" "$(db_query "SELECT mfa_enabled FROM users WHERE email='${U}';")" "^1$"

codes="$(run_cobol "MFA_BACKUP_CODES|${U}|${U}||||")"
assert_match "backup codes issued" "$codes" "SUCCESS\|BACKUP_CODES"
assert_match "backup rows persisted" "$(db_query "SELECT COUNT(*) FROM mfa_backup_codes WHERE user_id=(SELECT id FROM users WHERE email='${U}');")" "^8$"

disabled=""
for t in $(totp_now "$sec"); do
    disabled="$(run_cobol "MFA_DISABLE|${U}|${t}|${U}|||")"
    case "$disabled" in SUCCESS*) break;; esac
done
assert_match "disable ok" "$disabled" "SUCCESS\|MFA_DISABLED"
assert_match "mfa disabled persisted" "$(db_query "SELECT mfa_enabled FROM users WHERE email='${U}';")" "^0$"
assert_match "backup codes burned" "$(db_query "SELECT COUNT(*) FROM mfa_backup_codes WHERE user_id=(SELECT id FROM users WHERE email='${U}');")" "^0$"
assert_match "non-owner disable refused" "$(run_cobol "MFA_DISABLE|${U}|000000|sender@test.com|||")" "ERROR\|FORBIDDEN"

db_exec "DELETE FROM mfa_backup_codes WHERE user_id IN (SELECT id FROM users WHERE email='${U}');"
db_exec "DELETE FROM verification_logs WHERE email='${U}';"
db_exec "DELETE FROM notification_outbox WHERE recipient='${U}';"
db_exec "DELETE FROM users WHERE email='${U}';"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
