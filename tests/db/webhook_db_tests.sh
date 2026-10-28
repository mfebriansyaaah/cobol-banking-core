#!/usr/bin/env bash
# Webhook (Wave11) end-to-end DB tests via the COBOL binary.
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
db_reset_webhook

# Create a cost center.
create_out="$(run_cobol "WHK_CREATE|WHK-W11-1|SourceA|OUTBOUND|||admin@test.com")"
assert_match "WHK_CREATE ok" "$create_out" "SUCCESS\|WHK_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM webhook WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "WHK_CREATE|WHK-W11-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "WHK_GET ok" "$(run_cobol "WHK_GET|${id}|||||admin@test.com")" "SUCCESS\|WHK_GET\|${id}\|WHK-W11-1"
assert_match "WHK_LIST ok" "$(run_cobol "WHK_LIST|||50|0||admin@test.com")" "WHK-W11-1"

# Allocate.
assert_match "WHK_CALC ok" "$(run_cobol "WHK_CALC|${id}|||||admin@test.com")" "SUCCESS\|WHK_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM webhook WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "WHK_DELETE ok" "$(run_cobol "WHK_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|WHK_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM webhook WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "WHK_SUMMARY ok" "$(run_cobol "WHK_SUMMARY||||||admin@test.com")" "SUCCESS\|WHK_SUMMARY"
assert_match "WHK_AUDIT ok" "$(run_cobol "WHK_AUDIT|50|0||||admin@test.com")" "SUCCESS\|WHK_AUDIT"
assert_match "WHK_VALIDATE ok" "$(run_cobol "WHK_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|WHK_VALID"
assert_match "non-admin refused" "$(run_cobol "WHK_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0