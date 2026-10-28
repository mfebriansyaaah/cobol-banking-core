#!/usr/bin/env bash
# D9 (IT Ops) end-to-end DB tests via the COBOL binary.
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
db_reset_backup_drill

# Create a drill.
create_out="$(run_cobol "BDR_CREATE|BDR-D9-1|customer_tbl|FULL|||admin@test.com")"
assert_match "BDR_CREATE ok" "$create_out" "SUCCESS\|BDR_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM backup_drill WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "BDR_CREATE|BDR-D9-1|other_tbl|FULL|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "BDR_GET ok" "$(run_cobol "BDR_GET|${id}|||||admin@test.com")" "SUCCESS\|BDR_GET\|${id}\|BDR-D9-1"
assert_match "BDR_LIST ok" "$(run_cobol "BDR_LIST||FULL|50|0||admin@test.com")" "BDR-D9-1"

# Run.
assert_match "BDR_RUN ok" "$(run_cobol "BDR_RUN|${id}|||||admin@test.com")" "SUCCESS\|BDR_RUN\|1"
assert_match "run_count persisted" "$(db_query "SELECT run_count FROM backup_drill WHERE id=${id};")" "^1$"

# Close.
assert_match "BDR_CLOSE ok" "$(run_cobol "BDR_CLOSE|${id}|Completed||||admin@test.com")" "SUCCESS\|BDR_CLOSE"
assert_match "closed persisted" "$(db_query "SELECT status FROM backup_drill WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "BDR_SUMMARY ok" "$(run_cobol "BDR_SUMMARY||||||admin@test.com")" "SUCCESS\|BDR_SUMMARY"
assert_match "BDR_AUDIT ok" "$(run_cobol "BDR_AUDIT|50|0||||admin@test.com")" "SUCCESS\|BDR_AUDIT"
assert_match "BDR_VALIDATE ok" "$(run_cobol "BDR_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|BDR_VALID"
assert_match "non-admin refused" "$(run_cobol "BDR_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0