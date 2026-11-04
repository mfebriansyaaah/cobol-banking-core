#!/usr/bin/env bash
# Structured note (Wave12) end-to-end DB tests via the COBOL binary.
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
db_reset_structured_note

# Create a cost center.
create_out="$(run_cobol "STN_CREATE|STN-W12-1|NoteA|AUTOCALL|||admin@test.com")"
assert_match "STN_CREATE ok" "$create_out" "SUCCESS\|STN_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM structured_note WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "STN_CREATE|STN-W12-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "STN_GET ok" "$(run_cobol "STN_GET|${id}|||||admin@test.com")" "SUCCESS\|STN_GET\|${id}\|STN-W12-1"
assert_match "STN_LIST ok" "$(run_cobol "STN_LIST|||50|0||admin@test.com")" "STN-W12-1"

# Allocate.
assert_match "STN_CALC ok" "$(run_cobol "STN_CALC|${id}|||||admin@test.com")" "SUCCESS\|STN_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM structured_note WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "STN_DELETE ok" "$(run_cobol "STN_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|STN_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM structured_note WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "STN_SUMMARY ok" "$(run_cobol "STN_SUMMARY||||||admin@test.com")" "SUCCESS\|STN_SUMMARY"
assert_match "STN_AUDIT ok" "$(run_cobol "STN_AUDIT|50|0||||admin@test.com")" "SUCCESS\|STN_AUDIT"
assert_match "STN_VALIDATE ok" "$(run_cobol "STN_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|STN_VALID"
assert_match "non-admin refused" "$(run_cobol "STN_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"


# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM structured_note WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM structured_note_audit WHERE structured_note_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "STN_UPDATE|${id}|NoteA|AUTOCALL|||admin@test.com")"
assert_match "STN_UPDATE ok" "$upd_out" "SUCCESS\\|STN_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM structured_note WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM structured_note_audit WHERE structured_note_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "STN_UPDATE|999999|NoteA|AUTOCALL|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "STN_UPDATE|${id}|NoteA|AUTOCALL|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0