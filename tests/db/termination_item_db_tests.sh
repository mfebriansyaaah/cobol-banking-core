#!/usr/bin/env bash
# Termination item (Wave15) end-to-end DB tests via the COBOL binary.
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
db_reset_termination_item

# Create a cost center.
create_out="$(run_cobol "TERM_CREATE|TERM-W15-1|AccountA|CONTRACT|||admin@test.com")"
assert_match "TERM_CREATE ok" "$create_out" "SUCCESS\|TERM_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM termination_item WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "TERM_CREATE|TERM-W15-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "TERM_GET ok" "$(run_cobol "TERM_GET|${id}|||||admin@test.com")" "SUCCESS\|TERM_GET\|${id}\|TERM-W15-1"
assert_match "TERM_LIST ok" "$(run_cobol "TERM_LIST|||50|0||admin@test.com")" "TERM-W15-1"

# Allocate.
assert_match "TERM_CALC ok" "$(run_cobol "TERM_CALC|${id}|||||admin@test.com")" "SUCCESS\|TERM_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM termination_item WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "TERM_DELETE ok" "$(run_cobol "TERM_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|TERM_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM termination_item WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "TERM_SUMMARY ok" "$(run_cobol "TERM_SUMMARY||||||admin@test.com")" "SUCCESS\|TERM_SUMMARY"
assert_match "TERM_AUDIT ok" "$(run_cobol "TERM_AUDIT|50|0||||admin@test.com")" "SUCCESS\|TERM_AUDIT"
assert_match "TERM_VALIDATE ok" "$(run_cobol "TERM_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|TERM_VALID"
assert_match "non-admin refused" "$(run_cobol "TERM_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"


# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM termination_item WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM termination_item_audit WHERE termination_item_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "TERM_UPDATE|${id}|AccountA|CONTRACT|||admin@test.com")"
assert_match "TERM_UPDATE ok" "$upd_out" "SUCCESS\\|TERM_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM termination_item WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM termination_item_audit WHERE termination_item_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "TERM_UPDATE|999999|AccountA|CONTRACT|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "TERM_UPDATE|${id}|AccountA|CONTRACT|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0