#!/usr/bin/env bash
# Collateral mgmt (Wave3) end-to-end DB tests via the COBOL binary.
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
db_reset_collateral_mgmt

# Create a cost center.
create_out="$(run_cobol "CREP_CREATE|CLM-W3-1|AssetA|GOV|||admin@test.com")"
assert_match "CREP_CREATE ok" "$create_out" "SUCCESS\|CREP_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM collateral_mgmt WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "CREP_CREATE|CLM-W3-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "CREP_GET ok" "$(run_cobol "CREP_GET|${id}|||||admin@test.com")" "SUCCESS\|CREP_GET\|${id}\|CLM-W3-1"
assert_match "CREP_LIST ok" "$(run_cobol "CREP_LIST|||50|0||admin@test.com")" "CLM-W3-1"

# Allocate.
assert_match "CREP_CALC ok" "$(run_cobol "CREP_CALC|${id}|||||admin@test.com")" "SUCCESS\|CREP_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT haircut_value FROM collateral_mgmt WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "CREP_DELETE ok" "$(run_cobol "CREP_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|CREP_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM collateral_mgmt WHERE id=${id};")" "^RELEASED$"

# Summary and audit.
assert_match "CREP_SUMMARY ok" "$(run_cobol "CREP_SUMMARY||||||admin@test.com")" "SUCCESS\|CREP_SUMMARY"
assert_match "CREP_AUDIT ok" "$(run_cobol "CREP_AUDIT|50|0||||admin@test.com")" "SUCCESS\|CREP_AUDIT"
assert_match "CREP_VALIDATE ok" "$(run_cobol "CREP_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|CREP_VALID"
assert_match "non-admin refused" "$(run_cobol "CREP_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"


# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM collateral_mgmt WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM collateral_mgmt_audit WHERE collateral_mgmt_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "CREP_UPDATE|${id}|AssetA|GOV|||admin@test.com")"
assert_match "CREP_UPDATE ok" "$upd_out" "SUCCESS\\|CREP_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM collateral_mgmt WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM collateral_mgmt_audit WHERE collateral_mgmt_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "CREP_UPDATE|999999|AssetA|GOV|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "CREP_UPDATE|${id}|AssetA|GOV|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0