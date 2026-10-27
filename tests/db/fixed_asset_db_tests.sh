#!/usr/bin/env bash
# Fixed asset (D15) end-to-end DB tests via the COBOL binary.
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
db_reset_fixed_asset

# Create a cost center.
create_out="$(run_cobol "FAS_CREATE|FAS-D15-1|Laptop|IT|||admin@test.com")"
assert_match "FAS_CREATE ok" "$create_out" "SUCCESS\|FAS_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM fixed_asset WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "FAS_CREATE|FAS-D15-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "FAS_GET ok" "$(run_cobol "FAS_GET|${id}|||||admin@test.com")" "SUCCESS\|FAS_GET\|${id}\|FAS-D15-1"
assert_match "FAS_LIST ok" "$(run_cobol "FAS_LIST||IT|50|0||admin@test.com")" "FAS-D15-1"

# Allocate.
assert_match "FAS_CALC ok" "$(run_cobol "FAS_CALC|${id}|||||admin@test.com")" "SUCCESS\|FAS_CALC\|1"
assert_match "depreciation persisted" "$(db_query "SELECT accumulated_depreciation FROM fixed_asset WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "FAS_DELETE ok" "$(run_cobol "FAS_DELETE|${id}|Disposed||||admin@test.com")" "SUCCESS\|FAS_DELETE"
assert_match "disposed persisted" "$(db_query "SELECT status FROM fixed_asset WHERE id=${id};")" "^DISPOSED$"

# Summary and audit.
assert_match "FAS_SUMMARY ok" "$(run_cobol "FAS_SUMMARY||||||admin@test.com")" "SUCCESS\|FAS_SUMMARY"
assert_match "FAS_AUDIT ok" "$(run_cobol "FAS_AUDIT|50|0||||admin@test.com")" "SUCCESS\|FAS_AUDIT"
assert_match "FAS_VALIDATE ok" "$(run_cobol "FAS_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|FAS_VALID"
assert_match "non-admin refused" "$(run_cobol "FAS_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0