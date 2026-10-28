#!/usr/bin/env bash
# Crypto wallet (Wave6) end-to-end DB tests via the COBOL binary.
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
db_reset_crypto_wallet

# Create a cost center.
create_out="$(run_cobol "CRW_CREATE|CRW-W6-1|WalletA|BTC|||admin@test.com")"
assert_match "CRW_CREATE ok" "$create_out" "SUCCESS\|CRW_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM crypto_wallet WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "CRW_CREATE|CRW-W6-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "CRW_GET ok" "$(run_cobol "CRW_GET|${id}|||||admin@test.com")" "SUCCESS\|CRW_GET\|${id}\|CRW-W6-1"
assert_match "CRW_LIST ok" "$(run_cobol "CRW_LIST|||50|0||admin@test.com")" "CRW-W6-1"

# Allocate.
assert_match "CRW_CALC ok" "$(run_cobol "CRW_CALC|${id}|||||admin@test.com")" "SUCCESS\|CRW_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM crypto_wallet WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "CRW_DELETE ok" "$(run_cobol "CRW_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|CRW_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM crypto_wallet WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "CRW_SUMMARY ok" "$(run_cobol "CRW_SUMMARY||||||admin@test.com")" "SUCCESS\|CRW_SUMMARY"
assert_match "CRW_AUDIT ok" "$(run_cobol "CRW_AUDIT|50|0||||admin@test.com")" "SUCCESS\|CRW_AUDIT"
assert_match "CRW_VALIDATE ok" "$(run_cobol "CRW_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|CRW_VALID"
assert_match "non-admin refused" "$(run_cobol "CRW_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0