#!/usr/bin/env bash
# Sanctions list (D12) end-to-end DB tests via the COBOL binary.
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
db_reset_sanctions_list

# Create a sanctions list entry.
create_out="$(run_cobol "SCL_CREATE|SCL-D12-1|North Korea|UN_SANCTIONS|||admin@test.com")"
assert_match "SCL_CREATE ok" "$create_out" "SUCCESS\|SCL_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM sanctions_list WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "SCL_CREATE|SCL-D12-1|Other|OFAC|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "SCL_GET ok" "$(run_cobol "SCL_GET|${id}|||||admin@test.com")" "SUCCESS\|SCL_GET\|${id}\|SCL-D12-1"
assert_match "SCL_LIST ok" "$(run_cobol "SCL_LIST||UN_SANCTIONS|50|0||admin@test.com")" "SCL-D12-1"

# Check (screen).
assert_match "SCL_SCREEN ok" "$(run_cobol "SCL_SCREEN|${id}|||||admin@test.com")" "SUCCESS\|SCL_SCREEN\|1"
assert_match "match_count persisted" "$(db_query "SELECT match_count FROM sanctions_list WHERE id=${id};")" "^1$"

# Close.
assert_match "SCL_CLOSE ok" "$(run_cobol "SCL_CLOSE|${id}|Resolved||||admin@test.com")" "SUCCESS\|SCL_CLOSE"
assert_match "closed persisted" "$(db_query "SELECT status FROM sanctions_list WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "SCL_SUMMARY ok" "$(run_cobol "SCL_SUMMARY||||||admin@test.com")" "SUCCESS\|SCL_SUMMARY"
assert_match "SCL_AUDIT ok" "$(run_cobol "SCL_AUDIT|50|0||||admin@test.com")" "SUCCESS\|SCL_AUDIT"
assert_match "SCL_VALIDATE ok" "$(run_cobol "SCL_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|SCL_VALID"
assert_match "non-admin refused" "$(run_cobol "SCL_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0