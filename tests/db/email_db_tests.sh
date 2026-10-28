#!/usr/bin/env bash
# Email (Wave11) end-to-end DB tests via the COBOL binary.
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
db_reset_email

# Create a cost center.
create_out="$(run_cobol "EML_CREATE|EML-W11-1|SenderA|SMTP|||admin@test.com")"
assert_match "EML_CREATE ok" "$create_out" "SUCCESS\|EML_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM email WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "EML_CREATE|EML-W11-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "EML_GET ok" "$(run_cobol "EML_GET|${id}|||||admin@test.com")" "SUCCESS\|EML_GET\|${id}\|EML-W11-1"
assert_match "EML_LIST ok" "$(run_cobol "EML_LIST|||50|0||admin@test.com")" "EML-W11-1"

# Allocate.
assert_match "EML_CALC ok" "$(run_cobol "EML_CALC|${id}|||||admin@test.com")" "SUCCESS\|EML_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM email WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "EML_DELETE ok" "$(run_cobol "EML_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|EML_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM email WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "EML_SUMMARY ok" "$(run_cobol "EML_SUMMARY||||||admin@test.com")" "SUCCESS\|EML_SUMMARY"
assert_match "EML_AUDIT ok" "$(run_cobol "EML_AUDIT|50|0||||admin@test.com")" "SUCCESS\|EML_AUDIT"
assert_match "EML_VALIDATE ok" "$(run_cobol "EML_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|EML_VALID"
assert_match "non-admin refused" "$(run_cobol "EML_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0