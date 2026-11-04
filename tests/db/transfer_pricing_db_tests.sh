#!/usr/bin/env bash
# Transfer pricing (Wave14) end-to-end DB tests via the COBOL binary.
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
db_reset_transfer_pricing

# Create a cost center.
create_out="$(run_cobol "TPR_CREATE|TPR-W14-1|TpA|ARM_LENGTH|||admin@test.com")"
assert_match "TPR_CREATE ok" "$create_out" "SUCCESS\|TPR_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM transfer_pricing WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "TPR_CREATE|TPR-W14-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "TPR_GET ok" "$(run_cobol "TPR_GET|${id}|||||admin@test.com")" "SUCCESS\|TPR_GET\|${id}\|TPR-W14-1"
assert_match "TPR_LIST ok" "$(run_cobol "TPR_LIST|||50|0||admin@test.com")" "TPR-W14-1"

# Allocate.
assert_match "TPR_CALC ok" "$(run_cobol "TPR_CALC|${id}|||||admin@test.com")" "SUCCESS\|TPR_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM transfer_pricing WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "TPR_DELETE ok" "$(run_cobol "TPR_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|TPR_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM transfer_pricing WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "TPR_SUMMARY ok" "$(run_cobol "TPR_SUMMARY||||||admin@test.com")" "SUCCESS\|TPR_SUMMARY"
assert_match "TPR_AUDIT ok" "$(run_cobol "TPR_AUDIT|50|0||||admin@test.com")" "SUCCESS\|TPR_AUDIT"
assert_match "TPR_VALIDATE ok" "$(run_cobol "TPR_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|TPR_VALID"
assert_match "non-admin refused" "$(run_cobol "TPR_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"


# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM transfer_pricing WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM transfer_pricing_audit WHERE transfer_pricing_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "TPR_UPDATE|${id}|TpA|ARM_LENGTH|||admin@test.com")"
assert_match "TPR_UPDATE ok" "$upd_out" "SUCCESS\\|TPR_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM transfer_pricing WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM transfer_pricing_audit WHERE transfer_pricing_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "TPR_UPDATE|999999|TpA|ARM_LENGTH|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "TPR_UPDATE|${id}|TpA|ARM_LENGTH|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0