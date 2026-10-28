#!/usr/bin/env bash
# Crypto exchange (Wave6) end-to-end DB tests via the COBOL binary.
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
db_reset_crypto_exchange

# Create a cost center.
create_out="$(run_cobol "CRX_CREATE|CRX-W6-1|ExchangeA|SPOT|||admin@test.com")"
assert_match "CRX_CREATE ok" "$create_out" "SUCCESS\|CRX_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM crypto_exchange WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "CRX_CREATE|CRX-W6-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "CRX_GET ok" "$(run_cobol "CRX_GET|${id}|||||admin@test.com")" "SUCCESS\|CRX_GET\|${id}\|CRX-W6-1"
assert_match "CRX_LIST ok" "$(run_cobol "CRX_LIST|||50|0||admin@test.com")" "CRX-W6-1"

# Allocate.
assert_match "CRX_CALC ok" "$(run_cobol "CRX_CALC|${id}|||||admin@test.com")" "SUCCESS\|CRX_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM crypto_exchange WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "CRX_DELETE ok" "$(run_cobol "CRX_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|CRX_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM crypto_exchange WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "CRX_SUMMARY ok" "$(run_cobol "CRX_SUMMARY||||||admin@test.com")" "SUCCESS\|CRX_SUMMARY"
assert_match "CRX_AUDIT ok" "$(run_cobol "CRX_AUDIT|50|0||||admin@test.com")" "SUCCESS\|CRX_AUDIT"
assert_match "CRX_VALIDATE ok" "$(run_cobol "CRX_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|CRX_VALID"
assert_match "non-admin refused" "$(run_cobol "CRX_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0