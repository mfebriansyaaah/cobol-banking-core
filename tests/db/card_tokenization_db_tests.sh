#!/usr/bin/env bash
# Card tokenization (Wave8) end-to-end DB tests via the COBOL binary.
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
db_reset_card_tokenization

# Create a cost center.
create_out="$(run_cobol "CDT_CREATE|CDT-W8-1|CardholderA|APPLE_PAY|||admin@test.com")"
assert_match "CDT_CREATE ok" "$create_out" "SUCCESS\|CDT_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM card_tokenization WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "CDT_CREATE|CDT-W8-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "CDT_GET ok" "$(run_cobol "CDT_GET|${id}|||||admin@test.com")" "SUCCESS\|CDT_GET\|${id}\|CDT-W8-1"
assert_match "CDT_LIST ok" "$(run_cobol "CDT_LIST|||50|0||admin@test.com")" "CDT-W8-1"

# Allocate.
assert_match "CDT_CALC ok" "$(run_cobol "CDT_CALC|${id}|||||admin@test.com")" "SUCCESS\|CDT_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM card_tokenization WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "CDT_DELETE ok" "$(run_cobol "CDT_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|CDT_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM card_tokenization WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "CDT_SUMMARY ok" "$(run_cobol "CDT_SUMMARY||||||admin@test.com")" "SUCCESS\|CDT_SUMMARY"
assert_match "CDT_AUDIT ok" "$(run_cobol "CDT_AUDIT|50|0||||admin@test.com")" "SUCCESS\|CDT_AUDIT"
assert_match "CDT_VALIDATE ok" "$(run_cobol "CDT_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|CDT_VALID"
assert_match "non-admin refused" "$(run_cobol "CDT_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0