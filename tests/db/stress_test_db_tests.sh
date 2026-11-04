#!/usr/bin/env bash
# Stress test (Wave7) end-to-end DB tests via the COBOL binary.
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
db_reset_stress_test

# Create a cost center.
create_out="$(run_cobol "SST_CREATE|SST-W7-1|TestA|SCENARIO|||admin@test.com")"
assert_match "SST_CREATE ok" "$create_out" "SUCCESS\|SST_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM stress_test WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "SST_CREATE|SST-W7-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "SST_GET ok" "$(run_cobol "SST_GET|${id}|||||admin@test.com")" "SUCCESS\|SST_GET\|${id}\|SST-W7-1"
assert_match "SST_LIST ok" "$(run_cobol "SST_LIST|||50|0||admin@test.com")" "SST-W7-1"

# Allocate.
assert_match "SST_CALC ok" "$(run_cobol "SST_CALC|${id}|||||admin@test.com")" "SUCCESS\|SST_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM stress_test WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "SST_DELETE ok" "$(run_cobol "SST_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|SST_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM stress_test WHERE id=${id};")" "^COMPLETED$"

# Summary and audit.
assert_match "SST_SUMMARY ok" "$(run_cobol "SST_SUMMARY||||||admin@test.com")" "SUCCESS\|SST_SUMMARY"
assert_match "SST_AUDIT ok" "$(run_cobol "SST_AUDIT|50|0||||admin@test.com")" "SUCCESS\|SST_AUDIT"
assert_match "SST_VALIDATE ok" "$(run_cobol "SST_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|SST_VALID"
assert_match "non-admin refused" "$(run_cobol "SST_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"


# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM stress_test WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM stress_test_audit WHERE stress_test_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "SST_UPDATE|${id}|TestA|SCENARIO|||admin@test.com")"
assert_match "SST_UPDATE ok" "$upd_out" "SUCCESS\\|SST_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM stress_test WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM stress_test_audit WHERE stress_test_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "SST_UPDATE|999999|TestA|SCENARIO|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "SST_UPDATE|${id}|TestA|SCENARIO|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0