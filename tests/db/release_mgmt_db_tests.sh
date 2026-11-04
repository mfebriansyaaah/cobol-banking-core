#!/usr/bin/env bash
# Release mgmt (Wave17) end-to-end DB tests via the COBOL binary.
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
db_reset_release_mgmt

# Create a cost center.
create_out="$(run_cobol "REL_CREATE|REL-W17-1|ReleaseA|MAJOR|||admin@test.com")"
assert_match "REL_CREATE ok" "$create_out" "SUCCESS\|REL_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM release_mgmt WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "REL_CREATE|REL-W17-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "REL_GET ok" "$(run_cobol "REL_GET|${id}|||||admin@test.com")" "SUCCESS\|REL_GET\|${id}\|REL-W17-1"
assert_match "REL_LIST ok" "$(run_cobol "REL_LIST|||50|0||admin@test.com")" "REL-W17-1"

# Allocate.
assert_match "REL_CALC ok" "$(run_cobol "REL_CALC|${id}|||||admin@test.com")" "SUCCESS\|REL_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM release_mgmt WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "REL_DELETE ok" "$(run_cobol "REL_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|REL_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM release_mgmt WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "REL_SUMMARY ok" "$(run_cobol "REL_SUMMARY||||||admin@test.com")" "SUCCESS\|REL_SUMMARY"
assert_match "REL_AUDIT ok" "$(run_cobol "REL_AUDIT|50|0||||admin@test.com")" "SUCCESS\|REL_AUDIT"
assert_match "REL_VALIDATE ok" "$(run_cobol "REL_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|REL_VALID"
assert_match "non-admin refused" "$(run_cobol "REL_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"


# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM release_mgmt WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM release_mgmt_audit WHERE release_mgmt_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "REL_UPDATE|${id}|ReleaseA|MAJOR|||admin@test.com")"
assert_match "REL_UPDATE ok" "$upd_out" "SUCCESS\\|REL_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM release_mgmt WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM release_mgmt_audit WHERE release_mgmt_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "REL_UPDATE|999999|ReleaseA|MAJOR|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "REL_UPDATE|${id}|ReleaseA|MAJOR|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0