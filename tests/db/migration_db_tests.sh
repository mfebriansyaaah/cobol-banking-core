#!/usr/bin/env bash
# Migration (Wave17) end-to-end DB tests via the COBOL binary.
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
db_reset_migration

# Create a cost center.
create_out="$(run_cobol "MIG_CREATE|MIG-W17-1|MigrationA|SCHEMA|||admin@test.com")"
assert_match "MIG_CREATE ok" "$create_out" "SUCCESS\|MIG_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM migration WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "MIG_CREATE|MIG-W17-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "MIG_GET ok" "$(run_cobol "MIG_GET|${id}|||||admin@test.com")" "SUCCESS\|MIG_GET\|${id}\|MIG-W17-1"
assert_match "MIG_LIST ok" "$(run_cobol "MIG_LIST|||50|0||admin@test.com")" "MIG-W17-1"

# Allocate.
assert_match "MIG_CALC ok" "$(run_cobol "MIG_CALC|${id}|||||admin@test.com")" "SUCCESS\|MIG_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM migration WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "MIG_DELETE ok" "$(run_cobol "MIG_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|MIG_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM migration WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "MIG_SUMMARY ok" "$(run_cobol "MIG_SUMMARY||||||admin@test.com")" "SUCCESS\|MIG_SUMMARY"
assert_match "MIG_AUDIT ok" "$(run_cobol "MIG_AUDIT|50|0||||admin@test.com")" "SUCCESS\|MIG_AUDIT"
assert_match "MIG_VALIDATE ok" "$(run_cobol "MIG_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|MIG_VALID"
assert_match "non-admin refused" "$(run_cobol "MIG_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"


# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM migration WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM migration_audit WHERE migration_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "MIG_UPDATE|${id}|MigrationA|SCHEMA|||admin@test.com")"
assert_match "MIG_UPDATE ok" "$upd_out" "SUCCESS\\|MIG_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM migration WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM migration_audit WHERE migration_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "MIG_UPDATE|999999|MigrationA|SCHEMA|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "MIG_UPDATE|${id}|MigrationA|SCHEMA|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0