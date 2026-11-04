#!/usr/bin/env bash
# Position mgmt (Wave14) end-to-end DB tests via the COBOL binary.
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
db_reset_position_mgmt

# Create a cost center.
create_out="$(run_cobol "PSTN_CREATE|PSTN-W14-1|PosA|LONG|||admin@test.com")"
assert_match "PSTN_CREATE ok" "$create_out" "SUCCESS\|PSTN_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM position_mgmt WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "PSTN_CREATE|PSTN-W14-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "PSTN_GET ok" "$(run_cobol "PSTN_GET|${id}|||||admin@test.com")" "SUCCESS\|PSTN_GET\|${id}\|PSTN-W14-1"
assert_match "PSTN_LIST ok" "$(run_cobol "PSTN_LIST|||50|0||admin@test.com")" "PSTN-W14-1"

# Allocate.
assert_match "PSTN_CALC ok" "$(run_cobol "PSTN_CALC|${id}|||||admin@test.com")" "SUCCESS\|PSTN_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM position_mgmt WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "PSTN_DELETE ok" "$(run_cobol "PSTN_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|PSTN_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM position_mgmt WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "PSTN_SUMMARY ok" "$(run_cobol "PSTN_SUMMARY||||||admin@test.com")" "SUCCESS\|PSTN_SUMMARY"
assert_match "PSTN_AUDIT ok" "$(run_cobol "PSTN_AUDIT|50|0||||admin@test.com")" "SUCCESS\|PSTN_AUDIT"
assert_match "PSTN_VALIDATE ok" "$(run_cobol "PSTN_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|PSTN_VALID"
assert_match "non-admin refused" "$(run_cobol "PSTN_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"


# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM position_mgmt WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM position_mgmt_audit WHERE position_mgmt_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "PSTN_UPDATE|${id}|PosA|LONG|||admin@test.com")"
assert_match "PSTN_UPDATE ok" "$upd_out" "SUCCESS\\|PSTN_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM position_mgmt WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM position_mgmt_audit WHERE position_mgmt_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "PSTN_UPDATE|999999|PosA|LONG|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "PSTN_UPDATE|${id}|PosA|LONG|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0