#!/usr/bin/env bash
# Surety (Wave18) end-to-end DB tests via the COBOL binary.
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
db_reset_surety

# Create a cost center.
create_out="$(run_cobol "SR_CREATE|SR-W18-1|PrincipalA|CONTRACT|||admin@test.com")"
assert_match "SR_CREATE ok" "$create_out" "SUCCESS\|SR_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM surety WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "SR_CREATE|SR-W18-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "SR_GET ok" "$(run_cobol "SR_GET|${id}|||||admin@test.com")" "SUCCESS\|SR_GET\|${id}\|SR-W18-1"
assert_match "SR_LIST ok" "$(run_cobol "SR_LIST|||50|0||admin@test.com")" "SR-W18-1"

# Allocate.
assert_match "SR_CALC ok" "$(run_cobol "SR_CALC|${id}|||||admin@test.com")" "SUCCESS\|SR_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM surety WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "SR_DELETE ok" "$(run_cobol "SR_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|SR_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM surety WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "SR_SUMMARY ok" "$(run_cobol "SR_SUMMARY||||||admin@test.com")" "SUCCESS\|SR_SUMMARY"
assert_match "SR_AUDIT ok" "$(run_cobol "SR_AUDIT|50|0||||admin@test.com")" "SUCCESS\|SR_AUDIT"
assert_match "SR_VALIDATE ok" "$(run_cobol "SR_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|SR_VALID"
assert_match "non-admin refused" "$(run_cobol "SR_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"


# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM surety WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM surety_audit WHERE surety_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "SR_UPDATE|${id}|PrincipalA|CONTRACT|||admin@test.com")"
assert_match "SR_UPDATE ok" "$upd_out" "SUCCESS\\|SR_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM surety WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM surety_audit WHERE surety_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "SR_UPDATE|999999|PrincipalA|CONTRACT|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "SR_UPDATE|${id}|PrincipalA|CONTRACT|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0