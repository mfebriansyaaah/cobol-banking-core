#!/usr/bin/env bash
# Payment instructions (PR-4b): create/read/pause/resume/cancel lifecycle.
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
S="sender@test.com"
R="receiver@test.com"
P="PIC-D1"
db_exec "DELETE FROM payment_instruction WHERE instruction_code='${P}';"

assert_match "create ok" "$(run_cobol "PIC_CREATE|${P}|${S}|${R}|5.00,USD|ONCE,2026-06-01,2027-06-01|${A}")" "SUCCESS\|PIC_CREATED"
assert_match "state persisted" "$(db_query "SELECT status FROM payment_instruction WHERE instruction_code='${P}';")" "^ACTIVE$"
assert_match "get ok" "$(run_cobol "PIC_GET|${P}|||||${A}")" "SUCCESS\|PIC_INSTRUCTION"
assert_match "list ok" "$(run_cobol "PIC_LIST||50|0|||${A}")" "${P}"
assert_match "due list ok" "$(run_cobol "PIC_DUE|2026-12-31|50||||${A}")" "SUCCESS\|"
assert_match "history ok" "$(run_cobol "PIC_HISTORY|${P}|50|0|||${A}")" "SUCCESS\|"
assert_match "pause ok" "$(run_cobol "PIC_PAUSE|${P}|||||${A}")" "SUCCESS\|PIC_PAUSED"
assert_match "paused persisted" "$(db_query "SELECT status FROM payment_instruction WHERE instruction_code='${P}';")" "^PAUSED$"
assert_match "resume ok" "$(run_cobol "PIC_RESUME|${P}|||||${A}")" "SUCCESS\|PIC_RESUMED"
assert_match "cancel ok" "$(run_cobol "PIC_CANCEL|${P}|||||${A}")" "SUCCESS\|PIC_CANCELLED"
assert_match "cancelled persisted" "$(db_query "SELECT status FROM payment_instruction WHERE instruction_code='${P}';")" "^CANCELLED$"

assert_match "duplicate rejected" "$(run_cobol "PIC_CREATE|${P}|${S}|${R}|5.00,USD|ONCE,2026-06-01,2027-06-01|${A}")" "ERROR\|DUPLICATE"
assert_match "bad frequency rejected" "$(run_cobol "PIC_CREATE|${P}-X|${S}|${R}|5.00,USD|YEARLY,2026-06-01,|${A}")" "ERROR\|INVALID_INPUT"
assert_match "non-admin refused" "$(run_cobol "PIC_LIST||50|0|||sender@test.com")" "ERROR\|FORBIDDEN"

db_exec "DELETE FROM payment_instruction WHERE instruction_code='${P}';"
db_exec "DELETE FROM payment_instruction WHERE instruction_code='${P}-X';"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
