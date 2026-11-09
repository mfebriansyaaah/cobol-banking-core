#!/usr/bin/env bash
# Auth races (toward auth 10/10): true parallel requests over separate DB
# connections (COBOL_TEST_SERVE=0, one process per call). A single-use
# backup code logs in exactly once; a refresh session is consumed exactly
# once (loser is reuse, family dies); concurrent failures count exactly.
# Green twice required.
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

export COBOL_TEST_SERVE=0
db_seed
A="admin@test.com"
WA="arcA@test.com"
WB="arcB@test.com"

cleanup_fixture() {
    db_exec "DELETE FROM mfa_backup_codes WHERE user_id IN (SELECT id FROM users WHERE email IN ('${WA}','${WB}'));"
    db_exec "DELETE FROM refresh_sessions WHERE email IN ('${WA}','${WB}');"
    db_exec "DELETE FROM refresh_families WHERE email IN ('${WA}','${WB}');"
    db_exec "DELETE FROM users WHERE email IN ('${WA}','${WB}');"
}
cleanup_fixture
for U in "$WA" "$WB"; do
    run_cobol "REQUEST_SIGNUP|${U}|Passw0rd!|Arc Race|1990-01-01" >/dev/null
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
CODE1="$(printf '%s' "$CODES" | cut -d, -f1)"
CODE2="$(printf '%s' "$CODES" | cut -d, -f2)"
TMPD="$(mktemp -d "${TMPDIR:-/tmp}/arc.XXXXXX")"
trap 'rm -rf "$TMPD"' EXIT

# 1-6. Double burn: exactly one login, code dead afterwards.
run_cobol "AUTH_LOGIN|${WA}|Passw0rd!|${CODE1}" >"$TMPD/burnA.out" 2>&1 &
run_cobol "AUTH_LOGIN|${WA}|Passw0rd!|${CODE1}" >"$TMPD/burnB.out" 2>&1 &
wait
assert_match "exactly one login wins" "$(grep -o "SUCCESS|LOGIN_OK" "$TMPD"/burn*.out | wc -l | tr -d ' ')" "^1$"
assert_match "loser refused" "$(cat "$TMPD"/burn*.out)" "ERROR\|INVALID_MFA"
assert_match "code burned once" "$(db_query "SELECT COUNT(*) FROM mfa_backup_codes WHERE user_id=(SELECT id FROM users WHERE email='${WA}') AND used=1;")" "^1$"
assert_match "burned code dead" "$(run_cobol "AUTH_LOGIN|${WA}|Passw0rd!|${CODE1}")" "ERROR\|INVALID_MFA"
assert_match "other codes alive" "$(db_query "SELECT COUNT(*) FROM mfa_backup_codes WHERE user_id=(SELECT id FROM users WHERE email='${WA}') AND used=0;")" "^7$"
assert_match "fresh code works" "$(run_cobol "AUTH_LOGIN|${WA}|Passw0rd!|${CODE2}")" "SUCCESS\|LOGIN_OK"

# 7-13. Double consume: exactly one wins, loser is reuse, family dies.
run_cobol "STORE_SESSION|arc-j1|${WB}|7|arc-f1|ua|127.0.0.1" >/dev/null
run_cobol "CONSUME_SESSION|arc-j1|||||${A}" >"$TMPD/conA.out" 2>&1 &
run_cobol "CONSUME_SESSION|arc-j1|||||${A}" >"$TMPD/conB.out" 2>&1 &
wait
assert_match "exactly one consume wins" "$(grep -o "SUCCESS|SESSION_CONSUMED" "$TMPD"/con*.out | wc -l | tr -d ' ')" "^1$"
assert_match "loser is reuse" "$(cat "$TMPD"/con*.out)" "ERROR\|SESSION_REUSED"
assert_match "family revoked" "$(db_query "SELECT COUNT(*) FROM refresh_sessions WHERE family='arc-f1' AND revoked=0;")" "^0$"
assert_match "token version bumped" "$(db_query "SELECT token_version FROM users WHERE email='${WB}';")" "^2$"
assert_match "replay after reuse refused" "$(run_cobol "CONSUME_SESSION|arc-j1|||||${A}")" "ERROR\|SESSION_REUSED"
assert_match "unknown refused" "$(run_cobol "CONSUME_SESSION|arc-nope|||||${A}")" "ERROR\|SESSION_NOT_FOUND"
run_cobol "STORE_SESSION|arc-j9|${WB}|7|arc-f9|ua|127.0.0.1" >/dev/null
db_exec "UPDATE refresh_sessions SET expires_at=DATE_SUB(NOW(),INTERVAL 1 HOUR) WHERE jti='arc-j9';"
assert_match "expired refused" "$(run_cobol "CONSUME_SESSION|arc-j9|||||${A}")" "ERROR\|SESSION_EXPIRED"

# 14-19. Concurrent failures count exactly; lockout trips at three.
db_exec "UPDATE users SET failed_logins=0, locked_until=NULL WHERE email='${WB}';"
for i in 1 2 3 4 5; do
    run_cobol "AUTH_LOGIN|${WB}|Wrong${i}!x|" >"$TMPD/fail-${i}.out" 2>&1 &
done
wait
assert_match "five failures counted" "$(db_query "SELECT failed_logins FROM users WHERE email='${WB}';")" "^5$"
assert_match "locked after three" "$(db_query "SELECT locked_until IS NOT NULL FROM users WHERE email='${WB}';")" "^1$"
assert_match "correct refused while locked" "$(run_cobol "AUTH_LOGIN|${WB}|Passw0rd!|")" "ERROR\|ACCOUNT_LOCKED"
assert_match "unlock ok" "$(run_cobol "UNLOCK_USER|${WB}|${A}")" "SUCCESS\|"
assert_match "login works after unlock" "$(run_cobol "AUTH_LOGIN|${WB}|Passw0rd!|")" "SUCCESS\|LOGIN_OK"
assert_match "failures reset" "$(db_query "SELECT failed_logins FROM users WHERE email='${WB}';")" "^0$"

# 20-23. Fan-out: four parallel correct logins all land (no shared rows).
for i in 1 2 3 4; do
    run_cobol "AUTH_LOGIN|${WB}|Passw0rd!|" >"$TMPD/fan-${i}.out" 2>&1 &
done
wait
assert_match "all four land" "$(grep -o "SUCCESS|LOGIN_OK" "$TMPD"/fan-*.out | wc -l | tr -d ' ')" "^4$"
assert_match "no lockout from successes" "$(db_query "SELECT failed_logins FROM users WHERE email='${WB}';")" "^0$"
assert_match "not locked" "$(db_query "SELECT locked_until IS NULL FROM users WHERE email='${WB}';")" "^1$"
assert_match "successes audited" "$(db_query "SELECT COUNT(*) FROM audit_trail WHERE user_id=(SELECT id FROM users WHERE email='${WB}') AND action='AUTH_LOGIN_SUCCESS';")" "^5$"

cleanup_fixture
print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
