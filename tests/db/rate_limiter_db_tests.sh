#!/usr/bin/env bash
# Rate limiter (Wave11) end-to-end DB tests via the COBOL binary.
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
db_reset_rate_limiter

# Create a cost center.
create_out="$(run_cobol "RTL_CREATE|RTL-W11-1|TargetA|TOKEN_BUCKET|||admin@test.com")"
assert_match "RTL_CREATE ok" "$create_out" "SUCCESS\|RTL_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM rate_limiter WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "RTL_CREATE|RTL-W11-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "RTL_GET ok" "$(run_cobol "RTL_GET|${id}|||||admin@test.com")" "SUCCESS\|RTL_GET\|${id}\|RTL-W11-1"
assert_match "RTL_LIST ok" "$(run_cobol "RTL_LIST|||50|0||admin@test.com")" "RTL-W11-1"

# Allocate.
assert_match "RTL_CALC ok" "$(run_cobol "RTL_CALC|${id}|||||admin@test.com")" "SUCCESS\|RTL_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM rate_limiter WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "RTL_DELETE ok" "$(run_cobol "RTL_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|RTL_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM rate_limiter WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "RTL_SUMMARY ok" "$(run_cobol "RTL_SUMMARY||||||admin@test.com")" "SUCCESS\|RTL_SUMMARY"
assert_match "RTL_AUDIT ok" "$(run_cobol "RTL_AUDIT|50|0||||admin@test.com")" "SUCCESS\|RTL_AUDIT"
assert_match "RTL_VALIDATE ok" "$(run_cobol "RTL_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|RTL_VALID"
assert_match "non-admin refused" "$(run_cobol "RTL_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"


# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM rate_limiter WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM rate_limiter_audit WHERE rate_limiter_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "RTL_UPDATE|${id}|TargetA|TOKEN_BUCKET|||admin@test.com")"
assert_match "RTL_UPDATE ok" "$upd_out" "SUCCESS\\|RTL_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM rate_limiter WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM rate_limiter_audit WHERE rate_limiter_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "RTL_UPDATE|999999|TargetA|TOKEN_BUCKET|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "RTL_UPDATE|${id}|TargetA|TOKEN_BUCKET|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0