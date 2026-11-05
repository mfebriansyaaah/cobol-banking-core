#!/usr/bin/env bash
# Payment policy + instruction + loyalty shell coverage via run_cobol.
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

# Payment policy + profile lifecycle (idempotent upserts).
assert_match "PAY_POLICY_SET ok" "$(run_cobol "PAY_POLICY_SET|USD|1000.00,500.00,10,100.00,50.00|1|||${A}")" "SUCCESS\|"
assert_match "PAY_POLICY_LIST ok" "$(run_cobol "PAY_POLICY_LIST|50|0|USD|||${A}")" "SUCCESS\|"
assert_match "policy listed" "$(run_cobol "PAY_POLICY_LIST|50|0|USD|||${A}")" "USD"
assert_match "PAY_PROFILE_SET ok" "$(run_cobol "PAY_PROFILE_SET|${S}|USD|100.00,50.00,5,10.00,10.00|1||${A}")" "SUCCESS\|"
assert_match "PAY_PROFILE_LIST ok" "$(run_cobol "PAY_PROFILE_LIST|${S}|50|0|||${A}")" "SUCCESS\|"
assert_match "PAY_DAILY_USAGE ok" "$(run_cobol "PAY_DAILY_USAGE|${S}|USD||||${A}")" "SUCCESS\|"
assert_match "PAY_CHECK ok" "$(run_cobol "PAY_CHECK|${S}|USD|5.00|||${A}")" "SUCCESS\|PAY_CHECK"

# Standing instruction A: read paths, pause, resume, cancel.
P="PIC-SHELL-A"
db_exec "DELETE FROM payment_instruction WHERE instruction_code='${P}';"
assert_match "PIC_CREATE ok" "$(run_cobol "PIC_CREATE|${P}|${S}|${R}|5.00,USD|ONCE,2026-06-01,2026-06-01|${A}")" "SUCCESS\|PIC_CREATED"
assert_match "PIC_GET ok" "$(run_cobol "PIC_GET|${P}|||||${A}")" "SUCCESS\|PIC_INSTRUCTION"
assert_match "PIC_LIST ok" "$(run_cobol "PIC_LIST||50|0|||${A}")" "SUCCESS\|"
assert_match "PIC_DUE ok" "$(run_cobol "PIC_DUE|2026-12-31|50||||${A}")" "SUCCESS\|"
assert_match "PIC_HISTORY ok" "$(run_cobol "PIC_HISTORY|${P}|50|0|||${A}")" "SUCCESS\|"
assert_match "PIC_PAUSE ok" "$(run_cobol "PIC_PAUSE|${P}|||||${A}")" "SUCCESS\|PIC_PAUSED"
assert_match "PIC_RESUME verdict" "$(run_cobol "PIC_RESUME|${P}|||||${A}")" "SUCCESS\|PIC_RESUMED|ERROR\|"
assert_match "PIC_CANCEL ok" "$(run_cobol "PIC_CANCEL|${P}|||||${A}")" "SUCCESS\|PIC_CANCELLED"

# Standing instruction B: execute path (due date in the past).
Q="PIC-SHELL-B"
db_exec "DELETE FROM payment_instruction WHERE instruction_code='${Q}';"
assert_match "PIC_CREATE ok (B)" "$(run_cobol "PIC_CREATE|${Q}|${S}|${R}|1.00,USD|ONCE,2026-06-01,2026-06-01|${A}")" "SUCCESS\|PIC_CREATED"
assert_match "PIC_EXECUTE verdict" "$(run_cobol "PIC_EXECUTE|${Q}|||||${A}")" "SUCCESS\|PIC_EXECUTED|ERROR\|"
run_cobol "PIC_CANCEL|${Q}|||||${A}" >/dev/null

# Loyalty program lifecycle.
assert_match "LOY_CREATE ok" "$(run_cobol "LOY_CREATE|LOY-SHELL|Shell Prog|1:1:USD|2026-01-01:2026-12-31|STANDARD|${A}")" "SUCCESS\|LOY_CREATE"
assert_match "LOY_LIST ok" "$(run_cobol "LOY_LIST|DRAFT||50|0||${A}")" "SUCCESS\|LOY_LIST"
assert_match "program listed" "$(run_cobol "LOY_LIST|DRAFT||50|0||${A}")" "LOY-SHELL"

assert_match "non-admin refused" "$(run_cobol "PIC_LIST||50|0|||sender@test.com")" "ERROR\|FORBIDDEN"

db_exec "DELETE FROM payment_instruction WHERE instruction_code='${P}' OR instruction_code='${Q}';"
db_exec "DELETE FROM loyalty_member WHERE program_id IN (SELECT id FROM loyalty_program WHERE program_code='LOY-SHELL');"
db_exec "DELETE FROM loyalty_program WHERE program_code='LOY-SHELL';"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
