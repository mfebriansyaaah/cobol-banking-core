#!/usr/bin/env bash
# AML check (Wave13) end-to-end DB tests via the COBOL binary.
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
db_reset_aml_check

# Create a cost center.
create_out="$(run_cobol "AMLC_CREATE|AMLC-W13-1|EntityA|SANCTIONS|||admin@test.com")"
assert_match "AMLC_CREATE ok" "$create_out" "SUCCESS\|AMLC_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM aml_check WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "AMLC_CREATE|AMLC-W13-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "AMLC_GET ok" "$(run_cobol "AMLC_GET|${id}|||||admin@test.com")" "SUCCESS\|AMLC_GET\|${id}\|AMLC-W13-1"
assert_match "AMLC_LIST ok" "$(run_cobol "AMLC_LIST|||50|0||admin@test.com")" "AMLC-W13-1"

# Allocate.
assert_match "AMLC_CALC ok" "$(run_cobol "AMLC_CALC|${id}|||||admin@test.com")" "SUCCESS\|AMLC_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM aml_check WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "AMLC_DELETE ok" "$(run_cobol "AMLC_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|AMLC_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM aml_check WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "AMLC_SUMMARY ok" "$(run_cobol "AMLC_SUMMARY||||||admin@test.com")" "SUCCESS\|AMLC_SUMMARY"
assert_match "AMLC_AUDIT ok" "$(run_cobol "AMLC_AUDIT|50|0||||admin@test.com")" "SUCCESS\|AMLC_AUDIT"
assert_match "AMLC_VALIDATE ok" "$(run_cobol "AMLC_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|AMLC_VALID"
assert_match "non-admin refused" "$(run_cobol "AMLC_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0