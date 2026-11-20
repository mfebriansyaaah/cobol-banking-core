#!/usr/bin/env bash
# Auth ops (PR-5a): outbox claim/mark/list + audit read/archive guards.
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
W="worker-pr5a"
R="aops@test.com"
db_exec "DELETE FROM notification_outbox WHERE recipient='${R}';"
db_exec "INSERT INTO notification_outbox (recipient, purpose, code, detail, state, created_at) VALUES ('${R}', 'PR5A', '123456', 'auth ops', 'PENDING', '2000-01-01 00:00:00');"
oid="$(db_query "SELECT id FROM notification_outbox WHERE recipient='${R}' ORDER BY id DESC LIMIT 1;")"

assert_match "claim ok" "$(run_cobol "OUTBOX_CLAIM|1|${W}||||")" "SUCCESS\|CLAIMED"
assert_match "claimed state" "$(db_query "SELECT CONCAT(state, ':', claimed_by) FROM notification_outbox WHERE id=${oid};")" "^SENDING:${W}$"
assert_match "mark sent" "$(run_cobol "OUTBOX_MARK|${oid}|SENT||${W}||")" "SUCCESS\|MARKED\|SENT"
assert_match "sent persisted" "$(db_query "SELECT state FROM notification_outbox WHERE id=${oid};")" "^SENT$"
assert_match "list outbox shows row" "$(run_cobol "LIST_OUTBOX|${A}|SENT|50|0||")" "${R}"
assert_match "list outbox non-admin refused" "$(run_cobol "LIST_OUTBOX|sender@test.com||50|0||")" "ERROR\|FORBIDDEN"

assert_match "double mark rejected" "$(run_cobol "OUTBOX_MARK|${oid}|SENT||${W}||")" "ERROR\|UNKNOWN_TRANSACTION"
assert_match "bad claim size rejected" "$(run_cobol "OUTBOX_CLAIM|x|${W}||||")" "ERROR\|INVALID_INPUT"
assert_match "archive zero days rejected" "$(run_cobol "ARCHIVE_AUDIT|0|${A}||||")" "ERROR\|INVALID_INPUT"
assert_match "list audit ok" "$(run_cobol "LIST_AUDIT|${A}|||50|0|")" "SUCCESS\|AUDIT"

db_exec "DELETE FROM notification_outbox WHERE recipient='${R}';"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
