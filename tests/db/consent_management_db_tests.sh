#!/usr/bin/env bash
# Consent management (Wave6) end-to-end DB tests via the COBOL binary.
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
db_reset_consent_management

# Create a cost center.
create_out="$(run_cobol "CSN_CREATE|CSN-W6-1|ConsentA|ACCOUNT|||admin@test.com")"
assert_match "CSN_CREATE ok" "$create_out" "SUCCESS\|CSN_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM consent_management WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "CSN_CREATE|CSN-W6-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "CSN_GET ok" "$(run_cobol "CSN_GET|${id}|||||admin@test.com")" "SUCCESS\|CSN_GET\|${id}\|CSN-W6-1"
assert_match "CSN_LIST ok" "$(run_cobol "CSN_LIST|||50|0||admin@test.com")" "CSN-W6-1"

# Allocate.
assert_match "CSN_CALC ok" "$(run_cobol "CSN_CALC|${id}|||||admin@test.com")" "SUCCESS\|CSN_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM consent_management WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "CSN_DELETE ok" "$(run_cobol "CSN_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|CSN_DELETE"
assert_match "revoked persisted" "$(db_query "SELECT status FROM consent_management WHERE id=${id};")" "^REVOKED$"

# Summary and audit.
assert_match "CSN_SUMMARY ok" "$(run_cobol "CSN_SUMMARY||||||admin@test.com")" "SUCCESS\|CSN_SUMMARY"
assert_match "CSN_AUDIT ok" "$(run_cobol "CSN_AUDIT|50|0||||admin@test.com")" "SUCCESS\|CSN_AUDIT"
assert_match "CSN_VALIDATE ok" "$(run_cobol "CSN_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|CSN_VALID"
assert_match "non-admin refused" "$(run_cobol "CSN_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0