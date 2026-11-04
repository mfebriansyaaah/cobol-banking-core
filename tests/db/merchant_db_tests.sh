#!/usr/bin/env bash
# Merchant (Wave3) end-to-end DB tests via the COBOL binary.
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
db_reset_merchant

# Create a cost center.
create_out="$(run_cobol "MRT_CREATE|MRT-W3-1|MerchantA|ECOMMERCE|||admin@test.com")"
assert_match "MRT_CREATE ok" "$create_out" "SUCCESS\|MRT_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM merchant WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "MRT_CREATE|MRT-W3-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "MRT_GET ok" "$(run_cobol "MRT_GET|${id}|||||admin@test.com")" "SUCCESS\|MRT_GET\|${id}\|MRT-W3-1"
assert_match "MRT_LIST ok" "$(run_cobol "MRT_LIST|||50|0||admin@test.com")" "MRT-W3-1"

# Allocate.
assert_match "MRT_CALC ok" "$(run_cobol "MRT_CALC|${id}|||||admin@test.com")" "SUCCESS\|MRT_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT settled_volume FROM merchant WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "MRT_DELETE ok" "$(run_cobol "MRT_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|MRT_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM merchant WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "MRT_SUMMARY ok" "$(run_cobol "MRT_SUMMARY||||||admin@test.com")" "SUCCESS\|MRT_SUMMARY"
assert_match "MRT_AUDIT ok" "$(run_cobol "MRT_AUDIT|50|0||||admin@test.com")" "SUCCESS\|MRT_AUDIT"
assert_match "MRT_VALIDATE ok" "$(run_cobol "MRT_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|MRT_VALID"
assert_match "non-admin refused" "$(run_cobol "MRT_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"


# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM merchant WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM merchant_audit WHERE merchant_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "MRT_UPDATE|${id}|MerchantA|ECOMMERCE|||admin@test.com")"
assert_match "MRT_UPDATE ok" "$upd_out" "SUCCESS\\|MRT_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM merchant WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM merchant_audit WHERE merchant_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "MRT_UPDATE|999999|MerchantA|ECOMMERCE|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "MRT_UPDATE|${id}|MerchantA|ECOMMERCE|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0