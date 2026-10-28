#!/usr/bin/env bash
# FX swap (Wave9) end-to-end DB tests via the COBOL binary.
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
db_reset_fx_swap

# Create a cost center.
create_out="$(run_cobol "FXS_CREATE|FXS-W9-1|CounterpartyA|CCS|||admin@test.com")"
assert_match "FXS_CREATE ok" "$create_out" "SUCCESS\|FXS_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM fx_swap WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "FXS_CREATE|FXS-W9-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "FXS_GET ok" "$(run_cobol "FXS_GET|${id}|||||admin@test.com")" "SUCCESS\|FXS_GET\|${id}\|FXS-W9-1"
assert_match "FXS_LIST ok" "$(run_cobol "FXS_LIST|||50|0||admin@test.com")" "FXS-W9-1"

# Allocate.
assert_match "FXS_CALC ok" "$(run_cobol "FXS_CALC|${id}|||||admin@test.com")" "SUCCESS\|FXS_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM fx_swap WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "FXS_DELETE ok" "$(run_cobol "FXS_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|FXS_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM fx_swap WHERE id=${id};")" "^MATURED$"

# Summary and audit.
assert_match "FXS_SUMMARY ok" "$(run_cobol "FXS_SUMMARY||||||admin@test.com")" "SUCCESS\|FXS_SUMMARY"
assert_match "FXS_AUDIT ok" "$(run_cobol "FXS_AUDIT|50|0||||admin@test.com")" "SUCCESS\|FXS_AUDIT"
assert_match "FXS_VALIDATE ok" "$(run_cobol "FXS_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|FXS_VALID"
assert_match "non-admin refused" "$(run_cobol "FXS_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0