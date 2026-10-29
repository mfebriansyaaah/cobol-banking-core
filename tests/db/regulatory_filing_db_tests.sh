#!/usr/bin/env bash
# Regulatory filing (Wave17) end-to-end DB tests via the COBOL binary.
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
db_reset_regulatory_filing

# Create a cost center.
create_out="$(run_cobol "RGF_CREATE|RGF-W17-1|FilingA|OJK|||admin@test.com")"
assert_match "RGF_CREATE ok" "$create_out" "SUCCESS\|RGF_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM regulatory_filing WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "RGF_CREATE|RGF-W17-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "RGF_GET ok" "$(run_cobol "RGF_GET|${id}|||||admin@test.com")" "SUCCESS\|RGF_GET\|${id}\|RGF-W17-1"
assert_match "RGF_LIST ok" "$(run_cobol "RGF_LIST|||50|0||admin@test.com")" "RGF-W17-1"

# Allocate.
assert_match "RGF_CALC ok" "$(run_cobol "RGF_CALC|${id}|||||admin@test.com")" "SUCCESS\|RGF_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM regulatory_filing WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "RGF_DELETE ok" "$(run_cobol "RGF_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|RGF_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM regulatory_filing WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "RGF_SUMMARY ok" "$(run_cobol "RGF_SUMMARY||||||admin@test.com")" "SUCCESS\|RGF_SUMMARY"
assert_match "RGF_AUDIT ok" "$(run_cobol "RGF_AUDIT|50|0||||admin@test.com")" "SUCCESS\|RGF_AUDIT"
assert_match "RGF_VALIDATE ok" "$(run_cobol "RGF_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|RGF_VALID"
assert_match "non-admin refused" "$(run_cobol "RGF_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0