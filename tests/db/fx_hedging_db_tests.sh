#!/usr/bin/env bash
# FX hedging (D17) end-to-end DB tests via the COBOL binary.
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
db_reset_fx_hedging

# Create a cost center.
create_out="$(run_cobol "FXH_CREATE|FXH-D17-1|BankA|FX|||admin@test.com")"
assert_match "FXH_CREATE ok" "$create_out" "SUCCESS\|FXH_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM fx_hedging WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "FXH_CREATE|FXH-D17-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "FXH_GET ok" "$(run_cobol "FXH_GET|${id}|||||admin@test.com")" "SUCCESS\|FXH_GET\|${id}\|FXH-D17-1"
assert_match "FXH_LIST ok" "$(run_cobol "FXH_LIST|||50|0||admin@test.com")" "FXH-D17-1"

# Allocate.
assert_match "FXH_CALC ok" "$(run_cobol "FXH_CALC|${id}|||||admin@test.com")" "SUCCESS\|FXH_CALC\|1"
assert_match "posted persisted" "$(db_query "SELECT settled_amount FROM fx_hedging WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "FXH_DELETE ok" "$(run_cobol "FXH_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|FXH_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM fx_hedging WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "FXH_SUMMARY ok" "$(run_cobol "FXH_SUMMARY||||||admin@test.com")" "SUCCESS\|FXH_SUMMARY"
assert_match "FXH_AUDIT ok" "$(run_cobol "FXH_AUDIT|50|0||||admin@test.com")" "SUCCESS\|FXH_AUDIT"
assert_match "FXH_VALIDATE ok" "$(run_cobol "FXH_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|FXH_VALID"
assert_match "non-admin refused" "$(run_cobol "FXH_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0