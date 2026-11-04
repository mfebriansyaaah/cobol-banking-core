#!/usr/bin/env bash
# Metric (Wave10) end-to-end DB tests via the COBOL binary.
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
db_reset_metric

# Create a cost center.
create_out="$(run_cobol "MET_CREATE|MET-W10-1|EntityA|COUNT|||admin@test.com")"
assert_match "MET_CREATE ok" "$create_out" "SUCCESS\|MET_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM metric WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "MET_CREATE|MET-W10-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "MET_GET ok" "$(run_cobol "MET_GET|${id}|||||admin@test.com")" "SUCCESS\|MET_GET\|${id}\|MET-W10-1"
assert_match "MET_LIST ok" "$(run_cobol "MET_LIST|||50|0||admin@test.com")" "MET-W10-1"

# Allocate.
assert_match "MET_CALC ok" "$(run_cobol "MET_CALC|${id}|||||admin@test.com")" "SUCCESS\|MET_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM metric WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "MET_DELETE ok" "$(run_cobol "MET_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|MET_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM metric WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "MET_SUMMARY ok" "$(run_cobol "MET_SUMMARY||||||admin@test.com")" "SUCCESS\|MET_SUMMARY"
assert_match "MET_AUDIT ok" "$(run_cobol "MET_AUDIT|50|0||||admin@test.com")" "SUCCESS\|MET_AUDIT"
assert_match "MET_VALIDATE ok" "$(run_cobol "MET_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|MET_VALID"
assert_match "non-admin refused" "$(run_cobol "MET_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"


# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM metric WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM metric_audit WHERE metric_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "MET_UPDATE|${id}|EntityA|COUNT|||admin@test.com")"
assert_match "MET_UPDATE ok" "$upd_out" "SUCCESS\\|MET_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM metric WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM metric_audit WHERE metric_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "MET_UPDATE|999999|EntityA|COUNT|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "MET_UPDATE|${id}|EntityA|COUNT|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0