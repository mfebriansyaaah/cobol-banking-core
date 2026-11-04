#!/usr/bin/env bash
# standing_order (Wave1) end-to-end DB tests via the COBOL binary.
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
db_reset_standing_order

# Create a cost center.
create_out="$(run_cobol "STO_CREATE|STO-W1-1|Utility|MONTHLY|||admin@test.com")"
assert_match "STO_CREATE ok" "$create_out" "SUCCESS\|STO_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM standing_order WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "STO_CREATE|STO-W1-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "STO_GET ok" "$(run_cobol "STO_GET|${id}|||||admin@test.com")" "SUCCESS\|STO_GET\|${id}\|STO-W1-1"
assert_match "STO_LIST ok" "$(run_cobol "STO_LIST|||50|0||admin@test.com")" "STO-W1-1"

# Allocate.
assert_match "STO_CALC ok" "$(run_cobol "STO_CALC|${id}|||||admin@test.com")" "SUCCESS\|STO_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT used_amount FROM standing_order WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "STO_DELETE ok" "$(run_cobol "STO_DELETE|${id}|CANCELLED||||admin@test.com")" "SUCCESS\|STO_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM standing_order WHERE id=${id};")" "^CANCELLED$"

# Summary and audit.
assert_match "STO_SUMMARY ok" "$(run_cobol "STO_SUMMARY||||||admin@test.com")" "SUCCESS\|STO_SUMMARY"
assert_match "STO_AUDIT ok" "$(run_cobol "STO_AUDIT|50|0||||admin@test.com")" "SUCCESS\|STO_AUDIT"
assert_match "STO_VALIDATE ok" "$(run_cobol "STO_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|STO_VALID"
assert_match "non-admin refused" "$(run_cobol "STO_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"


# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM standing_order WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM standing_order_audit WHERE standing_order_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "STO_UPDATE|${id}|Utility|MONTHLY|||admin@test.com")"
assert_match "STO_UPDATE ok" "$upd_out" "SUCCESS\\|STO_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM standing_order WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM standing_order_audit WHERE standing_order_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "STO_UPDATE|999999|Utility|MONTHLY|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "STO_UPDATE|${id}|Utility|MONTHLY|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0