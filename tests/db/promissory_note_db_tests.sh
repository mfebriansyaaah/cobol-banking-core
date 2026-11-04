#!/usr/bin/env bash
# Promissory note (Wave16) end-to-end DB tests via the COBOL binary.
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
db_reset_promissory_note

# Create a cost center.
create_out="$(run_cobol "PMN_CREATE|PMN-W16-1|MakerA|NEGOTIABLE|||admin@test.com")"
assert_match "PMN_CREATE ok" "$create_out" "SUCCESS\|PMN_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM promissory_note WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "PMN_CREATE|PMN-W16-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "PMN_GET ok" "$(run_cobol "PMN_GET|${id}|||||admin@test.com")" "SUCCESS\|PMN_GET\|${id}\|PMN-W16-1"
assert_match "PMN_LIST ok" "$(run_cobol "PMN_LIST|||50|0||admin@test.com")" "PMN-W16-1"

# Allocate.
assert_match "PMN_CALC ok" "$(run_cobol "PMN_CALC|${id}|||||admin@test.com")" "SUCCESS\|PMN_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM promissory_note WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "PMN_DELETE ok" "$(run_cobol "PMN_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|PMN_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM promissory_note WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "PMN_SUMMARY ok" "$(run_cobol "PMN_SUMMARY||||||admin@test.com")" "SUCCESS\|PMN_SUMMARY"
assert_match "PMN_AUDIT ok" "$(run_cobol "PMN_AUDIT|50|0||||admin@test.com")" "SUCCESS\|PMN_AUDIT"
assert_match "PMN_VALIDATE ok" "$(run_cobol "PMN_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|PMN_VALID"
assert_match "non-admin refused" "$(run_cobol "PMN_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"


# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM promissory_note WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM promissory_note_audit WHERE promissory_note_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "PMN_UPDATE|${id}|MakerA|NEGOTIABLE|||admin@test.com")"
assert_match "PMN_UPDATE ok" "$upd_out" "SUCCESS\\|PMN_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM promissory_note WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM promissory_note_audit WHERE promissory_note_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "PMN_UPDATE|999999|MakerA|NEGOTIABLE|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "PMN_UPDATE|${id}|MakerA|NEGOTIABLE|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0