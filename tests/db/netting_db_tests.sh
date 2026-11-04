#!/usr/bin/env bash
# Netting (Wave13) end-to-end DB tests via the COBOL binary.
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
db_reset_netting

# Create a cost center.
create_out="$(run_cobol "NET_CREATE|NET-W13-1|EntityA|BILATERAL|||admin@test.com")"
assert_match "NET_CREATE ok" "$create_out" "SUCCESS\|NET_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM netting WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "NET_CREATE|NET-W13-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "NET_GET ok" "$(run_cobol "NET_GET|${id}|||||admin@test.com")" "SUCCESS\|NET_GET\|${id}\|NET-W13-1"
assert_match "NET_LIST ok" "$(run_cobol "NET_LIST|||50|0||admin@test.com")" "NET-W13-1"

# Allocate.
assert_match "NET_CALC ok" "$(run_cobol "NET_CALC|${id}|||||admin@test.com")" "SUCCESS\|NET_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM netting WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "NET_DELETE ok" "$(run_cobol "NET_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|NET_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM netting WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "NET_SUMMARY ok" "$(run_cobol "NET_SUMMARY||||||admin@test.com")" "SUCCESS\|NET_SUMMARY"
assert_match "NET_AUDIT ok" "$(run_cobol "NET_AUDIT|50|0||||admin@test.com")" "SUCCESS\|NET_AUDIT"
assert_match "NET_VALIDATE ok" "$(run_cobol "NET_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|NET_VALID"
assert_match "non-admin refused" "$(run_cobol "NET_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"


# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM netting WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM netting_audit WHERE netting_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "NET_UPDATE|${id}|EntityA|BILATERAL|||admin@test.com")"
assert_match "NET_UPDATE ok" "$upd_out" "SUCCESS\\|NET_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM netting WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM netting_audit WHERE netting_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "NET_UPDATE|999999|EntityA|BILATERAL|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "NET_UPDATE|${id}|EntityA|BILATERAL|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0