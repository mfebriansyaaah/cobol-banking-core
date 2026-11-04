#!/usr/bin/env bash
# Product item (Wave15) end-to-end DB tests via the COBOL binary.
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
db_reset_product_item

# Create a cost center.
create_out="$(run_cobol "PRDT_CREATE|PRDT-W15-1|ProductA|DEPOSIT|||admin@test.com")"
assert_match "PRDT_CREATE ok" "$create_out" "SUCCESS\|PRDT_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM product_item WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "PRDT_CREATE|PRDT-W15-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "PRDT_GET ok" "$(run_cobol "PRDT_GET|${id}|||||admin@test.com")" "SUCCESS\|PRDT_GET\|${id}\|PRDT-W15-1"
assert_match "PRDT_LIST ok" "$(run_cobol "PRDT_LIST|||50|0||admin@test.com")" "PRDT-W15-1"

# Allocate.
assert_match "PRDT_CALC ok" "$(run_cobol "PRDT_CALC|${id}|||||admin@test.com")" "SUCCESS\|PRDT_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM product_item WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "PRDT_DELETE ok" "$(run_cobol "PRDT_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|PRDT_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM product_item WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "PRDT_SUMMARY ok" "$(run_cobol "PRDT_SUMMARY||||||admin@test.com")" "SUCCESS\|PRDT_SUMMARY"
assert_match "PRDT_AUDIT ok" "$(run_cobol "PRDT_AUDIT|50|0||||admin@test.com")" "SUCCESS\|PRDT_AUDIT"
assert_match "PRDT_VALIDATE ok" "$(run_cobol "PRDT_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|PRDT_VALID"
assert_match "non-admin refused" "$(run_cobol "PRDT_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"


# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM product_item WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM product_item_audit WHERE product_item_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "PRDT_UPDATE|${id}|ProductA|DEPOSIT|||admin@test.com")"
assert_match "PRDT_UPDATE ok" "$upd_out" "SUCCESS\\|PRDT_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM product_item WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM product_item_audit WHERE product_item_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "PRDT_UPDATE|999999|ProductA|DEPOSIT|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "PRDT_UPDATE|${id}|ProductA|DEPOSIT|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0