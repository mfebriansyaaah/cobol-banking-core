#!/usr/bin/env bash
# Private debt (Wave12) end-to-end DB tests via the COBOL binary.
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
db_reset_private_debt

# Create a cost center.
create_out="$(run_cobol "PDB_CREATE|PDB-W12-1|BorrowerA|DIRECT|||admin@test.com")"
assert_match "PDB_CREATE ok" "$create_out" "SUCCESS\|PDB_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM private_debt WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "PDB_CREATE|PDB-W12-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "PDB_GET ok" "$(run_cobol "PDB_GET|${id}|||||admin@test.com")" "SUCCESS\|PDB_GET\|${id}\|PDB-W12-1"
assert_match "PDB_LIST ok" "$(run_cobol "PDB_LIST|||50|0||admin@test.com")" "PDB-W12-1"

# Allocate.
assert_match "PDB_CALC ok" "$(run_cobol "PDB_CALC|${id}|||||admin@test.com")" "SUCCESS\|PDB_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM private_debt WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "PDB_DELETE ok" "$(run_cobol "PDB_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|PDB_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM private_debt WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "PDB_SUMMARY ok" "$(run_cobol "PDB_SUMMARY||||||admin@test.com")" "SUCCESS\|PDB_SUMMARY"
assert_match "PDB_AUDIT ok" "$(run_cobol "PDB_AUDIT|50|0||||admin@test.com")" "SUCCESS\|PDB_AUDIT"
assert_match "PDB_VALIDATE ok" "$(run_cobol "PDB_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|PDB_VALID"
assert_match "non-admin refused" "$(run_cobol "PDB_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"


# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM private_debt WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM private_debt_audit WHERE private_debt_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "PDB_UPDATE|${id}|BorrowerA|DIRECT|||admin@test.com")"
assert_match "PDB_UPDATE ok" "$upd_out" "SUCCESS\\|PDB_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM private_debt WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM private_debt_audit WHERE private_debt_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "PDB_UPDATE|999999|BorrowerA|DIRECT|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "PDB_UPDATE|${id}|BorrowerA|DIRECT|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0