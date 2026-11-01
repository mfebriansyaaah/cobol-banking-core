#!/usr/bin/env bash
# Integration: card capture -> chargeback -> hold -> represent -> accept -> GL.
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
ADMIN="cbint@test.com"
db_exec "INSERT INTO users (email, password_hash, full_name, dob, status, role) VALUES ('$ADMIN', CONCAT('SHA256_',SHA2('secret123',256)), 'Cb Int', '1990-01-01', 'VERIFIED', 'SUPER_ADMIN') ON DUPLICATE KEY UPDATE role='SUPER_ADMIN', status='VERIFIED';"
db_exec "DELETE FROM card_transaction WHERE auth_ref LIKE 'CHB-I%';"
db_exec "DELETE FROM card_account WHERE card_ref='CHB-INT';"
db_exec "INSERT INTO card_account (card_ref, customer_email, card_type, status, limit_amount, currency, created_by) VALUES ('CHB-INT','$ADMIN','CREDIT','ACTIVE',5000000,'IDR','admin@test.com');"
CID=$(db_query "SELECT id FROM card_account WHERE card_ref='CHB-INT';")
db_exec "INSERT INTO card_transaction (card_id, auth_ref, txn_type, amount, currency, merchant, status) VALUES (${CID}, 'CHB-I1', 'CAPTURE', 1000000, 'IDR', 'Toko', 'CAPTURED'), (${CID}, 'CHB-I2', 'CAPTURE', 500000, 'IDR', 'Toko', 'CAPTURED');"
T1=$(db_query "SELECT id FROM card_transaction WHERE auth_ref='CHB-I1';")
T2=$(db_query "SELECT id FROM card_transaction WHERE auth_ref='CHB-I2';")

echo "=== Chargeback integration (card -> hold -> accept -> GL) ==="
# GL posting date must fall in an OPEN period (gl_period holds the current month).
GL_DATE="$(date +%F)"

# Merchant for reporting linkage.
MOUT=$(run_cobol "MRT_CREATE|CHB-INT-M|Toko Int|RETAIL|||admin@test.com")
MID=$(printf '%s' "$MOUT" | awk -F'|' '{print $3}')

OUT=$(run_cobol "CHB_OPEN|CHB-INT-1|${T1}|500000|FRAUD|${MID}|admin@test.com")
assert_match "open" "$OUT" "SUCCESS\|CHB_OPEN"
CB=$(printf '%s' "$OUT" | awk -F'|' '{print $3}')
assert_match "get detail" "$(run_cobol "CHB_CASE_GET|${CB}|||||admin@test.com")" "SUCCESS\|CHB_CASE_GET"
assert_match "evidence" "$(run_cobol "CHB_EVIDENCE|${CB}|SLIP|DOC-I1|nota||$ADMIN" | head -c 200)" "SUCCESS\|CHB_EVIDENCE"
assert_match "represent" "$(run_cobol "CHB_REPRESENT|${CB}|||||$ADMIN")" "SUCCESS\|CHB_REPRESENT"

# Payment clearing stub + GL for the accept leg.
run_cobol "PMC_CREATE|PMC-CHB-1|500000|IDR|||admin@test.com" >/dev/null
GOUT=$(run_cobol "GL_JOURNAL_POST|${GL_DATE}|Chargeback CHB-INT-1|5000|1100|IDR:500000|admin@test.com")
assert_match "gl posted" "$GOUT" "SUCCESS\|GL_POSTED"
GJ=$(db_query "SELECT id FROM gl_journal ORDER BY id DESC LIMIT 1;")
assert_match "accept" "$(run_cobol "CHB_ACCEPT|${CB}|${GJ}|PMC-CHB-1|||$ADMIN")" "SUCCESS\|CHB_ACCEPT"
assert_match "pmc linked" "$(db_query "SELECT payment_clearing_ref FROM chargeback_case WHERE case_id=${CB};")" "^PMC-CHB-1$"
assert_match "ledger balanced" "$(db_query "SELECT IF(SUM(CASE WHEN entry_type='HOLD' THEN amount ELSE 0 END)=SUM(CASE WHEN entry_type='DEBIT' THEN amount ELSE 0 END),'BALANCED','UNBALANCED') FROM chargeback_ledger WHERE case_id=${CB};")" "^BALANCED$"
assert_match "close" "$(run_cobol "CHB_CLOSE|${CB}|Menang||||$ADMIN")" "SUCCESS\|CHB_CLOSE"

# Merchant report shows the case; summary aggregates.
assert_match "merchant report" "$(run_cobol "CHB_CASE_LIST|${MID}||50|0||admin@test.com")" "CHB-INT-1"
assert_match "summary" "$(run_cobol "CHB_CASE_SUMMARY|${MID}|||||admin@test.com")" "SUCCESS\|CHB_CASE_SUMMARY"

# Second txn: expired deadline blocks represent.
OUT2=$(run_cobol "CHB_OPEN|CHB-INT-2|${T2}|100000|FRAUD||admin@test.com")
CB2=$(printf '%s' "$OUT2" | awk -F'|' '{print $3}')
run_cobol "CHB_EVIDENCE|${CB2}|SLIP|D|n||$ADMIN" >/dev/null
db_exec "UPDATE chargeback_case SET deadline = CURDATE() - INTERVAL 1 DAY WHERE case_id=${CB2};"
assert_match "expired deadline" "$(run_cobol "CHB_REPRESENT|${CB2}|||||$ADMIN")" "ERROR\|INVALID_STATE"

# Cleanup.
db_exec "DELETE FROM chargeback_event WHERE case_id IN (${CB},${CB2});"
db_exec "DELETE FROM chargeback_ledger WHERE case_id IN (${CB},${CB2});"
db_exec "DELETE FROM chargeback_audit WHERE chargeback_id IN (${CB},${CB2});"
db_exec "DELETE FROM chargeback_case WHERE case_id IN (${CB},${CB2});"
db_exec "DELETE FROM card_transaction WHERE auth_ref LIKE 'CHB-I%';"
db_exec "DELETE FROM card_account WHERE card_ref='CHB-INT';"
db_exec "DELETE FROM merchant WHERE merchant_ref='CHB-INT-M';"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
