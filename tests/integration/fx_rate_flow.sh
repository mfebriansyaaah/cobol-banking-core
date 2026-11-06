#!/usr/bin/env bash
# FX reference flow (PR-091): store -> fresh read -> stale after backdate ->
# unsupported currency refused. No network (COBOL + DB only).
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
A="admin@test.com"
D="$(date +%F)"
db_exec "DELETE FROM fx_rate_snapshots WHERE base='USD' AND quote IN ('IDR','EUR');"

echo "=== FX reference flow ==="
assert_match "missing pair not found" "$(run_cobol "FX_RATE_GET|USD|IDR||||")" "ERROR\|NOT_FOUND"
assert_match "bad codes refused" "$(run_cobol "FX_RATE_GET|US|IDR||||")" "ERROR\|INVALID_INPUT"
assert_match "same pair refused" "$(run_cobol "FX_RATE_STORE|USD|USD|1|frankfurter|${D}|${A}")" "ERROR\|INVALID_INPUT"
assert_match "bad rate refused" "$(run_cobol "FX_RATE_STORE|USD|IDR|0|frankfurter|${D}|${A}")" "ERROR\|INVALID_INPUT"
assert_match "non-admin store refused" "$(run_cobol "FX_RATE_STORE|USD|IDR|16500.50|frankfurter|${D}|sender@test.com")" "ERROR\|FORBIDDEN"
assert_match "store ok" "$(run_cobol "FX_RATE_STORE|USD|IDR|16500.50|frankfurter|${D}|${A}")" "SUCCESS\|FX_STORED"
assert_match "fresh read" "$(run_cobol "FX_RATE_GET|USD|IDR||||")" "SUCCESS\|FX_RATE\|16500\.500000\|FRESH"
db_exec "UPDATE fx_rate_snapshots SET fetched_at=DATE_SUB(NOW(), INTERVAL 25 HOUR) WHERE base='USD' AND quote='IDR';"
assert_match "stale after 25h" "$(run_cobol "FX_RATE_GET|USD|IDR||||")" "SUCCESS\|FX_RATE\|16500\.500000\|STALE"
assert_match "newer snapshot wins" "$(run_cobol "FX_RATE_STORE|USD|IDR|16600.00|frankfurter|${D}|${A}")" "SUCCESS\|FX_STORED"
assert_match "latest served fresh" "$(run_cobol "FX_RATE_GET|USD|IDR||||")" "SUCCESS\|FX_RATE\|16600\.000000\|FRESH"

db_exec "DELETE FROM fx_rate_snapshots WHERE base='USD' AND quote IN ('IDR','EUR');"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
