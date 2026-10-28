#!/usr/bin/env bash
# Data lineage (D22) end-to-end DB tests via the COBOL binary.
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
db_reset_data_lineage

# Create a cost center.
create_out="$(run_cobol "DLN_CREATE|DLN-D22-1|SourceA|DLN|||admin@test.com")"
assert_match "DLN_CREATE ok" "$create_out" "SUCCESS\|DLN_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM data_lineage WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "DLN_CREATE|DLN-D22-1|Other|DLNEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "DLN_GET ok" "$(run_cobol "DLN_GET|${id}|||||admin@test.com")" "SUCCESS\|DLN_GET\|${id}\|DLN-D22-1"
assert_match "DLN_LIST ok" "$(run_cobol "DLN_LIST|||50|0||admin@test.com")" "DLN-D22-1"

# Allocate.
assert_match "DLN_CALC ok" "$(run_cobol "DLN_CALC|${id}|||||admin@test.com")" "SUCCESS\|DLN_CALC\|1"
assert_match "posted persisted" "$(db_query "SELECT tracked_count FROM data_lineage WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "DLN_DELETE ok" "$(run_cobol "DLN_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|DLN_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM data_lineage WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "DLN_SUMMARY ok" "$(run_cobol "DLN_SUMMARY||||||admin@test.com")" "SUCCESS\|DLN_SUMMARY"
assert_match "DLN_AUDIT ok" "$(run_cobol "DLN_AUDIT|50|0||||admin@test.com")" "SUCCESS\|DLN_AUDIT"
assert_match "DLN_VALIDATE ok" "$(run_cobol "DLN_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|DLN_VALID"
assert_match "non-admin refused" "$(run_cobol "DLN_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0