#!/usr/bin/env bash
# Profit (Wave9) end-to-end DB tests via the COBOL binary.
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
db_reset_profit

# Create a cost center.
create_out="$(run_cobol "PRF_CREATE|PRF-W9-1|EntityA|NET|||admin@test.com")"
assert_match "PRF_CREATE ok" "$create_out" "SUCCESS\|PRF_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM profit WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "PRF_CREATE|PRF-W9-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "PRF_GET ok" "$(run_cobol "PRF_GET|${id}|||||admin@test.com")" "SUCCESS\|PRF_GET\|${id}\|PRF-W9-1"
assert_match "PRF_LIST ok" "$(run_cobol "PRF_LIST|||50|0||admin@test.com")" "PRF-W9-1"

# Allocate.
assert_match "PRF_CALC ok" "$(run_cobol "PRF_CALC|${id}|||||admin@test.com")" "SUCCESS\|PRF_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM profit WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "PRF_DELETE ok" "$(run_cobol "PRF_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|PRF_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM profit WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "PRF_SUMMARY ok" "$(run_cobol "PRF_SUMMARY||||||admin@test.com")" "SUCCESS\|PRF_SUMMARY"
assert_match "PRF_AUDIT ok" "$(run_cobol "PRF_AUDIT|50|0||||admin@test.com")" "SUCCESS\|PRF_AUDIT"
assert_match "PRF_VALIDATE ok" "$(run_cobol "PRF_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|PRF_VALID"
assert_match "non-admin refused" "$(run_cobol "PRF_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"


# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM profit WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM profit_audit WHERE profit_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "PRF_UPDATE|${id}|EntityA|NET|||admin@test.com")"
assert_match "PRF_UPDATE ok" "$upd_out" "SUCCESS\\|PRF_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM profit WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM profit_audit WHERE profit_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "PRF_UPDATE|999999|EntityA|NET|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "PRF_UPDATE|${id}|EntityA|NET|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0