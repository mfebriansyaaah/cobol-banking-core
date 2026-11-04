#!/usr/bin/env bash
# Collateral repossession (Wave7) end-to-end DB tests via the COBOL binary.
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
db_reset_collateral_repossession

# Create a cost center.
create_out="$(run_cobol "CRP_CREATE|CRP-W7-1|AssetA|VEHICLE|||admin@test.com")"
assert_match "CRP_CREATE ok" "$create_out" "SUCCESS\|CRP_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM collateral_repossession WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "CRP_CREATE|CRP-W7-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "CRP_GET ok" "$(run_cobol "CRP_GET|${id}|||||admin@test.com")" "SUCCESS\|CRP_GET\|${id}\|CRP-W7-1"
assert_match "CRP_LIST ok" "$(run_cobol "CRP_LIST|||50|0||admin@test.com")" "CRP-W7-1"

# Allocate.
assert_match "CRP_CALC ok" "$(run_cobol "CRP_CALC|${id}|||||admin@test.com")" "SUCCESS\|CRP_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM collateral_repossession WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "CRP_DELETE ok" "$(run_cobol "CRP_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|CRP_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM collateral_repossession WHERE id=${id};")" "^REPOSSESSED$"

# Summary and audit.
assert_match "CRP_SUMMARY ok" "$(run_cobol "CRP_SUMMARY||||||admin@test.com")" "SUCCESS\|CRP_SUMMARY"
assert_match "CRP_AUDIT ok" "$(run_cobol "CRP_AUDIT|50|0||||admin@test.com")" "SUCCESS\|CRP_AUDIT"
assert_match "CRP_VALIDATE ok" "$(run_cobol "CRP_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|CRP_VALID"
assert_match "non-admin refused" "$(run_cobol "CRP_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"


# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM collateral_repossession WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM collateral_repossession_audit WHERE collateral_repossession_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "CRP_UPDATE|${id}|AssetA|VEHICLE|||admin@test.com")"
assert_match "CRP_UPDATE ok" "$upd_out" "SUCCESS\\|CRP_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM collateral_repossession WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM collateral_repossession_audit WHERE collateral_repossession_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "CRP_UPDATE|999999|AssetA|VEHICLE|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "CRP_UPDATE|${id}|AssetA|VEHICLE|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0