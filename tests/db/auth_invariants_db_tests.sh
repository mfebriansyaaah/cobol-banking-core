#!/usr/bin/env bash
# Auth invariants (PR-041): lockout, rotation/reuse, expiry, family limits,
# step-up policy, backup single-use, role/permission matrix. Dedicated
# fixtures; global policy rows owned pre+post. Green twice required.
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
A="admin@test.com"
L="ainvL@test.com"
M="ainvM@test.com"

db_exec "DELETE FROM refresh_sessions WHERE email IN ('${L}','${M}');"
db_exec "DELETE FROM refresh_families WHERE email IN ('${L}','${M}');"
db_exec "DELETE FROM mfa_backup_codes WHERE user_id IN (SELECT id FROM users WHERE email='${M}');"
db_exec "DELETE FROM users WHERE email IN ('${L}','${M}');"
for U in "$L" "$M"; do
    run_cobol "REQUEST_SIGNUP|${U}|Passw0rd!|A Inv|1990-01-01" >/dev/null
    code="$(db_query "SELECT code FROM verification_logs WHERE email='${U}' AND is_used=0 ORDER BY id DESC LIMIT 1;")"
    run_cobol "VERIFY_EMAIL|${U}|${code}" >/dev/null
done

# 1. Lockout: 3 failures arm it, correct password refused, unlock resets.
run_cobol "AUTH_LOGIN|${L}|Wrong1!x|" >/dev/null
run_cobol "AUTH_LOGIN|${L}|Wrong1!x|" >/dev/null
assert_match "third failure locks" "$(run_cobol "AUTH_LOGIN|${L}|Wrong1!x|")" "ERROR\|ACCOUNT_LOCKED|ERROR\|INVALID_CREDENTIALS"
assert_match "failures counted" "$(db_query "SELECT failed_logins FROM users WHERE email='${L}';")" "^3$"
assert_match "locked flag set" "$(db_query "SELECT locked_until IS NOT NULL FROM users WHERE email='${L}';")" "^1$"
assert_match "correct refused while locked" "$(run_cobol "AUTH_LOGIN|${L}|Passw0rd!|")" "ERROR\|ACCOUNT_LOCKED"
assert_match "UNLOCK ok" "$(run_cobol "UNLOCK_USER|${L}|${A}")" "SUCCESS\|"
assert_match "login works after unlock" "$(run_cobol "AUTH_LOGIN|${L}|Passw0rd!|")" "SUCCESS\|LOGIN_OK"
assert_match "failures reset" "$(db_query "SELECT failed_logins FROM users WHERE email='${L}';")" "^0$"

# 2. Rotation: consume once wins; replay is reuse and kills the family.
assert_match "STORE ok (r1)" "$(run_cobol "STORE_SESSION|ainv-j1|${L}|7|ainv-f1|ua|127.0.0.1")" "SUCCESS\|SESSION_STORED"
assert_match "CONSUME ok" "$(run_cobol "CONSUME_SESSION|ainv-j1|||||${A}")" "SUCCESS\|SESSION_CONSUMED"
assert_match "STORE ok (r2 same family)" "$(run_cobol "STORE_SESSION|ainv-j2|${L}|7|ainv-f1|ua|127.0.0.1")" "SUCCESS\|SESSION_STORED"
tv_before="$(db_query "SELECT token_version FROM users WHERE email='${L}';")"
assert_match "replay is reuse" "$(run_cobol "CONSUME_SESSION|ainv-j1|||||${A}")" "ERROR\|SESSION_REUSED"
assert_match "family revoked" "$(db_query "SELECT COUNT(*) FROM refresh_sessions WHERE family='ainv-f1' AND revoked=0;")" "^0$"
assert_match "token version bumped" "$(db_query "SELECT token_version FROM users WHERE email='${L}';")" "^$((tv_before + 1))$"

# 3. Expiry: aged session refuses consume.
assert_match "STORE ok (exp)" "$(run_cobol "STORE_SESSION|ainv-j3|${L}|7|ainv-f3|ua|127.0.0.1")" "SUCCESS\|SESSION_STORED"
db_exec "UPDATE refresh_sessions SET expires_at=DATE_SUB(NOW(), INTERVAL 1 DAY) WHERE jti='ainv-j3';"
assert_match "expired refused" "$(run_cobol "CONSUME_SESSION|ainv-j3|||||${A}")" "ERROR\|SESSION_EXPIRED"
assert_match "missing refused" "$(run_cobol "CONSUME_SESSION|ainv-nope|||||${A}")" "ERROR\|SESSION_NOT_FOUND"

