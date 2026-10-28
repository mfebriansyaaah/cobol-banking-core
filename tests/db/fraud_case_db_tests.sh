#!/usr/bin/env bash
# Fraud case (D13) end-to-end DB tests via the COBOL binary.
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
db_reset_fraud_case

# Create a fraud case.
create_out="$(run_cobol "FRC_CREATE|FRC-D13-1|ACC-12345|UNAUTHORIZED_TX|||admin@test.com")"
assert_match "FRC_CREATE ok" "$create_out" "SUCCESS\|FRC_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM fraud_case WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "FRC_CREATE|FRC-D13-1|OTHER|SUSPICIOUS|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "FRC_GET ok" "$(run_cobol "FRC_GET|${id}|||||admin@test.com")" "SUCCESS\|FRC_GET\|${id}\|FRC-D13-1"
assert_match "FRC_LIST ok" "$(run_cobol "FRC_LIST||UNAUTHORIZED_TX|50|0||admin@test.com")" "FRC-D13-1"

# Screen.
assert_match "FRC_SCREEN ok" "$(run_cobol "FRC_SCREEN|${id}|||||admin@test.com")" "SUCCESS\|FRC_SCREEN\|1"
assert_match "alert_count persisted" "$(db_query "SELECT alert_count FROM fraud_case WHERE id=${id};")" "^1$"

# Close.
assert_match "FRC_CLOSE ok" "$(run_cobol "FRC_CLOSE|${id}|Confirmed fraud||||admin@test.com")" "SUCCESS\|FRC_CLOSE"
assert_match "closed persisted" "$(db_query "SELECT status FROM fraud_case WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "FRC_SUMMARY ok" "$(run_cobol "FRC_SUMMARY||||||admin@test.com")" "SUCCESS\|FRC_SUMMARY"
assert_match "FRC_AUDIT ok" "$(run_cobol "FRC_AUDIT|50|0||||admin@test.com")" "SUCCESS\|FRC_AUDIT"
assert_match "FRC_VALIDATE ok" "$(run_cobol "FRC_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|FRC_VALID"
assert_match "non-admin refused" "$(run_cobol "FRC_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0