#!/usr/bin/env bash
# Hotfix (Wave17) end-to-end DB tests via the COBOL binary.
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
db_reset_hotfix

# Create a cost center.
create_out="$(run_cobol "HFX_CREATE|HFX-W17-1|ServiceA|CRITICAL|||admin@test.com")"
assert_match "HFX_CREATE ok" "$create_out" "SUCCESS\|HFX_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM hotfix WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "HFX_CREATE|HFX-W17-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "HFX_GET ok" "$(run_cobol "HFX_GET|${id}|||||admin@test.com")" "SUCCESS\|HFX_GET\|${id}\|HFX-W17-1"
assert_match "HFX_LIST ok" "$(run_cobol "HFX_LIST|||50|0||admin@test.com")" "HFX-W17-1"

# Allocate.
assert_match "HFX_CALC ok" "$(run_cobol "HFX_CALC|${id}|||||admin@test.com")" "SUCCESS\|HFX_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM hotfix WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "HFX_DELETE ok" "$(run_cobol "HFX_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|HFX_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM hotfix WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "HFX_SUMMARY ok" "$(run_cobol "HFX_SUMMARY||||||admin@test.com")" "SUCCESS\|HFX_SUMMARY"
assert_match "HFX_AUDIT ok" "$(run_cobol "HFX_AUDIT|50|0||||admin@test.com")" "SUCCESS\|HFX_AUDIT"
assert_match "HFX_VALIDATE ok" "$(run_cobol "HFX_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|HFX_VALID"
assert_match "non-admin refused" "$(run_cobol "HFX_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0