#!/usr/bin/env bash
# Position (Wave10) end-to-end DB tests via the COBOL binary.
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
db_reset_position

# Create a cost center.
create_out="$(run_cobol "POS_CREATE|POS-W10-1|PositionA|MANAGER|||admin@test.com")"
assert_match "POS_CREATE ok" "$create_out" "SUCCESS\|POS_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM position WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "POS_CREATE|POS-W10-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "POS_GET ok" "$(run_cobol "POS_GET|${id}|||||admin@test.com")" "SUCCESS\|POS_GET\|${id}\|POS-W10-1"
assert_match "POS_LIST ok" "$(run_cobol "POS_LIST|||50|0||admin@test.com")" "POS-W10-1"

# Allocate.
assert_match "POS_CALC ok" "$(run_cobol "POS_CALC|${id}|||||admin@test.com")" "SUCCESS\|POS_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM position WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "POS_DELETE ok" "$(run_cobol "POS_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|POS_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM position WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "POS_SUMMARY ok" "$(run_cobol "POS_SUMMARY||||||admin@test.com")" "SUCCESS\|POS_SUMMARY"
assert_match "POS_AUDIT ok" "$(run_cobol "POS_AUDIT|50|0||||admin@test.com")" "SUCCESS\|POS_AUDIT"
assert_match "POS_VALIDATE ok" "$(run_cobol "POS_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|POS_VALID"
assert_match "non-admin refused" "$(run_cobol "POS_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"


# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM position WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM position_audit WHERE position_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "POS_UPDATE|${id}|PositionA|MANAGER|||admin@test.com")"
assert_match "POS_UPDATE ok" "$upd_out" "SUCCESS\\|POS_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM position WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM position_audit WHERE position_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "POS_UPDATE|999999|PositionA|MANAGER|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "POS_UPDATE|${id}|PositionA|MANAGER|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0