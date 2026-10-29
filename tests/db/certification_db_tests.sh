#!/usr/bin/env bash
# Certification (Wave17) end-to-end DB tests via the COBOL binary.
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
db_reset_certification

# Create a cost center.
create_out="$(run_cobol "CRTF_CREATE|CRTF-W17-1|HolderA|ISO|||admin@test.com")"
assert_match "CRTF_CREATE ok" "$create_out" "SUCCESS\|CRTF_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM certification WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "CRTF_CREATE|CRTF-W17-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "CRTF_GET ok" "$(run_cobol "CRTF_GET|${id}|||||admin@test.com")" "SUCCESS\|CRTF_GET\|${id}\|CRTF-W17-1"
assert_match "CRTF_LIST ok" "$(run_cobol "CRTF_LIST|||50|0||admin@test.com")" "CRTF-W17-1"

# Allocate.
assert_match "CRTF_CALC ok" "$(run_cobol "CRTF_CALC|${id}|||||admin@test.com")" "SUCCESS\|CRTF_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM certification WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "CRTF_DELETE ok" "$(run_cobol "CRTF_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|CRTF_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM certification WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "CRTF_SUMMARY ok" "$(run_cobol "CRTF_SUMMARY||||||admin@test.com")" "SUCCESS\|CRTF_SUMMARY"
assert_match "CRTF_AUDIT ok" "$(run_cobol "CRTF_AUDIT|50|0||||admin@test.com")" "SUCCESS\|CRTF_AUDIT"
assert_match "CRTF_VALIDATE ok" "$(run_cobol "CRTF_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|CRTF_VALID"
assert_match "non-admin refused" "$(run_cobol "CRTF_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0