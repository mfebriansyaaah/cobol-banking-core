#!/usr/bin/env bash
# Profit center (Wave14) end-to-end DB tests via the COBOL binary.
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
db_reset_profit_center

# Create a cost center.
create_out="$(run_cobol "PC_CREATE|PC-W14-1|PcA|BUSINESS_UNIT|||admin@test.com")"
assert_match "PC_CREATE ok" "$create_out" "SUCCESS\|PC_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM profit_center WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "PC_CREATE|PC-W14-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "PC_GET ok" "$(run_cobol "PC_GET|${id}|||||admin@test.com")" "SUCCESS\|PC_GET\|${id}\|PC-W14-1"
assert_match "PC_LIST ok" "$(run_cobol "PC_LIST|||50|0||admin@test.com")" "PC-W14-1"

# Allocate.
assert_match "PC_CALC ok" "$(run_cobol "PC_CALC|${id}|||||admin@test.com")" "SUCCESS\|PC_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM profit_center WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "PC_DELETE ok" "$(run_cobol "PC_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|PC_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM profit_center WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "PC_SUMMARY ok" "$(run_cobol "PC_SUMMARY||||||admin@test.com")" "SUCCESS\|PC_SUMMARY"
assert_match "PC_AUDIT ok" "$(run_cobol "PC_AUDIT|50|0||||admin@test.com")" "SUCCESS\|PC_AUDIT"
assert_match "PC_VALIDATE ok" "$(run_cobol "PC_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|PC_VALID"
assert_match "non-admin refused" "$(run_cobol "PC_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"


# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM profit_center WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM profit_center_audit WHERE profit_center_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "PC_UPDATE|${id}|PcA|BUSINESS_UNIT|||admin@test.com")"
assert_match "PC_UPDATE ok" "$upd_out" "SUCCESS\\|PC_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM profit_center WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM profit_center_audit WHERE profit_center_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "PC_UPDATE|999999|PcA|BUSINESS_UNIT|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "PC_UPDATE|${id}|PcA|BUSINESS_UNIT|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0