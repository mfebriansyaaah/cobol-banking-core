#!/usr/bin/env bash
# Standing instruction (Wave3) end-to-end DB tests via the COBOL binary.
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
db_reset_standing_instruction

# Create a cost center.
create_out="$(run_cobol "SIN_CREATE|SIN-W3-1|InstrA|PAY|||admin@test.com")"
assert_match "SIN_CREATE ok" "$create_out" "SUCCESS\|SIN_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM standing_instruction WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "SIN_CREATE|SIN-W3-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "SIN_GET ok" "$(run_cobol "SIN_GET|${id}|||||admin@test.com")" "SUCCESS\|SIN_GET\|${id}\|SIN-W3-1"
assert_match "SIN_LIST ok" "$(run_cobol "SIN_LIST|||50|0||admin@test.com")" "SIN-W3-1"

# Allocate.
assert_match "SIN_CALC ok" "$(run_cobol "SIN_CALC|${id}|||||admin@test.com")" "SUCCESS\|SIN_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT executed_amount FROM standing_instruction WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "SIN_DELETE ok" "$(run_cobol "SIN_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|SIN_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM standing_instruction WHERE id=${id};")" "^INACTIVE$"

# Summary and audit.
assert_match "SIN_SUMMARY ok" "$(run_cobol "SIN_SUMMARY||||||admin@test.com")" "SUCCESS\|SIN_SUMMARY"
assert_match "SIN_AUDIT ok" "$(run_cobol "SIN_AUDIT|50|0||||admin@test.com")" "SUCCESS\|SIN_AUDIT"
assert_match "SIN_VALIDATE ok" "$(run_cobol "SIN_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|SIN_VALID"
assert_match "non-admin refused" "$(run_cobol "SIN_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"


# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM standing_instruction WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM standing_instruction_audit WHERE standing_instruction_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "SIN_UPDATE|${id}|InstrA|PAY|||admin@test.com")"
assert_match "SIN_UPDATE ok" "$upd_out" "SUCCESS\\|SIN_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM standing_instruction WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM standing_instruction_audit WHERE standing_instruction_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "SIN_UPDATE|999999|InstrA|PAY|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "SIN_UPDATE|${id}|InstrA|PAY|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0