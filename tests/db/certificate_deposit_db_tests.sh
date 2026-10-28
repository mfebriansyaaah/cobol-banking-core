#!/usr/bin/env bash
# Certificate deposit (Wave9) end-to-end DB tests via the COBOL binary.
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
db_reset_certificate_deposit

# Create a cost center.
create_out="$(run_cobol "CDP_CREATE|CDP-W9-1|DepositorA|CD|||admin@test.com")"
assert_match "CDP_CREATE ok" "$create_out" "SUCCESS\|CDP_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM certificate_deposit WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "CDP_CREATE|CDP-W9-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "CDP_GET ok" "$(run_cobol "CDP_GET|${id}|||||admin@test.com")" "SUCCESS\|CDP_GET\|${id}\|CDP-W9-1"
assert_match "CDP_LIST ok" "$(run_cobol "CDP_LIST|||50|0||admin@test.com")" "CDP-W9-1"

# Allocate.
assert_match "CDP_CALC ok" "$(run_cobol "CDP_CALC|${id}|||||admin@test.com")" "SUCCESS\|CDP_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM certificate_deposit WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "CDP_DELETE ok" "$(run_cobol "CDP_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|CDP_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM certificate_deposit WHERE id=${id};")" "^MATURED$"

# Summary and audit.
assert_match "CDP_SUMMARY ok" "$(run_cobol "CDP_SUMMARY||||||admin@test.com")" "SUCCESS\|CDP_SUMMARY"
assert_match "CDP_AUDIT ok" "$(run_cobol "CDP_AUDIT|50|0||||admin@test.com")" "SUCCESS\|CDP_AUDIT"
assert_match "CDP_VALIDATE ok" "$(run_cobol "CDP_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|CDP_VALID"
assert_match "non-admin refused" "$(run_cobol "CDP_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0