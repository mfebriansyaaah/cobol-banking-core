#!/usr/bin/env bash
# Rebalancing (Wave14) end-to-end DB tests via the COBOL binary.
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
db_reset_rebalancing

# Create a cost center.
create_out="$(run_cobol "RBL_CREATE|RBL-W14-1|RebalA|PERIODIC|||admin@test.com")"
assert_match "RBL_CREATE ok" "$create_out" "SUCCESS\|RBL_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM rebalancing WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "RBL_CREATE|RBL-W14-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "RBL_GET ok" "$(run_cobol "RBL_GET|${id}|||||admin@test.com")" "SUCCESS\|RBL_GET\|${id}\|RBL-W14-1"
assert_match "RBL_LIST ok" "$(run_cobol "RBL_LIST|||50|0||admin@test.com")" "RBL-W14-1"

# Allocate.
assert_match "RBL_CALC ok" "$(run_cobol "RBL_CALC|${id}|||||admin@test.com")" "SUCCESS\|RBL_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM rebalancing WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "RBL_DELETE ok" "$(run_cobol "RBL_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|RBL_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM rebalancing WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "RBL_SUMMARY ok" "$(run_cobol "RBL_SUMMARY||||||admin@test.com")" "SUCCESS\|RBL_SUMMARY"
assert_match "RBL_AUDIT ok" "$(run_cobol "RBL_AUDIT|50|0||||admin@test.com")" "SUCCESS\|RBL_AUDIT"
assert_match "RBL_VALIDATE ok" "$(run_cobol "RBL_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|RBL_VALID"
assert_match "non-admin refused" "$(run_cobol "RBL_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"


# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM rebalancing WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM rebalancing_audit WHERE rebalancing_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "RBL_UPDATE|${id}|RebalA|PERIODIC|||admin@test.com")"
assert_match "RBL_UPDATE ok" "$upd_out" "SUCCESS\\|RBL_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM rebalancing WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM rebalancing_audit WHERE rebalancing_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "RBL_UPDATE|999999|RebalA|PERIODIC|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "RBL_UPDATE|${id}|RebalA|PERIODIC|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0