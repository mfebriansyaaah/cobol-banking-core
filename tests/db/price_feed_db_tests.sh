#!/usr/bin/env bash
# Price feed (Wave14) end-to-end DB tests via the COBOL binary.
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
db_reset_price_feed

# Create a cost center.
create_out="$(run_cobol "PF_CREATE|PF-W14-1|PfA|BLOOMBERG|||admin@test.com")"
assert_match "PF_CREATE ok" "$create_out" "SUCCESS\|PF_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM price_feed WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "PF_CREATE|PF-W14-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "PF_GET ok" "$(run_cobol "PF_GET|${id}|||||admin@test.com")" "SUCCESS\|PF_GET\|${id}\|PF-W14-1"
assert_match "PF_LIST ok" "$(run_cobol "PF_LIST|||50|0||admin@test.com")" "PF-W14-1"

# Allocate.
assert_match "PF_CALC ok" "$(run_cobol "PF_CALC|${id}|||||admin@test.com")" "SUCCESS\|PF_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM price_feed WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "PF_DELETE ok" "$(run_cobol "PF_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|PF_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM price_feed WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "PF_SUMMARY ok" "$(run_cobol "PF_SUMMARY||||||admin@test.com")" "SUCCESS\|PF_SUMMARY"
assert_match "PF_AUDIT ok" "$(run_cobol "PF_AUDIT|50|0||||admin@test.com")" "SUCCESS\|PF_AUDIT"
assert_match "PF_VALIDATE ok" "$(run_cobol "PF_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|PF_VALID"
assert_match "non-admin refused" "$(run_cobol "PF_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"


# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM price_feed WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM price_feed_audit WHERE price_feed_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "PF_UPDATE|${id}|PfA|BLOOMBERG|||admin@test.com")"
assert_match "PF_UPDATE ok" "$upd_out" "SUCCESS\\|PF_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM price_feed WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM price_feed_audit WHERE price_feed_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "PF_UPDATE|999999|PfA|BLOOMBERG|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "PF_UPDATE|${id}|PfA|BLOOMBERG|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0