# 4. Family limits: rotations past the cap expire the family.
assert_match "STORE ok (fam)" "$(run_cobol "STORE_SESSION|ainv-j4|${L}|7|ainv-f4|ua|127.0.0.1")" "SUCCESS\|SESSION_STORED"
assert_match "CONSUME ok (fam)" "$(run_cobol "CONSUME_SESSION|ainv-j4|||||${A}")" "SUCCESS\|SESSION_CONSUMED"
db_exec "UPDATE refresh_families SET rotations=101 WHERE family='ainv-f4';"
assert_match "STORE ok (fam2)" "$(run_cobol "STORE_SESSION|ainv-j5|${L}|7|ainv-f4|ua|127.0.0.1")" "SUCCESS\|SESSION_STORED"
assert_match "over-rotated refused" "$(run_cobol "CONSUME_SESSION|ainv-j5|||||${A}")" "ERROR\|SESSION_FAMILY_EXPIRED"
assert_match "family revoked" "$(db_query "SELECT COUNT(*) FROM refresh_sessions WHERE family='ainv-f4' AND revoked=0;")" "^0$"

# 5. Step-up policy: unknown action needs nothing; gated action scales by amount.
assert_match "unknown action free" "$(run_cobol "STEP_UP_REQUIRED|${L}|NOPE_ACTION|999.00|||${A}")" "SUCCESS\|STEP_UP_NOT_REQUIRED"
assert_match "zero-min always required" "$(run_cobol "STEP_UP_REQUIRED|${L}|MFA_DISABLE|0|||${A}")" "SUCCESS\|STEP_UP_REQUIRED"
db_exec "INSERT INTO step_up_policy (action, min_amount, enabled) VALUES ('TRANSFER', 100.00, 1) ON DUPLICATE KEY UPDATE min_amount=100.00, enabled=1;"
assert_match "below threshold free" "$(run_cobol "STEP_UP_REQUIRED|${L}|TRANSFER|50.00|||${A}")" "SUCCESS\|STEP_UP_NOT_REQUIRED"
assert_match "above threshold required" "$(run_cobol "STEP_UP_REQUIRED|${L}|TRANSFER|500.00|||${A}")" "SUCCESS\|STEP_UP_REQUIRED"
db_exec "DELETE FROM step_up_policy WHERE action='TRANSFER';"
assert_match "VERIFY_REAUTH ok" "$(run_cobol "VERIFY_REAUTH|${L}|Passw0rd!|")" "SUCCESS\|"

# 6. Backup codes: single use, then burned.
totp_now() {
    python3 -c "import hmac,hashlib,struct,time,base64,sys
s=base64.b32decode(sys.argv[1])
c=struct.pack('>Q',int(time.time())//30)
h=hmac.new(s,c,hashlib.sha1).digest()
o=h[19]&0x0F
print('%06d'%((struct.unpack('>I',h[o:o+4])[0]&0x7fffffff)%1000000))" "$1"
}
sec="$(run_cobol "MFA_ENROLL_BEGIN|${M}|${M}" | awk -F'|' '{print $3}')"
assert_match "enroll secret" "$sec" "^[A-Z0-9]+$"
enrolled=""
for t in $(totp_now "$sec"); do
    enrolled="$(run_cobol "MFA_ENROLL_CONFIRM|${M}|${t}|${M}")"
    case "$enrolled" in SUCCESS*) break;; esac
done
assert_match "MFA enrolled" "$enrolled" "SUCCESS\|MFA_ENABLED"
codes="$(run_cobol "MFA_BACKUP_CODES|${M}|${M}" | awk -F'|' '{print $3}')"
code1="$(printf '%s' "$codes" | cut -d, -f1)"
assert_match "backup code shape" "$code1" "^[0-9]{10}$"
assert_match "backup login ok" "$(run_cobol "AUTH_LOGIN|${M}|Passw0rd!|${code1}")" "SUCCESS\|LOGIN_OK"
assert_match "backup burned" "$(run_cobol "AUTH_LOGIN|${M}|Passw0rd!|${code1}")" "ERROR\|INVALID_MFA"

# 7. Role/permission matrix: self, manager+admin reads, permission grants.
assert_match "self role read" "$(run_cobol "CHECK_ROLE|${L}|USER|${L}")" "SUCCESS\|"
assert_match "manager cannot grant" "$(run_cobol "CHECK_PERMISSION|${L}|RECONCILE_READ|||${L}")" "ERROR\|PERMISSION_DENIED"
assert_match "admin granted" "$(run_cobol "CHECK_PERMISSION|${A}|RECONCILE_READ|||${A}")" "SUCCESS\|PERMISSION_OK"
assert_match "user denied" "$(run_cobol "CHECK_PERMISSION|${L}|RECONCILE_READ|||${A}")" "ERROR\|PERMISSION_DENIED"

db_exec "DELETE FROM refresh_sessions WHERE email IN ('${L}','${M}');"
db_exec "DELETE FROM refresh_families WHERE email IN ('${L}','${M}');"
db_exec "DELETE FROM mfa_backup_codes WHERE user_id IN (SELECT id FROM users WHERE email='${M}');"
db_exec "DELETE FROM users WHERE email IN ('${L}','${M}');"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
