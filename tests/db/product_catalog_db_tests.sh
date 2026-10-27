#!/usr/bin/env bash
# Product catalog (Wave1) end-to-end DB tests via the COBOL binary.
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
db_reset_product_catalog

# Create a cost center.
create_out="$(run_cobol "PRD_CREATE|PRD-W1-1|Widget|SOFTWARE|||admin@test.com")"
assert_match "PRD_CREATE ok" "$create_out" "SUCCESS\|PRD_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM product_catalog WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "PRD_CREATE|PRD-W1-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "PRD_GET ok" "$(run_cobol "PRD_GET|${id}|||||admin@test.com")" "SUCCESS\|PRD_GET\|${id}\|PRD-W1-1"
assert_match "PRD_LIST ok" "$(run_cobol "PRD_LIST|||50|0||admin@test.com")" "PRD-W1-1"

# Allocate.
assert_match "PRD_CALC ok" "$(run_cobol "PRD_CALC|${id}|||||admin@test.com")" "SUCCESS\|PRD_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT discount_price FROM product_catalog WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "PRD_DELETE ok" "$(run_cobol "PRD_DELETE|${id}|Retired||||admin@test.com")" "SUCCESS\|PRD_DELETE"
assert_match "retired persisted" "$(db_query "SELECT status FROM product_catalog WHERE id=${id};")" "^RETIRED$"

# Summary and audit.
assert_match "PRD_SUMMARY ok" "$(run_cobol "PRD_SUMMARY||||||admin@test.com")" "SUCCESS\|PRD_SUMMARY"
assert_match "PRD_AUDIT ok" "$(run_cobol "PRD_AUDIT|50|0||||admin@test.com")" "SUCCESS\|PRD_AUDIT"
assert_match "PRD_VALIDATE ok" "$(run_cobol "PRD_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|PRD_VALID"
assert_match "non-admin refused" "$(run_cobol "PRD_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0