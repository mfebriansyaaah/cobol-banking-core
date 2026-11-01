#!/usr/bin/env bash
# D5 (payments) end-to-end DB tests via the COBOL binary.
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
db_reset_payment_clearing

# Create a clearing entry.
create_out="$(run_cobol "PMC_CREATE|CLR-D5-1|100.00|USD|||admin@test.com")"
assert_match "PMC_CREATE ok" "$create_out" "SUCCESS\|PMC_CREATE\|[0-9]+"
id="$(printf '%s' "$create_out" | awk -F'|' '{print $3}')"
assert_match "id stored" "$(db_query "SELECT id FROM payment_clearing WHERE id=${id};")" "^${id}$"
assert_match "status open" "$(db_query "SELECT status FROM payment_clearing WHERE id=${id};")" "^OPEN$"

# Duplicate ref rejected.
assert_match "duplicate ref" "$(run_cobol "PMC_CREATE|CLR-D5-1|50.00|USD|||admin@test.com")" "ERROR\|DUPLICATE"

# Read paths.
assert_match "PMC_GET ok" "$(run_cobol "PMC_GET|${id}|||||admin@test.com")" "SUCCESS\|PMC_GET\|${id}\|CLR-D5-1"
assert_match "PMC_LIST ok" "$(run_cobol "PMC_LIST||USD|50|0||admin@test.com")" "CLR-D5-1"
assert_match "PMC_LIST filters status" "$(run_cobol "PMC_LIST|SETTLED||50|0||admin@test.com")" "SUCCESS\|PMC_LIST\|0"

# Post partial amount.
assert_match "PMC_POST ok" "$(run_cobol "PMC_POST|${id}|40.00||||admin@test.com")" "SUCCESS\|PMC_POST\|40.00"
assert_match "posted persisted" "$(db_query "SELECT posted_amount FROM payment_clearing WHERE id=${id};")" "^40.0000$"
assert_match "status posted" "$(db_query "SELECT status FROM payment_clearing WHERE id=${id};")" "^POSTED$"

# Settle remaining posted amount.
assert_match "PMC_SETTLE ok" "$(run_cobol "PMC_SETTLE|${id}|40.00||||admin@test.com")" "SUCCESS\|PMC_SETTLE\|40.00"
assert_match "settled persisted" "$(db_query "SELECT settled_amount FROM payment_clearing WHERE id=${id};")" "^40.0000$"

# A fully settled entry is terminal.
assert_match "settled status" "$(db_query "SELECT status FROM payment_clearing WHERE id=${id};")" "^SETTLED$"
assert_match "duplicate settle rejected" "$(run_cobol "PMC_SETTLE|${id}|1.00||||admin@test.com")" "ERROR\|INVALID_STATUS"

# Over-post rejected.
assert_match "over-post rejected" "$(run_cobol "PMC_POST|${id}|999.00||||admin@test.com")" "ERROR\|INVALID_STATUS"

# Cancel requires open/posted without posted? cancel on settled rejected.
assert_match "cancel settled rejected" "$(run_cobol "PMC_CANCEL|${id}|||||admin@test.com")" "ERROR\|INVALID_STATUS"

# A second entry stays open and can be cancelled with a reason.
create2="$(run_cobol "PMC_CREATE|CLR-D5-2|50.00|EUR|||admin@test.com")"
id2="$(printf '%s' "$create2" | awk -F'|' '{print $3}')"
assert_match "PMC_CANCEL ok" "$(run_cobol "PMC_CANCEL|${id2}|duplicate request||||admin@test.com")" "SUCCESS\|PMC_CANCEL"
assert_match "cancelled persisted" "$(db_query "SELECT CONCAT(status, '|', COALESCE(cancellation_reason, '')) FROM payment_clearing WHERE id=${id2};")" "^CANCELLED\|duplicate request$"

# An entry with posted funds is not cancellable until it is settled.
create3="$(run_cobol "PMC_CREATE|CLR-D5-3|20.00|USD|||admin@test.com")"
id3="$(printf '%s' "$create3" | awk -F'|' '{print $3}')"
assert_match "post before cancel" "$(run_cobol "PMC_POST|${id3}|5.00||||admin@test.com")" "SUCCESS\|PMC_POST\|5.00"
assert_match "cancel posted rejected" "$(run_cobol "PMC_CANCEL|${id3}|too late||||admin@test.com")" "ERROR\|INVALID_STATUS"

# Two concurrent posts must serialize on the clearing row: one wins, one is
# rejected by the locked re-check, and the total never exceeds the amount.
conc_create="$(run_cobol "PMC_CREATE|CLR-D5-CONC|100.00|USD|||admin@test.com")"
conc_id="$(printf '%s' "$conc_create" | awk -F'|' '{print $3}')"
conc_dir="$(mktemp -d "${TMPDIR:-/tmp}/pmc-conc.XXXXXX")"
( COBOL_TEST_SERVE=0; run_cobol "PMC_POST|${conc_id}|60.00||||admin@test.com" ) >"$conc_dir/a" &
conc_a=$!
( COBOL_TEST_SERVE=0; run_cobol "PMC_POST|${conc_id}|60.00||||admin@test.com" ) >"$conc_dir/b" &
conc_b=$!
wait "$conc_a" "$conc_b" || true
assert_match "one concurrent post wins" "$( { cat "$conc_dir/a"; echo; cat "$conc_dir/b"; } | grep -c '^SUCCESS')" "^1$"
assert_match "concurrent post amount once" "$(db_query "SELECT posted_amount FROM payment_clearing WHERE id=${conc_id};")" "^60.0000$"
rm -rf "$conc_dir"

# Summary and audit.
assert_match "PMC_SUMMARY ok" "$(run_cobol "PMC_SUMMARY||||||admin@test.com")" "SUCCESS\|PMC_SUMMARY"
assert_match "PMC_AUDIT ok" "$(run_cobol "PMC_AUDIT|50|0||||admin@test.com")" "SUCCESS\|PMC_AUDIT"
assert_match "PMC_VALIDATE ok" "$(run_cobol "PMC_VALIDATE|100.00|USD||||admin@test.com")" "SUCCESS\|PMC_VALID"
assert_match "non-admin refused" "$(run_cobol "PMC_GET|${id}|||||sender@test.com")" "ERROR\|FORBIDDEN"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0