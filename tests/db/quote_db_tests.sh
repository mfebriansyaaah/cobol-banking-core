#!/usr/bin/env bash
# Quote (Wave14) end-to-end DB tests via the COBOL binary.
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
db_reset_quote

# Create a cost center.
create_out="$(run_cobol "QTE_CREATE|QTE-W14-1|QuoteA|BID_ASK|||admin@test.com")"
assert_match "QTE_CREATE ok" "$create_out" "SUCCESS\|QTE_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM quote WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "QTE_CREATE|QTE-W14-1|Other|CAPEX|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "QTE_GET ok" "$(run_cobol "QTE_GET|${id}|||||admin@test.com")" "SUCCESS\|QTE_GET\|${id}\|QTE-W14-1"
assert_match "QTE_LIST ok" "$(run_cobol "QTE_LIST|||50|0||admin@test.com")" "QTE-W14-1"

# Allocate.
assert_match "QTE_CALC ok" "$(run_cobol "QTE_CALC|${id}|||||admin@test.com")" "SUCCESS\|QTE_CALC\|1"
assert_match "used credit persisted" "$(db_query "SELECT spent_amount FROM quote WHERE id=${id};")" "^1.0000$"

# Close.
assert_match "QTE_DELETE ok" "$(run_cobol "QTE_DELETE|${id}|Closed||||admin@test.com")" "SUCCESS\|QTE_DELETE"
assert_match "closed persisted" "$(db_query "SELECT status FROM quote WHERE id=${id};")" "^CLOSED$"

# Summary and audit.
assert_match "QTE_SUMMARY ok" "$(run_cobol "QTE_SUMMARY||||||admin@test.com")" "SUCCESS\|QTE_SUMMARY"
assert_match "QTE_AUDIT ok" "$(run_cobol "QTE_AUDIT|50|0||||admin@test.com")" "SUCCESS\|QTE_AUDIT"
assert_match "QTE_VALIDATE ok" "$(run_cobol "QTE_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|QTE_VALID"
assert_match "non-admin refused" "$(run_cobol "QTE_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"


# UPDATE (optimistic locking: version bump + audit).
ver_before="$(db_query "SELECT version FROM quote WHERE id=${id};")"
aud_before="$(db_query "SELECT COUNT(*) FROM quote_audit WHERE quote_id=${id} AND action='UPDATE';")"
upd_out="$(run_cobol "QTE_UPDATE|${id}|QuoteA|BID_ASK|||admin@test.com")"
assert_match "QTE_UPDATE ok" "$upd_out" "SUCCESS\\|QTE_UPDATE"
assert_match "version bumped" "$(db_query "SELECT version FROM quote WHERE id=${id};")" "^$((ver_before + 1))$"
assert_match "update audited" "$(db_query "SELECT COUNT(*) FROM quote_audit WHERE quote_id=${id} AND action='UPDATE';")" "^$((aud_before + 1))$"
assert_match "update missing id" "$(run_cobol "QTE_UPDATE|999999|QuoteA|BID_ASK|||admin@test.com")" "ERROR\\|NOT_FOUND"
assert_match "non-admin update refused" "$(run_cobol "QTE_UPDATE|${id}|QuoteA|BID_ASK|||sender@test.com")" "ERROR\\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0