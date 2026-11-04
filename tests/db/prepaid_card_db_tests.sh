#!/usr/bin/env bash
# Prepaid card (Wave8) end-to-end DB tests via the COBOL binary.
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
db_reset_prepaid_card

# Create a cost center.
create_out="$(run_cobol "PPC_CREATE|PPC-W8-1|CardholderA|RELOADABLE|||admin@test.com")"
assert_match "PPC_CREATE ok" "$create_out" "SUCCESS\|PPC_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM prepaid_card WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "PPC_CREATE|PPC-W8-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "PPC_GET ok" "$(run_cobol "PPC_GET|${id}|||||admin@test.com")" "SUCCESS\|PPC_GET\|${id}\|PPC-W8-1"
assert_match "PPC_LIST ok" "$(run_cobol "PPC_LIST|||50|0||admin@test.com")" "PPC-W8-1"

# Allocate.
assert_match "PPC_CALC ok" "$(run_cobol "PPC_CALC|${id}|||||admin@test.com")" "SUCCESS\|PPC_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM prepaid_card WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "PPC_DELETE ok" "$(run_cobol "PPC_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|PPC_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM prepaid_card WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "PPC_SUMMARY ok" "$(run_cobol "PPC_SUMMARY||||||admin@test.com")" "SUCCESS\|PPC_SUMMARY"
assert_match "PPC_AUDIT ok" "$(run_cobol "PPC_AUDIT|50|0||||admin@test.com")" "SUCCESS\|PPC_AUDIT"
assert_match "PPC_VALIDATE ok" "$(run_cobol "PPC_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|PPC_VALID"
assert_match "non-admin refused" "$(run_cobol "PPC_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"




# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM prepaid_card WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM prepaid_card_audit WHERE prepaid_card_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "PPC_UPDATE|${id}|CardholderA|RELOADABLE|||admin@test.com")"
assert_match "PPC_UPDATE ok" "$upd_out" "SUCCESS\\|PPC_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM prepaid_card WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM prepaid_card_audit WHERE prepaid_card_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "PPC_UPDATE|999999|CardholderA|RELOADABLE|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "PPC_UPDATE|${id}|CardholderA|RELOADABLE|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0