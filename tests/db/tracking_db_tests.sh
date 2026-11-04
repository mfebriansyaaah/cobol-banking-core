#!/usr/bin/env bash
# Tracking (Wave19) end-to-end DB tests via the COBOL binary.
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
db_reset_tracking

# Create a cost center.
create_out="$(run_cobol "TRK_CREATE|TRK-W19-1|TrackingA|REALTIME|||admin@test.com")"
assert_match "TRK_CREATE ok" "$create_out" "SUCCESS\|TRK_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM tracking WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "TRK_CREATE|TRK-W19-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "TRK_GET ok" "$(run_cobol "TRK_GET|${id}|||||admin@test.com")" "SUCCESS\|TRK_GET\|${id}\|TRK-W19-1"
assert_match "TRK_LIST ok" "$(run_cobol "TRK_LIST|||50|0||admin@test.com")" "TRK-W19-1"

# Allocate.
assert_match "TRK_CALC ok" "$(run_cobol "TRK_CALC|${id}|||||admin@test.com")" "SUCCESS\|TRK_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM tracking WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "TRK_DELETE ok" "$(run_cobol "TRK_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|TRK_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM tracking WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "TRK_SUMMARY ok" "$(run_cobol "TRK_SUMMARY||||||admin@test.com")" "SUCCESS\|TRK_SUMMARY"
assert_match "TRK_AUDIT ok" "$(run_cobol "TRK_AUDIT|50|0||||admin@test.com")" "SUCCESS\|TRK_AUDIT"
assert_match "TRK_VALIDATE ok" "$(run_cobol "TRK_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|TRK_VALID"
assert_match "non-admin refused" "$(run_cobol "TRK_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"


# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM tracking WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM tracking_audit WHERE tracking_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "TRK_UPDATE|${id}|TrackingA|REALTIME|||admin@test.com")"
assert_match "TRK_UPDATE ok" "$upd_out" "SUCCESS\\|TRK_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM tracking WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM tracking_audit WHERE tracking_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "TRK_UPDATE|999999|TrackingA|REALTIME|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "TRK_UPDATE|${id}|TrackingA|REALTIME|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0