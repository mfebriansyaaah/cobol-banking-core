#!/usr/bin/env bash
# Multi currency (Wave9) end-to-end DB tests via the COBOL binary.
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
db_reset_multi_currency

# Create a cost center.
create_out="$(run_cobol "MCC_CREATE|MCC-W9-1|AccountA|MULTI|||admin@test.com")"
assert_match "MCC_CREATE ok" "$create_out" "SUCCESS\|MCC_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM multi_currency WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "MCC_CREATE|MCC-W9-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "MCC_GET ok" "$(run_cobol "MCC_GET|${id}|||||admin@test.com")" "SUCCESS\|MCC_GET\|${id}\|MCC-W9-1"
assert_match "MCC_LIST ok" "$(run_cobol "MCC_LIST|||50|0||admin@test.com")" "MCC-W9-1"

# Allocate.
assert_match "MCC_CALC ok" "$(run_cobol "MCC_CALC|${id}|||||admin@test.com")" "SUCCESS\|MCC_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM multi_currency WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "MCC_DELETE ok" "$(run_cobol "MCC_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|MCC_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM multi_currency WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "MCC_SUMMARY ok" "$(run_cobol "MCC_SUMMARY||||||admin@test.com")" "SUCCESS\|MCC_SUMMARY"
assert_match "MCC_AUDIT ok" "$(run_cobol "MCC_AUDIT|50|0||||admin@test.com")" "SUCCESS\|MCC_AUDIT"
assert_match "MCC_VALIDATE ok" "$(run_cobol "MCC_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|MCC_VALID"
assert_match "non-admin refused" "$(run_cobol "MCC_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"


# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM multi_currency WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM multi_currency_audit WHERE multi_currency_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "MCC_UPDATE|${id}|AccountA|MULTI|||admin@test.com")"
assert_match "MCC_UPDATE ok" "$upd_out" "SUCCESS\\|MCC_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM multi_currency WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM multi_currency_audit WHERE multi_currency_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "MCC_UPDATE|999999|AccountA|MULTI|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "MCC_UPDATE|${id}|AccountA|MULTI|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0