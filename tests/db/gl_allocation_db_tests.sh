#!/usr/bin/env bash
# D8 (finance) end-to-end DB tests via the COBOL binary.
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
db_reset_gl_allocation

# Create an allocation.
create_out="$(run_cobol "GLA_CREATE|GLA-D8-1|CostCenter42|4000|||admin@test.com")"
assert_match "GLA_CREATE ok" "$create_out" "SUCCESS\|GLA_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM gl_allocation WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "GLA_CREATE|GLA-D8-1|Other|5000|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "GLA_GET ok" "$(run_cobol "GLA_GET|${id}|||||admin@test.com")" "SUCCESS\|GLA_GET\|${id}\|GLA-D8-1"
assert_match "GLA_LIST ok" "$(run_cobol "GLA_LIST||4000|50|0||admin@test.com")" "GLA-D8-1"

# Allocate.
assert_match "GLA_ALLO ok" "$(run_cobol "GLA_ALLO|${id}|||||admin@test.com")" "SUCCESS\|GLA_ALLO\|1"
assert_match "allocated persisted" "$(db_query "SELECT allocated_amount FROM gl_allocation WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "GLA_CLOSE ok" "$(run_cobol "GLA_CLOSE|${id}|Completed||||admin@test.com")" "SUCCESS\|GLA_CLOSE"
assert_match "closed persisted" "$(db_query "SELECT status FROM gl_allocation WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "GLA_SUMMARY ok" "$(run_cobol "GLA_SUMMARY||||||admin@test.com")" "SUCCESS\|GLA_SUMMARY"
assert_match "GLA_AUDIT ok" "$(run_cobol "GLA_AUDIT|50|0||||admin@test.com")" "SUCCESS\|GLA_AUDIT"
assert_match "GLA_VALIDATE ok" "$(run_cobol "GLA_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|GLA_VALID"
assert_match "non-admin refused" "$(run_cobol "GLA_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0