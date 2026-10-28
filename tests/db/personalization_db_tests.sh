#!/usr/bin/env bash
# Personalization (Wave11) end-to-end DB tests via the COBOL binary.
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
db_reset_personalization

# Create a cost center.
create_out="$(run_cobol "PSN_CREATE|PSN-W11-1|EntityA|CONTENT|||admin@test.com")"
assert_match "PSN_CREATE ok" "$create_out" "SUCCESS\|PSN_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM personalization WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "PSN_CREATE|PSN-W11-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "PSN_GET ok" "$(run_cobol "PSN_GET|${id}|||||admin@test.com")" "SUCCESS\|PSN_GET\|${id}\|PSN-W11-1"
assert_match "PSN_LIST ok" "$(run_cobol "PSN_LIST|||50|0||admin@test.com")" "PSN-W11-1"

# Allocate.
assert_match "PSN_CALC ok" "$(run_cobol "PSN_CALC|${id}|||||admin@test.com")" "SUCCESS\|PSN_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM personalization WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "PSN_DELETE ok" "$(run_cobol "PSN_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|PSN_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM personalization WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "PSN_SUMMARY ok" "$(run_cobol "PSN_SUMMARY||||||admin@test.com")" "SUCCESS\|PSN_SUMMARY"
assert_match "PSN_AUDIT ok" "$(run_cobol "PSN_AUDIT|50|0||||admin@test.com")" "SUCCESS\|PSN_AUDIT"
assert_match "PSN_VALIDATE ok" "$(run_cobol "PSN_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|PSN_VALID"
assert_match "non-admin refused" "$(run_cobol "PSN_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0