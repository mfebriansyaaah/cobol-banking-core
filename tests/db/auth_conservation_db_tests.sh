#!/usr/bin/env bash
# Auth conservation invariants (auth 10/10, Trek B): fixed script with
# hand-checked end state. Session families account every rotation;
# backup-code inventory always sums to issued; token_version moves only
# on reuse; lockout counters reset exactly; TOTP reuse inside one window
# is pinned accepted (30s window, interception model; single-use factor
# is backup codes). Green twice required.
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
WA="csvA@test.com"
WB="csvB@test.com"

cleanup_fixture() {
    db_exec "DELETE FROM mfa_backup_codes WHERE user_id IN (SELECT id FROM users WHERE email IN ('${WA}','${WB}'));"
    db_exec "DELETE FROM refresh_sessions WHERE email IN ('${WA}','${WB}');"
    db_exec "DELETE FROM refresh_families WHERE email IN ('${WA}','${WB}');"
    db_exec "DELETE FROM users WHERE email IN ('${WA}','${WB}');"
}
cleanup_fixture
for U in "$WA" "$WB"; do
    run_cobol "REQUEST_SIGNUP|${U}|Passw0rd!|Csv User|1990-01-01" >/dev/null
    code="$(db_query "SELECT code FROM verification_logs WHERE email='${U}' AND is_used=0 ORDER BY id DESC LIMIT 1;")"
    run_cobol "VERIFY_EMAIL|${U}|${code}" >/dev/null
done
totp_now() {
    python3 -c "import hmac,hashlib,struct,time,base64,sys
s=base64.b32decode(sys.argv[1])
c=struct.pack('>Q',int(time.time())//30)
h=hmac.new(s,c,hashlib.sha1).digest()
o=h[19]&0x0F
print('%06d'%((struct.unpack('>I',h[o:o+4])[0]&0x7fffffff)%1000000))" "$1"
}
SEC="$(run_cobol "MFA_ENROLL_BEGIN|${WA}|${WA}" | awk -F'|' '{print $3}')"
for t in $(totp_now "$SEC"); do
    ENR="$(run_cobol "MFA_ENROLL_CONFIRM|${WA}|${t}|${WA}")"
    case "$ENR" in SUCCESS*) break;; esac
done
CODES="$(run_cobol "MFA_BACKUP_CODES|${WA}|${WA}" | awk -F'|' '{print $3}')"
TV0="$(db_query "SELECT token_version FROM users WHERE email='${WA}';")"

# 1-8. Session family lifecycle: two rotations accounted exactly.
assert_match "store j1 ok" "$(run_cobol "STORE_SESSION|cs-j1|${WA}|7|cs-f1|ua|127.0.0.1")" "SUCCESS\|SESSION_STORED"
assert_match "consume j1 ok" "$(run_cobol "CONSUME_SESSION|cs-j1|||||${A}")" "SUCCESS\|SESSION_CONSUMED"
assert_match "family row exists" "$(db_query "SELECT COUNT(*) FROM refresh_families WHERE family='cs-f1';")" "^1$"
assert_match "one rotation counted" "$(db_query "SELECT rotations FROM refresh_families WHERE family='cs-f1';")" "^1$"
assert_match "store j2 same family ok" "$(run_cobol "STORE_SESSION|cs-j2|${WA}|7|cs-f1|ua|127.0.0.1")" "SUCCESS\|SESSION_STORED"
assert_match "consume j2 ok" "$(run_cobol "CONSUME_SESSION|cs-j2|||||${A}")" "SUCCESS\|SESSION_CONSUMED"
assert_match "two rotations counted" "$(db_query "SELECT rotations FROM refresh_families WHERE family='cs-f1';")" "^2$"
assert_match "both consumed" "$(db_query "SELECT COUNT(*) FROM refresh_sessions WHERE family='cs-f1' AND revoked=1;")" "^2$"

