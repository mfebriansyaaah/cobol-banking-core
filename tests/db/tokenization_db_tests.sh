#!/usr/bin/env bash
# Tokenization (Wave6) end-to-end DB tests via the COBOL binary.
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
db_reset_tokenization

# Create a cost center.
create_out="$(run_cobol "TKN_CREATE|TKN-W6-1|TokenA|UTILITY|||admin@test.com")"
assert_match "TKN_CREATE ok" "$create_out" "SUCCESS\|TKN_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM tokenization WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "TKN_CREATE|TKN-W6-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "TKN_GET ok" "$(run_cobol "TKN_GET|${id}|||||admin@test.com")" "SUCCESS\|TKN_GET\|${id}\|TKN-W6-1"
assert_match "TKN_LIST ok" "$(run_cobol "TKN_LIST|||50|0||admin@test.com")" "TKN-W6-1"

# Allocate.
assert_match "TKN_CALC ok" "$(run_cobol "TKN_CALC|${id}|||||admin@test.com")" "SUCCESS\|TKN_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM tokenization WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "TKN_DELETE ok" "$(run_cobol "TKN_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|TKN_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM tokenization WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "TKN_SUMMARY ok" "$(run_cobol "TKN_SUMMARY||||||admin@test.com")" "SUCCESS\|TKN_SUMMARY"
assert_match "TKN_AUDIT ok" "$(run_cobol "TKN_AUDIT|50|0||||admin@test.com")" "SUCCESS\|TKN_AUDIT"
assert_match "TKN_VALIDATE ok" "$(run_cobol "TKN_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|TKN_VALID"
assert_match "non-admin refused" "$(run_cobol "TKN_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0