#!/usr/bin/env bash
# Retry (Wave11) end-to-end DB tests via the COBOL binary.
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
db_reset_retry

# Create a cost center.
create_out="$(run_cobol "RTY_CREATE|RTY-W11-1|OperationA|EXPONENTIAL|||admin@test.com")"
assert_match "RTY_CREATE ok" "$create_out" "SUCCESS\|RTY_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM retry WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "RTY_CREATE|RTY-W11-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "RTY_GET ok" "$(run_cobol "RTY_GET|${id}|||||admin@test.com")" "SUCCESS\|RTY_GET\|${id}\|RTY-W11-1"
assert_match "RTY_LIST ok" "$(run_cobol "RTY_LIST|||50|0||admin@test.com")" "RTY-W11-1"

# Allocate.
assert_match "RTY_CALC ok" "$(run_cobol "RTY_CALC|${id}|||||admin@test.com")" "SUCCESS\|RTY_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM retry WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "RTY_DELETE ok" "$(run_cobol "RTY_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|RTY_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM retry WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "RTY_SUMMARY ok" "$(run_cobol "RTY_SUMMARY||||||admin@test.com")" "SUCCESS\|RTY_SUMMARY"
assert_match "RTY_AUDIT ok" "$(run_cobol "RTY_AUDIT|50|0||||admin@test.com")" "SUCCESS\|RTY_AUDIT"
assert_match "RTY_VALIDATE ok" "$(run_cobol "RTY_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|RTY_VALID"
assert_match "non-admin refused" "$(run_cobol "RTY_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"


# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM retry WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM retry_audit WHERE retry_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "RTY_UPDATE|${id}|OperationA|EXPONENTIAL|||admin@test.com")"
assert_match "RTY_UPDATE ok" "$upd_out" "SUCCESS\\|RTY_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM retry WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM retry_audit WHERE retry_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "RTY_UPDATE|999999|OperationA|EXPONENTIAL|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "RTY_UPDATE|${id}|OperationA|EXPONENTIAL|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0