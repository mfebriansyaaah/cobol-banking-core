#!/usr/bin/env bash
# Revenue (Wave9) end-to-end DB tests via the COBOL binary.
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
db_reset_revenue

# Create a cost center.
create_out="$(run_cobol "REV_CREATE|REV-W9-1|EntityA|FEE|||admin@test.com")"
assert_match "REV_CREATE ok" "$create_out" "SUCCESS\|REV_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM revenue WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "REV_CREATE|REV-W9-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "REV_GET ok" "$(run_cobol "REV_GET|${id}|||||admin@test.com")" "SUCCESS\|REV_GET\|${id}\|REV-W9-1"
assert_match "REV_LIST ok" "$(run_cobol "REV_LIST|||50|0||admin@test.com")" "REV-W9-1"

# Allocate.
assert_match "REV_CALC ok" "$(run_cobol "REV_CALC|${id}|||||admin@test.com")" "SUCCESS\|REV_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM revenue WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "REV_DELETE ok" "$(run_cobol "REV_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|REV_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM revenue WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "REV_SUMMARY ok" "$(run_cobol "REV_SUMMARY||||||admin@test.com")" "SUCCESS\|REV_SUMMARY"
assert_match "REV_AUDIT ok" "$(run_cobol "REV_AUDIT|50|0||||admin@test.com")" "SUCCESS\|REV_AUDIT"
assert_match "REV_VALIDATE ok" "$(run_cobol "REV_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|REV_VALID"
assert_match "non-admin refused" "$(run_cobol "REV_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"


# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM revenue WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM revenue_audit WHERE revenue_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "REV_UPDATE|${id}|EntityA|FEE|||admin@test.com")"
assert_match "REV_UPDATE ok" "$upd_out" "SUCCESS\\|REV_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM revenue WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM revenue_audit WHERE revenue_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "REV_UPDATE|999999|EntityA|FEE|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "REV_UPDATE|${id}|EntityA|FEE|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0