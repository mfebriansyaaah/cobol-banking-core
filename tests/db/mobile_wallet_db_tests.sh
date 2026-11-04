#!/usr/bin/env bash
# Mobile wallet (Wave5) end-to-end DB tests via the COBOL binary.
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
db_reset_mobile_wallet

# Create a cost center.
create_out="$(run_cobol "MBW_CREATE|MBW-W5-1|WalletA|PREPAID|||admin@test.com")"
assert_match "MBW_CREATE ok" "$create_out" "SUCCESS\|MBW_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM mobile_wallet WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "MBW_CREATE|MBW-W5-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "MBW_GET ok" "$(run_cobol "MBW_GET|${id}|||||admin@test.com")" "SUCCESS\|MBW_GET\|${id}\|MBW-W5-1"
assert_match "MBW_LIST ok" "$(run_cobol "MBW_LIST|||50|0||admin@test.com")" "MBW-W5-1"

# Allocate.
assert_match "MBW_CALC ok" "$(run_cobol "MBW_CALC|${id}|||||admin@test.com")" "SUCCESS\|MBW_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_today FROM mobile_wallet WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "MBW_DELETE ok" "$(run_cobol "MBW_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|MBW_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM mobile_wallet WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "MBW_SUMMARY ok" "$(run_cobol "MBW_SUMMARY||||||admin@test.com")" "SUCCESS\|MBW_SUMMARY"
assert_match "MBW_AUDIT ok" "$(run_cobol "MBW_AUDIT|50|0||||admin@test.com")" "SUCCESS\|MBW_AUDIT"
assert_match "MBW_VALIDATE ok" "$(run_cobol "MBW_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|MBW_VALID"
assert_match "non-admin refused" "$(run_cobol "MBW_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"




# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM mobile_wallet WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM mobile_wallet_audit WHERE mobile_wallet_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "MBW_UPDATE|${id}|WalletA|PREPAID|||admin@test.com")"
assert_match "MBW_UPDATE ok" "$upd_out" "SUCCESS\\|MBW_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM mobile_wallet WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM mobile_wallet_audit WHERE mobile_wallet_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "MBW_UPDATE|999999|WalletA|PREPAID|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "MBW_UPDATE|${id}|WalletA|PREPAID|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0