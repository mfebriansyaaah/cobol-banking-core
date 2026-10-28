#!/usr/bin/env bash
# FX forward (Wave9) end-to-end DB tests via the COBOL binary.
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
db_reset_fx_forward

# Create a cost center.
create_out="$(run_cobol "FXF_CREATE|FXF-W9-1|CounterpartyA|FORWARD|||admin@test.com")"
assert_match "FXF_CREATE ok" "$create_out" "SUCCESS\|FXF_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM fx_forward WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "FXF_CREATE|FXF-W9-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "FXF_GET ok" "$(run_cobol "FXF_GET|${id}|||||admin@test.com")" "SUCCESS\|FXF_GET\|${id}\|FXF-W9-1"
assert_match "FXF_LIST ok" "$(run_cobol "FXF_LIST|||50|0||admin@test.com")" "FXF-W9-1"

# Allocate.
assert_match "FXF_CALC ok" "$(run_cobol "FXF_CALC|${id}|||||admin@test.com")" "SUCCESS\|FXF_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM fx_forward WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "FXF_DELETE ok" "$(run_cobol "FXF_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|FXF_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM fx_forward WHERE id=${id};")" "^SETTLED$"

# Summary and audit.
assert_match "FXF_SUMMARY ok" "$(run_cobol "FXF_SUMMARY||||||admin@test.com")" "SUCCESS\|FXF_SUMMARY"
assert_match "FXF_AUDIT ok" "$(run_cobol "FXF_AUDIT|50|0||||admin@test.com")" "SUCCESS\|FXF_AUDIT"
assert_match "FXF_VALIDATE ok" "$(run_cobol "FXF_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|FXF_VALID"
assert_match "non-admin refused" "$(run_cobol "FXF_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0