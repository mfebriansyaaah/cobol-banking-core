#!/usr/bin/env bash
# Rollback (Wave17) end-to-end DB tests via the COBOL binary.
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
db_reset_rollback

# Create a cost center.
create_out="$(run_cobol "ROL_CREATE|ROL-W17-1|ServiceA|EMERGENCY|||admin@test.com")"
assert_match "ROL_CREATE ok" "$create_out" "SUCCESS\|ROL_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM rollback WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "ROL_CREATE|ROL-W17-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "ROL_GET ok" "$(run_cobol "ROL_GET|${id}|||||admin@test.com")" "SUCCESS\|ROL_GET\|${id}\|ROL-W17-1"
assert_match "ROL_LIST ok" "$(run_cobol "ROL_LIST|||50|0||admin@test.com")" "ROL-W17-1"

# Allocate.
assert_match "ROL_CALC ok" "$(run_cobol "ROL_CALC|${id}|||||admin@test.com")" "SUCCESS\|ROL_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM rollback WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "ROL_DELETE ok" "$(run_cobol "ROL_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|ROL_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM rollback WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "ROL_SUMMARY ok" "$(run_cobol "ROL_SUMMARY||||||admin@test.com")" "SUCCESS\|ROL_SUMMARY"
assert_match "ROL_AUDIT ok" "$(run_cobol "ROL_AUDIT|50|0||||admin@test.com")" "SUCCESS\|ROL_AUDIT"
assert_match "ROL_VALIDATE ok" "$(run_cobol "ROL_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|ROL_VALID"
assert_match "non-admin refused" "$(run_cobol "ROL_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"


# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM rollback WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM rollback_audit WHERE rollback_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "ROL_UPDATE|${id}|ServiceA|EMERGENCY|||admin@test.com")"
assert_match "ROL_UPDATE ok" "$upd_out" "SUCCESS\\|ROL_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM rollback WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM rollback_audit WHERE rollback_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "ROL_UPDATE|999999|ServiceA|EMERGENCY|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "ROL_UPDATE|${id}|ServiceA|EMERGENCY|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0