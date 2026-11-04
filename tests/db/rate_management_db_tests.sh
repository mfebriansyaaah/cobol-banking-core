#!/usr/bin/env bash
# Rate management (Wave5) end-to-end DB tests via the COBOL binary.
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
db_reset_rate_management

# Create a cost center.
create_out="$(run_cobol "RTM_CREATE|RTM-W5-1|RateA|FIXED|||admin@test.com")"
assert_match "RTM_CREATE ok" "$create_out" "SUCCESS\|RTM_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM rate_management WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "RTM_CREATE|RTM-W5-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "RTM_GET ok" "$(run_cobol "RTM_GET|${id}|||||admin@test.com")" "SUCCESS\|RTM_GET\|${id}\|RTM-W5-1"
assert_match "RTM_LIST ok" "$(run_cobol "RTM_LIST|||50|0||admin@test.com")" "RTM-W5-1"

# Allocate.
assert_match "RTM_CALC ok" "$(run_cobol "RTM_CALC|${id}|||||admin@test.com")" "SUCCESS\|RTM_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT current_rate FROM rate_management WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "RTM_DELETE ok" "$(run_cobol "RTM_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|RTM_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM rate_management WHERE id=${id};")" "^INACTIVE$"

# Summary and audit.
assert_match "RTM_SUMMARY ok" "$(run_cobol "RTM_SUMMARY||||||admin@test.com")" "SUCCESS\|RTM_SUMMARY"
assert_match "RTM_AUDIT ok" "$(run_cobol "RTM_AUDIT|50|0||||admin@test.com")" "SUCCESS\|RTM_AUDIT"
assert_match "RTM_VALIDATE ok" "$(run_cobol "RTM_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|RTM_VALID"
assert_match "non-admin refused" "$(run_cobol "RTM_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"


# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM rate_management WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM rate_management_audit WHERE rate_management_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "RTM_UPDATE|${id}|RateA|FIXED|||admin@test.com")"
assert_match "RTM_UPDATE ok" "$upd_out" "SUCCESS\\|RTM_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM rate_management WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM rate_management_audit WHERE rate_management_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "RTM_UPDATE|999999|RateA|FIXED|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "RTM_UPDATE|${id}|RateA|FIXED|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0