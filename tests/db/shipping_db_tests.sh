#!/usr/bin/env bash
# Shipping (Wave19) end-to-end DB tests via the COBOL binary.
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
db_reset_shipping

# Create a cost center.
create_out="$(run_cobol "SHP_CREATE|SHP-W19-1|ShipmentA|EXPORT|||admin@test.com")"
assert_match "SHP_CREATE ok" "$create_out" "SUCCESS\|SHP_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM shipping WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "SHP_CREATE|SHP-W19-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "SHP_GET ok" "$(run_cobol "SHP_GET|${id}|||||admin@test.com")" "SUCCESS\|SHP_GET\|${id}\|SHP-W19-1"
assert_match "SHP_LIST ok" "$(run_cobol "SHP_LIST|||50|0||admin@test.com")" "SHP-W19-1"

# Allocate.
assert_match "SHP_CALC ok" "$(run_cobol "SHP_CALC|${id}|||||admin@test.com")" "SUCCESS\|SHP_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM shipping WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "SHP_DELETE ok" "$(run_cobol "SHP_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|SHP_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM shipping WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "SHP_SUMMARY ok" "$(run_cobol "SHP_SUMMARY||||||admin@test.com")" "SUCCESS\|SHP_SUMMARY"
assert_match "SHP_AUDIT ok" "$(run_cobol "SHP_AUDIT|50|0||||admin@test.com")" "SUCCESS\|SHP_AUDIT"
assert_match "SHP_VALIDATE ok" "$(run_cobol "SHP_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|SHP_VALID"
assert_match "non-admin refused" "$(run_cobol "SHP_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"


# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM shipping WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM shipping_audit WHERE shipping_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "SHP_UPDATE|${id}|ShipmentA|EXPORT|||admin@test.com")"
assert_match "SHP_UPDATE ok" "$upd_out" "SUCCESS\\|SHP_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM shipping WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM shipping_audit WHERE shipping_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "SHP_UPDATE|999999|ShipmentA|EXPORT|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "SHP_UPDATE|${id}|ShipmentA|EXPORT|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0