#!/usr/bin/env bash
# Digital banking (Wave5) end-to-end DB tests via the COBOL binary.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/tests/lib/db.sh"
# shellcheck disable=SC1091
. "$ROOT/tests/lib/cobol.sh"
if ! db_available; then echo "SKIP: DB unavailable"; exit 0; fi

T_PASS=0; T_FAIL=0; T_TOTAL=0
# shellcheck disable=SC1091
. "$ROOT/tests/lib/assert.sh"

db_seed
db_reset_digital_banking

# Create a cost center.
create_out="$(run_cobol "DGB_CREATE|DGB-W5-1|ServiceA|MOBILE|||admin@test.com")"
assert_match "DGB_CREATE ok" "$create_out" "SUCCESS\|DGB_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM digital_banking WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "DGB_CREATE|DGB-W5-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "DGB_GET ok" "$(run_cobol "DGB_GET|${id}|||||admin@test.com")" "SUCCESS\|DGB_GET\|${id}\|DGB-W5-1"
assert_match "DGB_LIST ok" "$(run_cobol "DGB_LIST|||50|0||admin@test.com")" "DGB-W5-1"

# Allocate.
assert_match "DGB_CALC ok" "$(run_cobol "DGB_CALC|${id}|||||admin@test.com")" "SUCCESS\|DGB_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT current_usage FROM digital_banking WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "DGB_DELETE ok" "$(run_cobol "DGB_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|DGB_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM digital_banking WHERE id=${id};")" "^INACTIVE$"

# Summary and audit.
assert_match "DGB_SUMMARY ok" "$(run_cobol "DGB_SUMMARY||||||admin@test.com")" "SUCCESS\|DGB_SUMMARY"
assert_match "DGB_AUDIT ok" "$(run_cobol "DGB_AUDIT|50|0||||admin@test.com")" "SUCCESS\|DGB_AUDIT"
assert_match "DGB_VALIDATE ok" "$(run_cobol "DGB_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|DGB_VALID"
assert_match "non-admin refused" "$(run_cobol "DGB_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0