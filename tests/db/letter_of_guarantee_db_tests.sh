#!/usr/bin/env bash
# Letter of guarantee (Wave16) end-to-end DB tests via the COBOL binary.
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
db_reset_letter_of_guarantee

# Create a cost center.
create_out="$(run_cobol "LOGG_CREATE|LOGG-W16-1|ApplicantA|BID|||admin@test.com")"
assert_match "LOGG_CREATE ok" "$create_out" "SUCCESS\|LOGG_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM letter_of_guarantee WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "LOGG_CREATE|LOGG-W16-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "LOGG_GET ok" "$(run_cobol "LOGG_GET|${id}|||||admin@test.com")" "SUCCESS\|LOGG_GET\|${id}\|LOGG-W16-1"
assert_match "LOGG_LIST ok" "$(run_cobol "LOGG_LIST|||50|0||admin@test.com")" "LOGG-W16-1"

# Allocate.
assert_match "LOGG_CALC ok" "$(run_cobol "LOGG_CALC|${id}|||||admin@test.com")" "SUCCESS\|LOGG_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM letter_of_guarantee WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "LOGG_DELETE ok" "$(run_cobol "LOGG_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|LOGG_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM letter_of_guarantee WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "LOGG_SUMMARY ok" "$(run_cobol "LOGG_SUMMARY||||||admin@test.com")" "SUCCESS\|LOGG_SUMMARY"
assert_match "LOGG_AUDIT ok" "$(run_cobol "LOGG_AUDIT|50|0||||admin@test.com")" "SUCCESS\|LOGG_AUDIT"
assert_match "LOGG_VALIDATE ok" "$(run_cobol "LOGG_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|LOGG_VALID"
assert_match "non-admin refused" "$(run_cobol "LOGG_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0