#!/usr/bin/env bash
# Training (Wave10) end-to-end DB tests via the COBOL binary.
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
db_reset_training

# Create a cost center.
create_out="$(run_cobol "TRN_CREATE|TRN-W10-1|CourseA|TECHNICAL|||admin@test.com")"
assert_match "TRN_CREATE ok" "$create_out" "SUCCESS\|TRN_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM training WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "TRN_CREATE|TRN-W10-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "TRN_GET ok" "$(run_cobol "TRN_GET|${id}|||||admin@test.com")" "SUCCESS\|TRN_GET\|${id}\|TRN-W10-1"
assert_match "TRN_LIST ok" "$(run_cobol "TRN_LIST|||50|0||admin@test.com")" "TRN-W10-1"

# Allocate.
assert_match "TRN_CALC ok" "$(run_cobol "TRN_CALC|${id}|||||admin@test.com")" "SUCCESS\|TRN_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM training WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "TRN_DELETE ok" "$(run_cobol "TRN_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|TRN_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM training WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "TRN_SUMMARY ok" "$(run_cobol "TRN_SUMMARY||||||admin@test.com")" "SUCCESS\|TRN_SUMMARY"
assert_match "TRN_AUDIT ok" "$(run_cobol "TRN_AUDIT|50|0||||admin@test.com")" "SUCCESS\|TRN_AUDIT"
assert_match "TRN_VALIDATE ok" "$(run_cobol "TRN_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|TRN_VALID"
assert_match "non-admin refused" "$(run_cobol "TRN_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"


# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM training WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM training_audit WHERE training_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "TRN_UPDATE|${id}|CourseA|TECHNICAL|||admin@test.com")"
assert_match "TRN_UPDATE ok" "$upd_out" "SUCCESS\\|TRN_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM training WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM training_audit WHERE training_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "TRN_UPDATE|999999|CourseA|TECHNICAL|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "TRN_UPDATE|${id}|CourseA|TECHNICAL|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0