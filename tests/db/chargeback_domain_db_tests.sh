#!/usr/bin/env bash
# Chargeback domain lifecycle (PR-502): open/assign/evidence/represent/
# accept/reject/arbitrate/close + hold/release/debit ledger + GL link.
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
db_reset_chargeback
db_exec "DELETE FROM card_transaction WHERE auth_ref LIKE 'CHD-%';"
db_exec "DELETE FROM card_account WHERE card_ref='CHD-C1';"
db_exec "INSERT INTO card_account (card_ref, customer_email, card_type, status, limit_amount, currency, created_by) VALUES ('CHD-C1','cb@test.com','CREDIT','ACTIVE',5000000,'IDR','admin@test.com');"
CID="$(db_query "SELECT id FROM card_account WHERE card_ref='CHD-C1';")"
db_exec "INSERT INTO card_transaction (card_id, auth_ref, txn_type, amount, currency, merchant, status) VALUES (${CID}, 'CHD-A1', 'CAPTURE', 1000000, 'IDR', 'Toko', 'CAPTURED'), (${CID}, 'CHD-A2', 'CAPTURE', 800000, 'IDR', 'Toko', 'CAPTURED'), (${CID}, 'CHD-A3', 'AUTHORIZATION', 500000, 'IDR', 'Toko', 'AUTHORIZED'), (${CID}, 'CHD-A4', 'CAPTURE', 600000, 'IDR', 'Toko', 'CAPTURED'), (${CID}, 'CHD-A5', 'CAPTURE', 300000, 'IDR', 'Toko', 'CAPTURED');"
T1="$(db_query "SELECT id FROM card_transaction WHERE auth_ref='CHD-A1';")"
T2="$(db_query "SELECT id FROM card_transaction WHERE auth_ref='CHD-A2';")"
T3="$(db_query "SELECT id FROM card_transaction WHERE auth_ref='CHD-A3';")"
T4="$(db_query "SELECT id FROM card_transaction WHERE auth_ref='CHD-A4';")"
T5="$(db_query "SELECT id FROM card_transaction WHERE auth_ref='CHD-A5';")"

# OPEN happy path + guards.
out="$(run_cobol "CHB_OPEN|CHD-1|${T1}|500000|FRAUD||admin@test.com")"
assert_match "open ok" "$out" "SUCCESS\|CHB_OPEN\|[0-9]+"
id="$(printf '%s' "$out" | awk -F'|' '{print $3}')"
assert_match "status open" "$(db_query "SELECT status FROM chargeback_case WHERE case_id=${id};")" "^OPEN$"
assert_match "deadline set" "$(db_query "SELECT deadline IS NOT NULL FROM chargeback_case WHERE case_id=${id};")" "^1$"
assert_match "hold row" "$(db_query "SELECT COUNT(*) FROM chargeback_ledger WHERE case_id=${id} AND entry_type='HOLD';")" "^1$"
assert_match "open event" "$(db_query "SELECT COUNT(*) FROM chargeback_event WHERE case_id=${id} AND event_type='OPENED';")" "^1$"
assert_match "duplicate ref" "$(run_cobol "CHB_OPEN|CHD-1|${T1}|1|FRAUD||admin@test.com")" "ERROR\|DUPLICATE"
assert_match "duplicate active txn" "$(run_cobol "CHB_OPEN|CHD-X|${T1}|1|FRAUD||admin@test.com")" "ERROR\|DUPLICATE"
assert_match "over amount" "$(run_cobol "CHB_OPEN|CHD-Y|${T2}|900000|FRAUD||admin@test.com")" "ERROR\|LIMIT"
assert_match "unknown txn" "$(run_cobol "CHB_OPEN|CHD-Z|999999999|1|FRAUD||admin@test.com")" "ERROR\|NOT_FOUND"
assert_match "non-captured txn" "$(run_cobol "CHB_OPEN|CHD-W|${T3}|100|FRAUD||admin@test.com")" "ERROR\|INVALID_STATE"
assert_match "assign" "$(run_cobol "CHB_ASSIGN|${id}|officer@test.com||||admin@test.com")" "SUCCESS\|CHB_ASSIGN"

# EVIDENCE then REPRESENT.
assert_match "evidence" "$(run_cobol "CHB_EVIDENCE|${id}|SLIP|DOC-1|nota||admin@test.com")" "SUCCESS\|CHB_EVIDENCE"
assert_match "evidence state" "$(db_query "SELECT status FROM chargeback_case WHERE case_id=${id};")" "^EVIDENCE_REQUIRED$"
assert_match "represent needs evidence" "$(run_cobol "CHB_OPEN|CHD-E|${T2}|100|FRAUD||admin@test.com" >/dev/null; E2=$(db_query "SELECT case_id FROM chargeback_case WHERE case_ref='CHD-E';"); run_cobol "CHB_REPRESENT|${E2}|||||admin@test.com")" "ERROR\|INVALID_STATE"
assert_match "represent" "$(run_cobol "CHB_REPRESENT|${id}|||||admin@test.com")" "SUCCESS\|CHB_REPRESENT"

