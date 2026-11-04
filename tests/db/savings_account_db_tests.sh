#!/usr/bin/env bash
# Savings account (Wave9) end-to-end DB tests via the COBOL binary.
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
db_reset_savings_account

# Create a cost center.
create_out="$(run_cobol "SAV_CREATE|SAV-W9-1|AccountA|BASIC|||admin@test.com")"
assert_match "SAV_CREATE ok" "$create_out" "SUCCESS\|SAV_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM savings_account WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "SAV_CREATE|SAV-W9-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "SAV_GET ok" "$(run_cobol "SAV_GET|${id}|||||admin@test.com")" "SUCCESS\|SAV_GET\|${id}\|SAV-W9-1"
assert_match "SAV_LIST ok" "$(run_cobol "SAV_LIST|||50|0||admin@test.com")" "SAV-W9-1"

# Allocate.
assert_match "SAV_CALC ok" "$(run_cobol "SAV_CALC|${id}|||||admin@test.com")" "SUCCESS\|SAV_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM savings_account WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "SAV_DELETE ok" "$(run_cobol "SAV_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|SAV_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM savings_account WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "SAV_SUMMARY ok" "$(run_cobol "SAV_SUMMARY||||||admin@test.com")" "SUCCESS\|SAV_SUMMARY"
assert_match "SAV_AUDIT ok" "$(run_cobol "SAV_AUDIT|50|0||||admin@test.com")" "SUCCESS\|SAV_AUDIT"
assert_match "SAV_VALIDATE ok" "$(run_cobol "SAV_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|SAV_VALID"
assert_match "non-admin refused" "$(run_cobol "SAV_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"




# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM savings_account WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM savings_account_audit WHERE savings_account_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "SAV_UPDATE|${id}|AccountA|BASIC|||admin@test.com")"
assert_match "SAV_UPDATE ok" "$upd_out" "SUCCESS\\|SAV_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM savings_account WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM savings_account_audit WHERE savings_account_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "SAV_UPDATE|999999|AccountA|BASIC|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "SAV_UPDATE|${id}|AccountA|BASIC|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0