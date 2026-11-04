#!/usr/bin/env bash
# Public liability (Wave18) end-to-end DB tests via the COBOL binary.
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
db_reset_public_liability

# Create a cost center.
create_out="$(run_cobol "PUL_CREATE|PUL-W18-1|BusinessA|BUSINESS|||admin@test.com")"
assert_match "PUL_CREATE ok" "$create_out" "SUCCESS\|PUL_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM public_liability WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "PUL_CREATE|PUL-W18-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "PUL_GET ok" "$(run_cobol "PUL_GET|${id}|||||admin@test.com")" "SUCCESS\|PUL_GET\|${id}\|PUL-W18-1"
assert_match "PUL_LIST ok" "$(run_cobol "PUL_LIST|||50|0||admin@test.com")" "PUL-W18-1"

# Allocate.
assert_match "PUL_CALC ok" "$(run_cobol "PUL_CALC|${id}|||||admin@test.com")" "SUCCESS\|PUL_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM public_liability WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "PUL_DELETE ok" "$(run_cobol "PUL_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|PUL_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM public_liability WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "PUL_SUMMARY ok" "$(run_cobol "PUL_SUMMARY||||||admin@test.com")" "SUCCESS\|PUL_SUMMARY"
assert_match "PUL_AUDIT ok" "$(run_cobol "PUL_AUDIT|50|0||||admin@test.com")" "SUCCESS\|PUL_AUDIT"
assert_match "PUL_VALIDATE ok" "$(run_cobol "PUL_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|PUL_VALID"
assert_match "non-admin refused" "$(run_cobol "PUL_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"


# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM public_liability WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM public_liability_audit WHERE public_liability_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "PUL_UPDATE|${id}|BusinessA|BUSINESS|||admin@test.com")"
assert_match "PUL_UPDATE ok" "$upd_out" "SUCCESS\\|PUL_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM public_liability WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM public_liability_audit WHERE public_liability_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "PUL_UPDATE|999999|BusinessA|BUSINESS|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "PUL_UPDATE|${id}|BusinessA|BUSINESS|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0