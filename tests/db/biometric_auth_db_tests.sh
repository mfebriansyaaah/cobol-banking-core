#!/usr/bin/env bash
# Biometric auth (Wave8) end-to-end DB tests via the COBOL binary.
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
db_reset_biometric_auth

# Create a cost center.
create_out="$(run_cobol "BMA_CREATE|BMA-W8-1|UserA|FINGERPRINT|||admin@test.com")"
assert_match "BMA_CREATE ok" "$create_out" "SUCCESS\|BMA_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM biometric_auth WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "BMA_CREATE|BMA-W8-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "BMA_GET ok" "$(run_cobol "BMA_GET|${id}|||||admin@test.com")" "SUCCESS\|BMA_GET\|${id}\|BMA-W8-1"
assert_match "BMA_LIST ok" "$(run_cobol "BMA_LIST|||50|0||admin@test.com")" "BMA-W8-1"

# Allocate.
assert_match "BMA_CALC ok" "$(run_cobol "BMA_CALC|${id}|||||admin@test.com")" "SUCCESS\|BMA_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM biometric_auth WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "BMA_DELETE ok" "$(run_cobol "BMA_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|BMA_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM biometric_auth WHERE id=${id};")" "^DISABLED$"

# Summary and audit.
assert_match "BMA_SUMMARY ok" "$(run_cobol "BMA_SUMMARY||||||admin@test.com")" "SUCCESS\|BMA_SUMMARY"
assert_match "BMA_AUDIT ok" "$(run_cobol "BMA_AUDIT|50|0||||admin@test.com")" "SUCCESS\|BMA_AUDIT"
assert_match "BMA_VALIDATE ok" "$(run_cobol "BMA_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|BMA_VALID"
assert_match "non-admin refused" "$(run_cobol "BMA_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0