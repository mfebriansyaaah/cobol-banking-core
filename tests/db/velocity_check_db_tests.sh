#!/usr/bin/env bash
# Velocity check (Wave8) end-to-end DB tests via the COBOL binary.
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
db_reset_velocity_check

# Create a cost center.
create_out="$(run_cobol "VLC_CREATE|VLC-W8-1|AccountA|HOURLY|||admin@test.com")"
assert_match "VLC_CREATE ok" "$create_out" "SUCCESS\|VLC_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM velocity_check WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "VLC_CREATE|VLC-W8-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "VLC_GET ok" "$(run_cobol "VLC_GET|${id}|||||admin@test.com")" "SUCCESS\|VLC_GET\|${id}\|VLC-W8-1"
assert_match "VLC_LIST ok" "$(run_cobol "VLC_LIST|||50|0||admin@test.com")" "VLC-W8-1"

# Allocate.
assert_match "VLC_CALC ok" "$(run_cobol "VLC_CALC|${id}|||||admin@test.com")" "SUCCESS\|VLC_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM velocity_check WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "VLC_DELETE ok" "$(run_cobol "VLC_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|VLC_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM velocity_check WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "VLC_SUMMARY ok" "$(run_cobol "VLC_SUMMARY||||||admin@test.com")" "SUCCESS\|VLC_SUMMARY"
assert_match "VLC_AUDIT ok" "$(run_cobol "VLC_AUDIT|50|0||||admin@test.com")" "SUCCESS\|VLC_AUDIT"
assert_match "VLC_VALIDATE ok" "$(run_cobol "VLC_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|VLC_VALID"
assert_match "non-admin refused" "$(run_cobol "VLC_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"


# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM velocity_check WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM velocity_check_audit WHERE velocity_check_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "VLC_UPDATE|${id}|AccountA|HOURLY|||admin@test.com")"
assert_match "VLC_UPDATE ok" "$upd_out" "SUCCESS\\|VLC_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM velocity_check WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM velocity_check_audit WHERE velocity_check_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "VLC_UPDATE|999999|AccountA|HOURLY|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "VLC_UPDATE|${id}|AccountA|HOURLY|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0