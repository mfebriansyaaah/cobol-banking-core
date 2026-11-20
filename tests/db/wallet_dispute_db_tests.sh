#!/usr/bin/env bash
# Wallet disputes (PR-5b): open/note/ack/resolve lifecycle + guards.
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
U="wdisp@test.com"
db_exec "DELETE FROM dispute_cases WHERE user_id IN (SELECT id FROM users WHERE email='${U}');"
db_exec "DELETE FROM verification_logs WHERE email='${U}';"
db_exec "DELETE FROM users WHERE email='${U}';"
run_cobol "REQUEST_SIGNUP|${U}|Passw0rd!|Disp Test|1990-01-01" >/dev/null
code="$(db_query "SELECT code FROM verification_logs WHERE email='${U}' AND is_used=0 ORDER BY id DESC LIMIT 1;")"
run_cobol "VERIFY_EMAIL|${U}|${code}" >/dev/null

open_out="$(run_cobol "OPEN_DISPUTE|${U}|${U}|Late delivery|Never arrived|")"
assert_match "open ok" "$open_out" "SUCCESS\|"
did="$(db_query "SELECT case_id FROM dispute_cases WHERE user_id=(SELECT id FROM users WHERE email='${U}') ORDER BY case_id DESC LIMIT 1;")"
assert_match "case persisted" "$did" "^[0-9]+$"
assert_match "initial state" "$(db_query "SELECT state FROM dispute_cases WHERE case_id=${did};")" "^OPEN$"
assert_match "list ok" "$(run_cobol "LIST_DISPUTES|${A}|${U}||50|0|")" "${did}"
assert_match "get ok" "$(run_cobol "GET_DISPUTE|${did}|${U}||||")" "SUCCESS\|"
assert_match "note ok" "$(run_cobol "ADD_DISPUTE_NOTE|${did}|${U}|Still waiting|||")" "SUCCESS\|"
assert_match "ack ok" "$(run_cobol "ACK_DISPUTE|${did}|${A}||||")" "SUCCESS\|"
assert_match "ack persisted" "$(db_query "SELECT state FROM dispute_cases WHERE case_id=${did};")" "^ACKNOWLEDGED$"
assert_match "resolve ok" "$(run_cobol "RESOLVE_DISPUTE|${did}|${A}|Refunded|||")" "SUCCESS\|"
assert_match "resolved persisted" "$(db_query "SELECT state FROM dispute_cases WHERE case_id=${did};")" "^RESOLVED$"
assert_match "double resolve refused" "$(run_cobol "RESOLVE_DISPUTE|${did}|${A}|Again|||")" "ERROR\|INVALID_STATUS"
assert_match "foreign read refused" "$(run_cobol "GET_DISPUTE|${did}|sender@test.com||||")" "ERROR\|FORBIDDEN"

db_exec "DELETE FROM dispute_cases WHERE user_id IN (SELECT id FROM users WHERE email='${U}');"
db_exec "DELETE FROM verification_logs WHERE email='${U}';"
db_exec "DELETE FROM users WHERE email='${U}';"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
