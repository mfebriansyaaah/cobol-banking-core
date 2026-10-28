#!/usr/bin/env bash
# Portfolio management (Wave4) end-to-end DB tests via the COBOL binary.
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
db_reset_portfolio_management

# Create a cost center.
create_out="$(run_cobol "POM_CREATE|POM-W4-1|PortfolioA|GROWTH|||admin@test.com")"
assert_match "POM_CREATE ok" "$create_out" "SUCCESS\|POM_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM portfolio_management WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "POM_CREATE|POM-W4-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "POM_GET ok" "$(run_cobol "POM_GET|${id}|||||admin@test.com")" "SUCCESS\|POM_GET\|${id}\|POM-W4-1"
assert_match "POM_LIST ok" "$(run_cobol "POM_LIST|||50|0||admin@test.com")" "POM-W4-1"

# Allocate.
assert_match "POM_CALC ok" "$(run_cobol "POM_CALC|${id}|||||admin@test.com")" "SUCCESS\|POM_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT actual_return FROM portfolio_management WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "POM_DELETE ok" "$(run_cobol "POM_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|POM_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM portfolio_management WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "POM_SUMMARY ok" "$(run_cobol "POM_SUMMARY||||||admin@test.com")" "SUCCESS\|POM_SUMMARY"
assert_match "POM_AUDIT ok" "$(run_cobol "POM_AUDIT|50|0||||admin@test.com")" "SUCCESS\|POM_AUDIT"
assert_match "POM_VALIDATE ok" "$(run_cobol "POM_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|POM_VALID"
assert_match "non-admin refused" "$(run_cobol "POM_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0