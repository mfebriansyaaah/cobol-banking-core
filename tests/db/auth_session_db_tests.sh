#!/usr/bin/env bash
# Auth session seam tests (maint-08): STORE/CONSUME/LIST/REVOKE/REVOKE_ALL/
# CHECK_TOKEN/GET_TOKEN_VERSION through the auth_session_core split. The
# owner keeps dispatch, guards, and the REVOKE_ALL transaction; the callee
# owns the session/token paragraphs. Covers the passthrough OUT protocol,
# the consume-reuse family kill, and the revoke-all join.
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
U="sesspost@test.com"
V="sessother@test.com"
for E in "$U" "$V"; do
db_exec "DELETE FROM revoked_access_tokens WHERE email='${E}';"
db_exec "DELETE FROM refresh_sessions WHERE email='${E}';"
db_exec "DELETE FROM refresh_families WHERE email='${E}';"
db_exec "DELETE FROM users WHERE email='${E}';"
run_cobol "REQUEST_SIGNUP|${E}|Passw0rd!|Sess Post|1990-01-01" >/dev/null
code="$(db_query "SELECT code FROM verification_logs WHERE email='${E}' AND is_used=0 ORDER BY id DESC LIMIT 1;")"
run_cobol "VERIFY_EMAIL|${E}|${code}" >/dev/null
done

# Store two sessions in one family, then consume-rotate the first.
assert_match "store ok" "$(run_cobol "STORE_SESSION|SJTI-1|${U}|30|SFAM-1|agent|1.2.3.4")" "SUCCESS\|SESSION_STORED"
assert_match "store second ok" "$(run_cobol "STORE_SESSION|SJTI-2|${U}|30|SFAM-1|agent|1.2.3.4")" "SUCCESS\|SESSION_STORED"
assert_match "consume ok" "$(run_cobol "CONSUME_SESSION|SJTI-1|||||")" "SUCCESS\|SESSION_CONSUMED"
assert_match "consume replay kills family" "$(run_cobol "CONSUME_SESSION|SJTI-1|||||")" "ERROR\|SESSION_REUSED"
assert_match "family revoked" "$(db_query "SELECT COUNT(*) FROM refresh_sessions WHERE family='SFAM-1' AND revoked=0;")" "^0$"
assert_match "consume unknown refused" "$(run_cobol "CONSUME_SESSION|SJTI-NOPE|||||")" "ERROR\|SESSION_NOT_FOUND"

# List shows only live sessions; per-user revoke drops one.
assert_match "store third ok" "$(run_cobol "STORE_SESSION|SJTI-3|${U}|30|SFAM-3|agent|1.2.3.4")" "SUCCESS\|SESSION_STORED"
assert_match "list shows live" "$(run_cobol "LIST_SESSIONS|${U}|${U}|||||")" "SUCCESS\|SESSIONS\|.*SJTI-3"
assert_match "revoke one ok" "$(run_cobol "REVOKE_USER_SESSION|${U}|${U}|SJTI-3|||")" "SUCCESS\|SESSION_REVOKED"
assert_match "revoked gone from list" "$(run_cobol "LIST_SESSIONS|${U}|${U}|||||")" "SUCCESS\|SESSIONS\|$"
assert_match "revoke missing refused" "$(run_cobol "REVOKE_USER_SESSION|${U}|${U}|SJTI-NOPE|||")" "ERROR\|SESSION_NOT_FOUND"

# Revoke-all closes every session and bumps the token version (JOIN tx).
assert_match "store fourth ok" "$(run_cobol "STORE_SESSION|SJTI-4|${U}|30|SFAM-4|agent|1.2.3.4")" "SUCCESS\|SESSION_STORED"
v0="$(run_cobol "GET_TOKEN_VERSION|${U}|||||")"
assert_match "token version reads" "$v0" "SUCCESS\|[0-9]+"
assert_match "revoke all ok" "$(run_cobol "REVOKE_ALL_SESSIONS|${U}|${U}||||")" "SUCCESS\|SESSIONS_REVOKED"
assert_match "all sessions dead" "$(db_query "SELECT COUNT(*) FROM refresh_sessions WHERE email='${U}' AND revoked=0;")" "^0$"
v1="$(run_cobol "GET_TOKEN_VERSION|${U}|||||")"
assert_match "token version bumped" "$v1" "SUCCESS\|[0-9]+"
v0n="$(printf '%s' "$v0" | awk -F'|' '{print $2}')"
v1n="$(printf '%s' "$v1" | awk -F'|' '{print $2}')"
if [ "$v1n" -gt "$v0n" ] 2>/dev/null; then bumped=yes; else bumped=no; fi
assert_match "version differs" "$bumped" "^yes$"

# Token check follows the version; deny-listed jti refuses.
ver="$(printf '%s' "$v1" | awk -F'|' '{print $2}')"
assert_match "token valid" "$(run_cobol "CHECK_TOKEN|${U}|${ver}||||")" "SUCCESS\|TOKEN_VALID"
assert_match "stale token refused" "$(run_cobol "CHECK_TOKEN|${U}|0||||")" "ERROR\|TOKEN_REVOKED"
assert_match "revoke token ok" "$(run_cobol "REVOKE_ACCESS_TOKEN|TJTI-9|${U}|3600|||")" "SUCCESS\|TOKEN_REVOKED"
assert_match "denied token refused" "$(run_cobol "CHECK_TOKEN|${U}|${ver}|TJTI-9|||")" "ERROR\|TOKEN_REVOKED"

# Guards stayed owner-side: a stranger may not list or revoke.
assert_match "list by stranger refused" "$(run_cobol "LIST_SESSIONS|${U}|${V}|||||")" "ERROR\|FORBIDDEN"
assert_match "revoke by stranger refused" "$(run_cobol "REVOKE_USER_SESSION|${U}|${V}|SJTI-4|||")" "ERROR\|FORBIDDEN"

db_exec "DELETE FROM revoked_access_tokens WHERE email IN ('${U}','${V}');"
db_exec "DELETE FROM refresh_sessions WHERE email IN ('${U}','${V}');"
db_exec "DELETE FROM refresh_families WHERE email IN ('${U}','${V}');"
db_exec "DELETE FROM users WHERE email IN ('${U}','${V}');"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
