#!/usr/bin/env bash
# Retention money (Wave16) end-to-end DB tests via the COBOL binary.
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
db_reset_retention_money

# Create a cost center.
create_out="$(run_cobol "RTMN_CREATE|RTMN-W16-1|ContractorA|CONTRACT|||admin@test.com")"
assert_match "RTMN_CREATE ok" "$create_out" "SUCCESS\|RTMN_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM retention_money WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "RTMN_CREATE|RTMN-W16-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "RTMN_GET ok" "$(run_cobol "RTMN_GET|${id}|||||admin@test.com")" "SUCCESS\|RTMN_GET\|${id}\|RTMN-W16-1"
assert_match "RTMN_LIST ok" "$(run_cobol "RTMN_LIST|||50|0||admin@test.com")" "RTMN-W16-1"

# Allocate.
assert_match "RTMN_CALC ok" "$(run_cobol "RTMN_CALC|${id}|||||admin@test.com")" "SUCCESS\|RTMN_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM retention_money WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "RTMN_DELETE ok" "$(run_cobol "RTMN_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|RTMN_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM retention_money WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "RTMN_SUMMARY ok" "$(run_cobol "RTMN_SUMMARY||||||admin@test.com")" "SUCCESS\|RTMN_SUMMARY"
assert_match "RTMN_AUDIT ok" "$(run_cobol "RTMN_AUDIT|50|0||||admin@test.com")" "SUCCESS\|RTMN_AUDIT"
assert_match "RTMN_VALIDATE ok" "$(run_cobol "RTMN_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|RTMN_VALID"
assert_match "non-admin refused" "$(run_cobol "RTMN_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"


# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM retention_money WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM retention_money_audit WHERE retention_money_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "RTMN_UPDATE|${id}|ContractorA|CONTRACT|||admin@test.com")"
assert_match "RTMN_UPDATE ok" "$upd_out" "SUCCESS\\|RTMN_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM retention_money WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM retention_money_audit WHERE retention_money_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "RTMN_UPDATE|999999|ContractorA|CONTRACT|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "RTMN_UPDATE|${id}|ContractorA|CONTRACT|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0