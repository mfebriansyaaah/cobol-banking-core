#!/usr/bin/env bash
# Thrift (Wave20) end-to-end DB tests via the COBOL binary.
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
db_reset_thrift

# Create a cost center.
create_out="$(run_cobol "THR_CREATE|THR-W20-1|ThriftA|SAVINGS_LOAN|||admin@test.com")"
assert_match "THR_CREATE ok" "$create_out" "SUCCESS\|THR_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM thrift WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "THR_CREATE|THR-W20-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "THR_GET ok" "$(run_cobol "THR_GET|${id}|||||admin@test.com")" "SUCCESS\|THR_GET\|${id}\|THR-W20-1"
assert_match "THR_LIST ok" "$(run_cobol "THR_LIST|||50|0||admin@test.com")" "THR-W20-1"

# Allocate.
assert_match "THR_CALC ok" "$(run_cobol "THR_CALC|${id}|||||admin@test.com")" "SUCCESS\|THR_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM thrift WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "THR_DELETE ok" "$(run_cobol "THR_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|THR_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM thrift WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "THR_SUMMARY ok" "$(run_cobol "THR_SUMMARY||||||admin@test.com")" "SUCCESS\|THR_SUMMARY"
assert_match "THR_AUDIT ok" "$(run_cobol "THR_AUDIT|50|0||||admin@test.com")" "SUCCESS\|THR_AUDIT"
assert_match "THR_VALIDATE ok" "$(run_cobol "THR_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|THR_VALID"
assert_match "non-admin refused" "$(run_cobol "THR_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"


# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM thrift WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM thrift_audit WHERE thrift_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "THR_UPDATE|${id}|ThriftA|SAVINGS_LOAN|||admin@test.com")"
assert_match "THR_UPDATE ok" "$upd_out" "SUCCESS\\|THR_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM thrift WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM thrift_audit WHERE thrift_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "THR_UPDATE|999999|ThriftA|SAVINGS_LOAN|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "THR_UPDATE|${id}|ThriftA|SAVINGS_LOAN|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0