# ACCEPT with GL link, then CLOSE.
assert_match "accept" "$(run_cobol "CHB_ACCEPT|${id}|9101||||admin@test.com")" "SUCCESS\|CHB_ACCEPT"
assert_match "accepted" "$(db_query "SELECT status FROM chargeback_case WHERE case_id=${id};")" "^ACCEPTED$"
assert_match "debit row" "$(db_query "SELECT COUNT(*) FROM chargeback_ledger WHERE case_id=${id} AND entry_type='DEBIT';")" "^1$"
assert_match "gl linked" "$(db_query "SELECT gl_journal_id FROM chargeback_ledger WHERE case_id=${id} AND entry_type='DEBIT';")" "^9101$"
assert_match "close" "$(run_cobol "CHB_CLOSE|${id}|Menang||||admin@test.com")" "SUCCESS\|CHB_CLOSE"
assert_match "closed" "$(db_query "SELECT status FROM chargeback_case WHERE case_id=${id};")" "^CLOSED$"

# REJECT flow with RELEASE, then ARBITRATE, then CLOSE.
out2="$(run_cobol "CHB_OPEN|CHD-2|${T4}|200000|FRAUD||admin@test.com")"
id2="$(printf '%s' "$out2" | awk -F'|' '{print $3}')"
run_cobol "CHB_EVIDENCE|${id2}|SLIP|D2|n||admin@test.com" >/dev/null
run_cobol "CHB_REPRESENT|${id2}|||||admin@test.com" >/dev/null
assert_match "reject" "$(run_cobol "CHB_REJECT|${id2}|||||admin@test.com")" "SUCCESS\|CHB_REJECT"
assert_match "released" "$(db_query "SELECT status FROM chargeback_case WHERE case_id=${id2};")" "^REJECTED$"
assert_match "release row" "$(db_query "SELECT COUNT(*) FROM chargeback_ledger WHERE case_id=${id2} AND entry_type='RELEASE';")" "^1$"
assert_match "arbitrate" "$(run_cobol "CHB_ARBITRATE|${id2}|||||admin@test.com")" "SUCCESS\|CHB_ARBITRATE"
assert_match "arbitration" "$(db_query "SELECT status FROM chargeback_case WHERE case_id=${id2};")" "^ARBITRATION$"
assert_match "close after arbitration" "$(run_cobol "CHB_CLOSE|${id2}|Kalah||||admin@test.com")" "SUCCESS\|CHB_CLOSE"

# CLOSE blocked on OPEN; ACCEPT blocked on CLOSED.
out3="$(run_cobol "CHB_OPEN|CHD-3|${T5}|100|FRAUD||admin@test.com")"
id3="$(printf '%s' "$out3" | awk -F'|' '{print $3}')"
assert_match "close blocked open" "$(run_cobol "CHB_CLOSE|${id3}|x||||admin@test.com")" "ERROR\|INVALID_STATE"
assert_match "accept on closed invalid" "$(run_cobol "CHB_ACCEPT|${id}|||||admin@test.com")" "ERROR\|INVALID_STATE"
assert_match "audit rows" "$(db_query "SELECT COUNT(*) FROM chargeback_audit WHERE chargeback_id=${id};")" "^[1-9]"
assert_match "non-admin refused" "$(run_cobol "CHB_OPEN|CHD-Z|${T2}|1|FRAUD||sender@test.com")" "ERROR\|FORBIDDEN"

# Cleanup.
db_exec "DELETE FROM chargeback_event WHERE case_id IN (SELECT case_id FROM chargeback_case WHERE case_ref LIKE 'CHD-%');"
db_exec "DELETE FROM chargeback_ledger WHERE case_id IN (SELECT case_id FROM chargeback_case WHERE case_ref LIKE 'CHD-%');"
db_exec "DELETE FROM chargeback_case WHERE case_ref LIKE 'CHD-%';"
db_exec "DELETE FROM chargeback_audit WHERE detail LIKE 'CHD-%';"
db_exec "DELETE FROM card_transaction WHERE auth_ref LIKE 'CHD-%';"
db_exec "DELETE FROM card_account WHERE card_ref='CHD-C1';"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
