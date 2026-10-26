#!/usr/bin/env bash
# D7 (compliance) end-to-end DB tests via the COBOL binary.
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
db_reset_kyc_periodic

# Create a review.
create_out="$(run_cobol "KCP_CREATE|KCP-D7-1|cust@test.com|MEDIUM|||admin@test.com")"
assert_match "KCP_CREATE ok" "$create_out" "SUCCESS\|KCP_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM kyc_periodic WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "KCP_CREATE|KCP-D7-1|cust2@test.com|HIGH|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "KCP_GET ok" "$(run_cobol "KCP_GET|${id}|||||admin@test.com")" "SUCCESS\|KCP_GET\|${id}\|KCP-D7-1"
assert_match "KCP_LIST ok" "$(run_cobol "KCP_LIST||cust@test.com|50|0||admin@test.com")" "KCP-D7-1"

# Close.
assert_match "KCP_CLOSE ok" "$(run_cobol "KCP_CLOSE|${id}|Completed||||admin@test.com")" "SUCCESS\|KCP_CLOSE"
assert_match "closed persisted" "$(db_query "SELECT status FROM kyc_periodic WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "KCP_SUMMARY ok" "$(run_cobol "KCP_SUMMARY||||||admin@test.com")" "SUCCESS\|KCP_SUMMARY"
assert_match "KCP_AUDIT ok" "$(run_cobol "KCP_AUDIT|50|0||||admin@test.com")" "SUCCESS\|KCP_AUDIT"
assert_match "KCP_VALIDATE ok" "$(run_cobol "KCP_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|KCP_VALID"
assert_match "non-admin refused" "$(run_cobol "KCP_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0