#!/usr/bin/env bash
# Payment gateway (Wave5) end-to-end DB tests via the COBOL binary.
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
db_reset_payment_gateway

# Create a cost center.
create_out="$(run_cobol "PWG_CREATE|PWG-W5-1|GatewayA|ONLINE|||admin@test.com")"
assert_match "PWG_CREATE ok" "$create_out" "SUCCESS\|PWG_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM payment_gateway WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "PWG_CREATE|PWG-W5-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "PWG_GET ok" "$(run_cobol "PWG_GET|${id}|||||admin@test.com")" "SUCCESS\|PWG_GET\|${id}\|PWG-W5-1"
assert_match "PWG_LIST ok" "$(run_cobol "PWG_LIST|||50|0||admin@test.com")" "PWG-W5-1"

# Allocate.
assert_match "PWG_CALC ok" "$(run_cobol "PWG_CALC|${id}|||||admin@test.com")" "SUCCESS\|PWG_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT processed_volume FROM payment_gateway WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "PWG_DELETE ok" "$(run_cobol "PWG_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|PWG_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM payment_gateway WHERE id=${id};")" "^INACTIVE$"

# Summary and audit.
assert_match "PWG_SUMMARY ok" "$(run_cobol "PWG_SUMMARY||||||admin@test.com")" "SUCCESS\|PWG_SUMMARY"
assert_match "PWG_AUDIT ok" "$(run_cobol "PWG_AUDIT|50|0||||admin@test.com")" "SUCCESS\|PWG_AUDIT"
assert_match "PWG_VALIDATE ok" "$(run_cobol "PWG_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|PWG_VALID"
assert_match "non-admin refused" "$(run_cobol "PWG_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"




# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM payment_gateway WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM payment_gateway_audit WHERE payment_gateway_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "PWG_UPDATE|${id}|GatewayA|ONLINE|||admin@test.com")"
assert_match "PWG_UPDATE ok" "$upd_out" "SUCCESS\\|PWG_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM payment_gateway WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM payment_gateway_audit WHERE payment_gateway_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "PWG_UPDATE|999999|GatewayA|ONLINE|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "PWG_UPDATE|${id}|GatewayA|ONLINE|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0