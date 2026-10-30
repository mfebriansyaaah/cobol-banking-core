#!/usr/bin/env bash
# Chargeback schema/constraint tests (PR-501).
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/tests/lib/db.sh"
require_db

T_PASS=0; T_FAIL=0; T_TOTAL=0
# shellcheck disable=SC1091
. "$ROOT/tests/lib/assert.sh"

# Case with card link + deadline.
db_exec "DELETE FROM card_transaction WHERE auth_ref='CHB-TXN-1';"
db_exec "DELETE FROM card_account WHERE card_ref='CHB-CARD-1';"
db_exec "INSERT INTO card_account (card_ref, customer_email, card_type, status, limit_amount, currency, created_by) VALUES ('CHB-CARD-1','cust@test.com','CREDIT','ACTIVE',5000000,'IDR','admin@test.com');"
CARD_ID="$(db_query "SELECT id FROM card_account WHERE card_ref='CHB-CARD-1';")"
db_exec "INSERT INTO card_transaction (card_id, auth_ref, txn_type, amount, currency, merchant, status) VALUES (${CARD_ID}, 'CHB-TXN-1', 'CAPTURE', 1000000, 'IDR', 'Toko', 'CAPTURED');"
TXN_ID="$(db_query "SELECT id FROM card_transaction WHERE auth_ref='CHB-TXN-1';")"

db_exec "INSERT INTO chargeback_case (case_ref, card_transaction_id, card_id, amount, currency, reason_code, status, deadline, opened_by) VALUES ('CHB-S1', ${TXN_ID}, ${CARD_ID}, 1000000, 'IDR', 'FRAUD', 'OPEN', '2026-11-30', 'admin@test.com');"
CID="$(db_query "SELECT case_id FROM chargeback_case WHERE case_ref='CHB-S1';")"
assert_match "case inserted" "$CID" "^[0-9]+$"
assert_match "status open" "$(db_query "SELECT status FROM chargeback_case WHERE case_id=${CID};")" "^OPEN$"
db_exec "INSERT INTO chargeback_case (case_ref, amount, opened_by) VALUES ('CHB-S1', 1, 'admin@test.com');" 2>/dev/null
assert_match "ref unique" "$(db_query "SELECT COUNT(*) FROM chargeback_case WHERE case_ref='CHB-S1';")" "^1$"
db_exec "INSERT INTO chargeback_case (case_ref, amount, opened_by) VALUES ('CHB-NEG', -1, 'admin@test.com');" 2>/dev/null
assert_match "amount check" "$(db_query "SELECT COUNT(*) FROM chargeback_case WHERE case_ref='CHB-NEG';")" "^0$"

# Evidence + event rows.
db_exec "INSERT INTO chargeback_evidence (case_id, evidence_type, document_ref, note, submitted_by) VALUES (${CID}, 'DOCUMENT', 'DOC-1', 'nota', 'admin@test.com');"
assert_match "evidence row" "$(db_query "SELECT COUNT(*) FROM chargeback_evidence WHERE case_id=${CID};")" "^1$"
db_exec "INSERT INTO chargeback_event (case_id, event_type, actor_email) VALUES (${CID}, 'OPENED', 'admin@test.com');"
assert_match "event row" "$(db_query "SELECT COUNT(*) FROM chargeback_event WHERE case_id=${CID};")" "^1$"

# Ledger hold + release rows.
db_exec "INSERT INTO chargeback_ledger (case_id, entry_type, amount, currency, created_by) VALUES (${CID}, 'HOLD', 1000000, 'IDR', 'admin@test.com');"
assert_match "ledger hold" "$(db_query "SELECT COUNT(*) FROM chargeback_ledger WHERE case_id=${CID} AND entry_type='HOLD';")" "^1$"
db_exec "INSERT INTO chargeback_ledger (case_id, entry_type, amount, created_by) VALUES (${CID}, 'HOLD', -1, 'admin@test.com');" 2>/dev/null
assert_match "ledger amount check" "$(db_query "SELECT COUNT(*) FROM chargeback_ledger WHERE case_id=${CID} AND amount<0;")" "^0$"

# Cleanup (children cascade from case; card rows removed explicitly).
db_exec "DELETE FROM chargeback_case WHERE case_ref='CHB-S1';"
db_exec "DELETE FROM card_transaction WHERE auth_ref='CHB-TXN-1';"
db_exec "DELETE FROM card_account WHERE card_ref='CHB-CARD-1';"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
