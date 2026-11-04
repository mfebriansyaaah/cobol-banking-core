#!/usr/bin/env bash
# Token management (Wave8) end-to-end DB tests via the COBOL binary.
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
db_reset_token_management

# Create a cost center.
create_out="$(run_cobol "TKM_CREATE|TKM-W8-1|UserA|JWT|||admin@test.com")"
assert_match "TKM_CREATE ok" "$create_out" "SUCCESS\|TKM_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM token_management WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "TKM_CREATE|TKM-W8-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "TKM_GET ok" "$(run_cobol "TKM_GET|${id}|||||admin@test.com")" "SUCCESS\|TKM_GET\|${id}\|TKM-W8-1"
assert_match "TKM_LIST ok" "$(run_cobol "TKM_LIST|||50|0||admin@test.com")" "TKM-W8-1"

# Allocate.
assert_match "TKM_CALC ok" "$(run_cobol "TKM_CALC|${id}|||||admin@test.com")" "SUCCESS\|TKM_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM token_management WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "TKM_DELETE ok" "$(run_cobol "TKM_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|TKM_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM token_management WHERE id=${id};")" "^REVOKED$"

# Summary and audit.
assert_match "TKM_SUMMARY ok" "$(run_cobol "TKM_SUMMARY||||||admin@test.com")" "SUCCESS\|TKM_SUMMARY"
assert_match "TKM_AUDIT ok" "$(run_cobol "TKM_AUDIT|50|0||||admin@test.com")" "SUCCESS\|TKM_AUDIT"
assert_match "TKM_VALIDATE ok" "$(run_cobol "TKM_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|TKM_VALID"
assert_match "non-admin refused" "$(run_cobol "TKM_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"


# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM token_management WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM token_management_audit WHERE token_management_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "TKM_UPDATE|${id}|UserA|JWT|||admin@test.com")"
assert_match "TKM_UPDATE ok" "$upd_out" "SUCCESS\\|TKM_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM token_management WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM token_management_audit WHERE token_management_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "TKM_UPDATE|999999|UserA|JWT|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "TKM_UPDATE|${id}|UserA|JWT|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0