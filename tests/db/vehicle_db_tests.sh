#!/usr/bin/env bash
# Vehicle (Wave12) end-to-end DB tests via the COBOL binary.
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
db_reset_vehicle

# Create a cost center.
create_out="$(run_cobol "SPV_CREATE|SPV-W12-1|VehicleA|SPV|||admin@test.com")"
assert_match "SPV_CREATE ok" "$create_out" "SUCCESS\|SPV_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM vehicle WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "SPV_CREATE|SPV-W12-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "SPV_GET ok" "$(run_cobol "SPV_GET|${id}|||||admin@test.com")" "SUCCESS\|SPV_GET\|${id}\|SPV-W12-1"
assert_match "SPV_LIST ok" "$(run_cobol "SPV_LIST|||50|0||admin@test.com")" "SPV-W12-1"

# Allocate.
assert_match "SPV_CALC ok" "$(run_cobol "SPV_CALC|${id}|||||admin@test.com")" "SUCCESS\|SPV_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM vehicle WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "SPV_DELETE ok" "$(run_cobol "SPV_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|SPV_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM vehicle WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "SPV_SUMMARY ok" "$(run_cobol "SPV_SUMMARY||||||admin@test.com")" "SUCCESS\|SPV_SUMMARY"
assert_match "SPV_AUDIT ok" "$(run_cobol "SPV_AUDIT|50|0||||admin@test.com")" "SUCCESS\|SPV_AUDIT"
assert_match "SPV_VALIDATE ok" "$(run_cobol "SPV_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|SPV_VALID"
assert_match "non-admin refused" "$(run_cobol "SPV_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"


# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM vehicle WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM vehicle_audit WHERE vehicle_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "SPV_UPDATE|${id}|VehicleA|SPV|||admin@test.com")"
assert_match "SPV_UPDATE ok" "$upd_out" "SUCCESS\\|SPV_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM vehicle WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM vehicle_audit WHERE vehicle_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "SPV_UPDATE|999999|VehicleA|SPV|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "SPV_UPDATE|${id}|VehicleA|SPV|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0