# 9-14. Reuse kills the family; version bumps exactly once per reuse.
assert_match "store j3 ok" "$(run_cobol "STORE_SESSION|cs-j3|${WA}|7|cs-f1|ua|127.0.0.1")" "SUCCESS\|SESSION_STORED"
assert_match "replay j1 is reuse" "$(run_cobol "CONSUME_SESSION|cs-j1|||||${A}")" "ERROR\|SESSION_REUSED"
assert_match "family dead" "$(db_query "SELECT COUNT(*) FROM refresh_sessions WHERE family='cs-f1' AND revoked=0;")" "^0$"
assert_match "version bumped once" "$(db_query "SELECT token_version FROM users WHERE email='${WA}';")" "$((TV0 + 1))"
assert_match "second replay still reuse" "$(run_cobol "CONSUME_SESSION|cs-j2|||||${A}")" "ERROR\|SESSION_REUSED"
assert_match "version bumped twice total" "$(db_query "SELECT token_version FROM users WHERE email='${WA}';")" "$((TV0 + 2))"

# 15-21. Backup-code inventory: 8 issued, every burn accounted.
assert_match "issued eight" "$(db_query "SELECT COUNT(*) FROM mfa_backup_codes WHERE user_id=(SELECT id FROM users WHERE email='${WA}');")" "^8$"
C1="$(printf '%s' "$CODES" | cut -d, -f1)"
C2="$(printf '%s' "$CODES" | cut -d, -f2)"
assert_match "burn one ok" "$(run_cobol "AUTH_LOGIN|${WA}|Passw0rd!|${C1}")" "SUCCESS\|LOGIN_OK"
assert_match "one used seven left" "$(db_query "SELECT CONCAT(SUM(used=1),'|',SUM(used=0)) FROM mfa_backup_codes WHERE user_id=(SELECT id FROM users WHERE email='${WA}');")" "^1|7$"
assert_match "burn second ok" "$(run_cobol "AUTH_LOGIN|${WA}|Passw0rd!|${C2}")" "SUCCESS\|LOGIN_OK"
assert_match "two used six left" "$(db_query "SELECT CONCAT(SUM(used=1),'|',SUM(used=0)) FROM mfa_backup_codes WHERE user_id=(SELECT id FROM users WHERE email='${WA}');")" "^2|6$"
assert_match "total still eight" "$(db_query "SELECT COUNT(*) FROM mfa_backup_codes WHERE user_id=(SELECT id FROM users WHERE email='${WA}');")" "^8$"

# 22-26. TOTP replay inside one window is accepted (pinned behavior:
# 30s interception window; the single-use guarantee lives on backup
# codes). Start away from the window edge so both logins share a window.
SEC_LEFT=$((30 - $(date +%s) % 30))
if [ "$SEC_LEFT" -lt 8 ]; then sleep "$((SEC_LEFT + 1))"; fi
T="$(totp_now "$SEC")"
assert_match "totp login ok" "$(run_cobol "AUTH_LOGIN|${WA}|Passw0rd!|${T}")" "SUCCESS\|LOGIN_OK"
assert_match "totp replay accepted" "$(run_cobol "AUTH_LOGIN|${WA}|Passw0rd!|${T}")" "SUCCESS\|LOGIN_OK"

# 27-32. Lockout counters exact, reset clean.
db_exec "UPDATE users SET failed_logins=0, locked_until=NULL WHERE email='${WB}';"
run_cobol "AUTH_LOGIN|${WB}|Bad1!x|" >/dev/null
run_cobol "AUTH_LOGIN|${WB}|Bad2!x|" >/dev/null
assert_match "two failures counted" "$(db_query "SELECT failed_logins FROM users WHERE email='${WB}';")" "^2$"
assert_match "not yet locked" "$(db_query "SELECT locked_until IS NULL FROM users WHERE email='${WB}';")" "^1$"
run_cobol "AUTH_LOGIN|${WB}|Bad3!x|" >/dev/null
assert_match "three failures counted" "$(db_query "SELECT failed_logins FROM users WHERE email='${WB}';")" "^3$"
assert_match "locked now" "$(db_query "SELECT locked_until IS NOT NULL FROM users WHERE email='${WB}';")" "^1$"
assert_match "unlock ok" "$(run_cobol "UNLOCK_USER|${WB}|${A}")" "SUCCESS\|"
assert_match "failures reset" "$(db_query "SELECT failed_logins FROM users WHERE email='${WB}';")" "^0$"

cleanup_fixture
print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
