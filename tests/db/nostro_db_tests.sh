#!/usr/bin/env bash
# Nostro (Wave13) end-to-end DB tests via the COBOL binary.
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
db_reset_nostro

# Create a cost center.
create_out="$(run_cobol "NOS_CREATE|NOS-W13-1|AccountA|USD|||admin@test.com")"
assert_match "NOS_CREATE ok" "$create_out" "SUCCESS\|NOS_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM nostro WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "NOS_CREATE|NOS-W13-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "NOS_GET ok" "$(run_cobol "NOS_GET|${id}|||||admin@test.com")" "SUCCESS\|NOS_GET\|${id}\|NOS-W13-1"
assert_match "NOS_LIST ok" "$(run_cobol "NOS_LIST|||50|0||admin@test.com")" "NOS-W13-1"

# Allocate.
assert_match "NOS_CALC ok" "$(run_cobol "NOS_CALC|${id}|||||admin@test.com")" "SUCCESS\|NOS_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM nostro WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "NOS_DELETE ok" "$(run_cobol "NOS_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|NOS_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM nostro WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "NOS_SUMMARY ok" "$(run_cobol "NOS_SUMMARY||||||admin@test.com")" "SUCCESS\|NOS_SUMMARY"
assert_match "NOS_AUDIT ok" "$(run_cobol "NOS_AUDIT|50|0||||admin@test.com")" "SUCCESS\|NOS_AUDIT"
assert_match "NOS_VALIDATE ok" "$(run_cobol "NOS_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|NOS_VALID"
assert_match "non-admin refused" "$(run_cobol "NOS_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"


# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM nostro WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM nostro_audit WHERE nostro_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "NOS_UPDATE|${id}|AccountA|USD|||admin@test.com")"
assert_match "NOS_UPDATE ok" "$upd_out" "SUCCESS\\|NOS_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM nostro WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM nostro_audit WHERE nostro_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "NOS_UPDATE|999999|AccountA|USD|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "NOS_UPDATE|${id}|AccountA|USD|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0