#!/usr/bin/env bash
# Policy review (Wave17) end-to-end DB tests via the COBOL binary.
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
db_reset_policy_review

# Create a cost center.
create_out="$(run_cobol "PLR_CREATE|PLR-W17-1|PolicyA|ANNUAL|||admin@test.com")"
assert_match "PLR_CREATE ok" "$create_out" "SUCCESS\|PLR_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM policy_review WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "PLR_CREATE|PLR-W17-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "PLR_GET ok" "$(run_cobol "PLR_GET|${id}|||||admin@test.com")" "SUCCESS\|PLR_GET\|${id}\|PLR-W17-1"
assert_match "PLR_LIST ok" "$(run_cobol "PLR_LIST|||50|0||admin@test.com")" "PLR-W17-1"

# Allocate.
assert_match "PLR_CALC ok" "$(run_cobol "PLR_CALC|${id}|||||admin@test.com")" "SUCCESS\|PLR_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM policy_review WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "PLR_DELETE ok" "$(run_cobol "PLR_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|PLR_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM policy_review WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "PLR_SUMMARY ok" "$(run_cobol "PLR_SUMMARY||||||admin@test.com")" "SUCCESS\|PLR_SUMMARY"
assert_match "PLR_AUDIT ok" "$(run_cobol "PLR_AUDIT|50|0||||admin@test.com")" "SUCCESS\|PLR_AUDIT"
assert_match "PLR_VALIDATE ok" "$(run_cobol "PLR_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|PLR_VALID"
assert_match "non-admin refused" "$(run_cobol "PLR_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"


# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM policy_review WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM policy_review_audit WHERE policy_review_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "PLR_UPDATE|${id}|PolicyA|ANNUAL|||admin@test.com")"
assert_match "PLR_UPDATE ok" "$upd_out" "SUCCESS\\|PLR_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM policy_review WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM policy_review_audit WHERE policy_review_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "PLR_UPDATE|999999|PolicyA|ANNUAL|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "PLR_UPDATE|${id}|PolicyA|ANNUAL|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0