#!/usr/bin/env bash
# D6 (treasury) end-to-end DB tests via the COBOL binary.
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
db_reset_treasury_liquidity

# Create a liquidity entry.
create_out="$(run_cobol "TRL_CREATE|TRL-D6-1|100000.00|USD|||admin@test.com")"
assert_match "TRL_CREATE ok" "$create_out" "SUCCESS\|TRL_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "id stored" "$(db_query "SELECT id FROM treasury_liquidity WHERE id=${id};")" "^${id}$"
assert_match "status open" "$(db_query "SELECT status FROM treasury_liquidity WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "TRL_CREATE|TRL-D6-1|50000.00|USD|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "TRL_GET ok" "$(run_cobol "TRL_GET|${id}|||||admin@test.com")" "SUCCESS\|TRL_GET\|${id}\|TRL-D6-1"
assert_match "TRL_LIST ok" "$(run_cobol "TRL_LIST||USD|50|0||admin@test.com")" "TRL-D6-1"
assert_match "TRL_LIST filters status" "$(run_cobol "TRL_LIST|REALIZED||50|0||admin@test.com")" "SUCCESS\|TRL_LIST\|0"

# Post projected amount.
assert_match "TRL_POST ok" "$(run_cobol "TRL_POST|${id}|60000.00||||admin@test.com")" "SUCCESS\|TRL_POST\|60000.00"
assert_match "projected persisted" "$(db_query "SELECT projected_amount FROM treasury_liquidity WHERE id=${id};")" "^60000.0000$"

# Settle realized.
assert_match "TRL_SETTLE ok" "$(run_cobol "TRL_SETTLE|${id}|50000.00||||admin@test.com")" "SUCCESS\|TRL_SETTLE\|50000.00"
assert_match "realized persisted" "$(db_query "SELECT realized_amount FROM treasury_liquidity WHERE id=${id};")" "^50000.0000$"

# Over-post rejected.
assert_match "over-post rejected" "$(run_cobol "TRL_POST|${id}|999999.00||||admin@test.com")" "ERROR\|INVALID_AMOUNT"

# A second entry stays open and can be closed.
create2="$(run_cobol "TRL_CREATE|TRL-D6-2|20000.00|EUR|||admin@test.com")"
id2="$(printf '%s' "$create2" | awk -F'|' '{print $3}')"
assert_match "TRL_CLOSE ok" "$(run_cobol "TRL_CLOSE|${id2}|Not needed||||admin@test.com")" "SUCCESS\|TRL_CLOSE"
assert_match "closed persisted" "$(db_query "SELECT status FROM treasury_liquidity WHERE id=${id2};")" "^CLOSED$"

# Summary and audit.
assert_match "TRL_SUMMARY ok" "$(run_cobol "TRL_SUMMARY||||||admin@test.com")" "SUCCESS\|TRL_SUMMARY"
assert_match "TRL_AUDIT ok" "$(run_cobol "TRL_AUDIT|50|0||||admin@test.com")" "SUCCESS\|TRL_AUDIT"
assert_match "TRL_VALIDATE ok" "$(run_cobol "TRL_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|TRL_VALID"
assert_match "non-admin refused" "$(run_cobol "TRL_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0