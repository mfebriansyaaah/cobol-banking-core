#!/usr/bin/env bash
# Notice deposit (Wave9) end-to-end DB tests via the COBOL binary.
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
db_reset_notice_deposit

# Create a cost center.
create_out="$(run_cobol "NDP_CREATE|NDP-W9-1|DepositorA|NOTICE|||admin@test.com")"
assert_match "NDP_CREATE ok" "$create_out" "SUCCESS\|NDP_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM notice_deposit WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "NDP_CREATE|NDP-W9-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "NDP_GET ok" "$(run_cobol "NDP_GET|${id}|||||admin@test.com")" "SUCCESS\|NDP_GET\|${id}\|NDP-W9-1"
assert_match "NDP_LIST ok" "$(run_cobol "NDP_LIST|||50|0||admin@test.com")" "NDP-W9-1"

# Allocate.
assert_match "NDP_CALC ok" "$(run_cobol "NDP_CALC|${id}|||||admin@test.com")" "SUCCESS\|NDP_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM notice_deposit WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "NDP_DELETE ok" "$(run_cobol "NDP_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|NDP_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM notice_deposit WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "NDP_SUMMARY ok" "$(run_cobol "NDP_SUMMARY||||||admin@test.com")" "SUCCESS\|NDP_SUMMARY"
assert_match "NDP_AUDIT ok" "$(run_cobol "NDP_AUDIT|50|0||||admin@test.com")" "SUCCESS\|NDP_AUDIT"
assert_match "NDP_VALIDATE ok" "$(run_cobol "NDP_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|NDP_VALID"
assert_match "non-admin refused" "$(run_cobol "NDP_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"




# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM notice_deposit WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM notice_deposit_audit WHERE notice_deposit_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "NDP_UPDATE|${id}|DepositorA|NOTICE|||admin@test.com")"
assert_match "NDP_UPDATE ok" "$upd_out" "SUCCESS\\|NDP_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM notice_deposit WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM notice_deposit_audit WHERE notice_deposit_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "NDP_UPDATE|999999|DepositorA|NOTICE|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "NDP_UPDATE|${id}|DepositorA|NOTICE|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0