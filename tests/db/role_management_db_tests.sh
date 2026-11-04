#!/usr/bin/env bash
# Role management (Wave5) end-to-end DB tests via the COBOL binary.
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
db_reset_role_management

# Create a cost center.
create_out="$(run_cobol "RLM_CREATE|RLM-W5-1|RoleA|ADMIN|||admin@test.com")"
assert_match "RLM_CREATE ok" "$create_out" "SUCCESS\|RLM_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM role_management WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "RLM_CREATE|RLM-W5-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "RLM_GET ok" "$(run_cobol "RLM_GET|${id}|||||admin@test.com")" "SUCCESS\|RLM_GET\|${id}\|RLM-W5-1"
assert_match "RLM_LIST ok" "$(run_cobol "RLM_LIST|||50|0||admin@test.com")" "RLM-W5-1"

# Allocate.
assert_match "RLM_CALC ok" "$(run_cobol "RLM_CALC|${id}|||||admin@test.com")" "SUCCESS\|RLM_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT assigned_users FROM role_management WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "RLM_DELETE ok" "$(run_cobol "RLM_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|RLM_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM role_management WHERE id=${id};")" "^INACTIVE$"

# Summary and audit.
assert_match "RLM_SUMMARY ok" "$(run_cobol "RLM_SUMMARY||||||admin@test.com")" "SUCCESS\|RLM_SUMMARY"
assert_match "RLM_AUDIT ok" "$(run_cobol "RLM_AUDIT|50|0||||admin@test.com")" "SUCCESS\|RLM_AUDIT"
assert_match "RLM_VALIDATE ok" "$(run_cobol "RLM_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|RLM_VALID"
assert_match "non-admin refused" "$(run_cobol "RLM_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"


# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM role_management WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM role_management_audit WHERE role_management_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "RLM_UPDATE|${id}|RoleA|ADMIN|||admin@test.com")"
assert_match "RLM_UPDATE ok" "$upd_out" "SUCCESS\\|RLM_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM role_management WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM role_management_audit WHERE role_management_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "RLM_UPDATE|999999|RoleA|ADMIN|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "RLM_UPDATE|${id}|RoleA|ADMIN|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0