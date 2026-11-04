#!/usr/bin/env bash
# Open banking (Wave6) end-to-end DB tests via the COBOL binary.
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
db_reset_open_banking

# Create a cost center.
create_out="$(run_cobol "OPN_CREATE|OPN-W6-1|ProviderA|PSD2|||admin@test.com")"
assert_match "OPN_CREATE ok" "$create_out" "SUCCESS\|OPN_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM open_banking WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "OPN_CREATE|OPN-W6-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "OPN_GET ok" "$(run_cobol "OPN_GET|${id}|||||admin@test.com")" "SUCCESS\|OPN_GET\|${id}\|OPN-W6-1"
assert_match "OPN_LIST ok" "$(run_cobol "OPN_LIST|||50|0||admin@test.com")" "OPN-W6-1"

# Allocate.
assert_match "OPN_CALC ok" "$(run_cobol "OPN_CALC|${id}|||||admin@test.com")" "SUCCESS\|OPN_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM open_banking WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "OPN_DELETE ok" "$(run_cobol "OPN_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|OPN_DELETE"
assert_match "inactive persisted" "$(db_query "SELECT status FROM open_banking WHERE id=${id};")" "^INACTIVE$"

# Summary and audit.
assert_match "OPN_SUMMARY ok" "$(run_cobol "OPN_SUMMARY||||||admin@test.com")" "SUCCESS\|OPN_SUMMARY"
assert_match "OPN_AUDIT ok" "$(run_cobol "OPN_AUDIT|50|0||||admin@test.com")" "SUCCESS\|OPN_AUDIT"
assert_match "OPN_VALIDATE ok" "$(run_cobol "OPN_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|OPN_VALID"
assert_match "non-admin refused" "$(run_cobol "OPN_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"


# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM open_banking WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM open_banking_audit WHERE open_banking_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "OPN_UPDATE|${id}|ProviderA|PSD2|||admin@test.com")"
assert_match "OPN_UPDATE ok" "$upd_out" "SUCCESS\\|OPN_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM open_banking WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM open_banking_audit WHERE open_banking_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "OPN_UPDATE|999999|ProviderA|PSD2|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "OPN_UPDATE|${id}|ProviderA|PSD2|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0