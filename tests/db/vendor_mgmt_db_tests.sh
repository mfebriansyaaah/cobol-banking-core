#!/usr/bin/env bash
# Vendor mgmt (Wave19) end-to-end DB tests via the COBOL binary.
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
db_reset_vendor_mgmt

# Create a cost center.
create_out="$(run_cobol "VDR_CREATE|VDR-W19-1|VendorA|SUPPLIER|||admin@test.com")"
assert_match "VDR_CREATE ok" "$create_out" "SUCCESS\|VDR_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM vendor_mgmt WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "VDR_CREATE|VDR-W19-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "VDR_GET ok" "$(run_cobol "VDR_GET|${id}|||||admin@test.com")" "SUCCESS\|VDR_GET\|${id}\|VDR-W19-1"
assert_match "VDR_LIST ok" "$(run_cobol "VDR_LIST|||50|0||admin@test.com")" "VDR-W19-1"

# Allocate.
assert_match "VDR_CALC ok" "$(run_cobol "VDR_CALC|${id}|||||admin@test.com")" "SUCCESS\|VDR_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM vendor_mgmt WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "VDR_DELETE ok" "$(run_cobol "VDR_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|VDR_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM vendor_mgmt WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "VDR_SUMMARY ok" "$(run_cobol "VDR_SUMMARY||||||admin@test.com")" "SUCCESS\|VDR_SUMMARY"
assert_match "VDR_AUDIT ok" "$(run_cobol "VDR_AUDIT|50|0||||admin@test.com")" "SUCCESS\|VDR_AUDIT"
assert_match "VDR_VALIDATE ok" "$(run_cobol "VDR_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|VDR_VALID"
assert_match "non-admin refused" "$(run_cobol "VDR_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"


# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM vendor_mgmt WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM vendor_mgmt_audit WHERE vendor_mgmt_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "VDR_UPDATE|${id}|VendorA|SUPPLIER|||admin@test.com")"
assert_match "VDR_UPDATE ok" "$upd_out" "SUCCESS\\|VDR_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM vendor_mgmt WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM vendor_mgmt_audit WHERE vendor_mgmt_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "VDR_UPDATE|999999|VendorA|SUPPLIER|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "VDR_UPDATE|${id}|VendorA|SUPPLIER|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0