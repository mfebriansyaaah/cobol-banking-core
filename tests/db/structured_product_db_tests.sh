#!/usr/bin/env bash
# Structured product (Wave6) end-to-end DB tests via the COBOL binary.
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
db_reset_structured_product

# Create a cost center.
create_out="$(run_cobol "STP_CREATE|STP-W6-1|ProductA|AUTOCALL|||admin@test.com")"
assert_match "STP_CREATE ok" "$create_out" "SUCCESS\|STP_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM structured_product WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "STP_CREATE|STP-W6-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "STP_GET ok" "$(run_cobol "STP_GET|${id}|||||admin@test.com")" "SUCCESS\|STP_GET\|${id}\|STP-W6-1"
assert_match "STP_LIST ok" "$(run_cobol "STP_LIST|||50|0||admin@test.com")" "STP-W6-1"

# Allocate.
assert_match "STP_CALC ok" "$(run_cobol "STP_CALC|${id}|||||admin@test.com")" "SUCCESS\|STP_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM structured_product WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "STP_DELETE ok" "$(run_cobol "STP_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|STP_DELETE"
assert_match "matured persisted" "$(db_query "SELECT status FROM structured_product WHERE id=${id};")" "^MATURED$"

# Summary and audit.
assert_match "STP_SUMMARY ok" "$(run_cobol "STP_SUMMARY||||||admin@test.com")" "SUCCESS\|STP_SUMMARY"
assert_match "STP_AUDIT ok" "$(run_cobol "STP_AUDIT|50|0||||admin@test.com")" "SUCCESS\|STP_AUDIT"
assert_match "STP_VALIDATE ok" "$(run_cobol "STP_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|STP_VALID"
assert_match "non-admin refused" "$(run_cobol "STP_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"


# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM structured_product WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM structured_product_audit WHERE structured_product_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "STP_UPDATE|${id}|ProductA|AUTOCALL|||admin@test.com")"
assert_match "STP_UPDATE ok" "$upd_out" "SUCCESS\\|STP_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM structured_product WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM structured_product_audit WHERE structured_product_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "STP_UPDATE|999999|ProductA|AUTOCALL|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "STP_UPDATE|${id}|ProductA|AUTOCALL|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0