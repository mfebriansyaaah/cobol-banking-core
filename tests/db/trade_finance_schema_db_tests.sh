#!/usr/bin/env bash
# Trade Finance schema/constraint tests (PR-201).
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/tests/lib/db.sh"
require_db

T_PASS=0; T_FAIL=0; T_TOTAL=0
# shellcheck disable=SC1091
. "$ROOT/tests/lib/assert.sh"

# Fresh LC row with domain columns.
db_exec "DELETE FROM letter_of_credit WHERE lc_ref='LCS-T1';"
db_exec "INSERT INTO letter_of_credit (lc_ref, applicant_customer_ref, applicant_name, beneficiary_name, lc_type, currency, lc_amount, expiry_date, status, created_by) VALUES ('LCS-T1','CST-W1-1','John Doe','PT Buyer','SIGHT','IDR',1000000,'2026-12-31','DRAFT','admin@test.com');"
LC_ID="$(db_query "SELECT id FROM letter_of_credit WHERE lc_ref='LCS-T1';")"
assert_match "lc inserted" "$LC_ID" "^[0-9]+$"
assert_match "lc status draft" "$(db_query "SELECT status FROM letter_of_credit WHERE id=${LC_ID};")" "^DRAFT$"

# Amendment unique per LC.
db_exec "INSERT INTO lc_amendment (lc_id, amendment_no, amount_delta, created_by) VALUES (${LC_ID}, 1, 50000, 'admin@test.com');"
assert_match "amendment row" "$(db_query "SELECT COUNT(*) FROM lc_amendment WHERE lc_id=${LC_ID};")" "^1$"
db_exec "INSERT INTO lc_amendment (lc_id, amendment_no, amount_delta, created_by) VALUES (${LC_ID}, 1, 1, 'admin@test.com');" 2>/dev/null
assert_match "amendment unique" "$(db_query "SELECT COUNT(*) FROM lc_amendment WHERE lc_id=${LC_ID};")" "^1$"

# Drawing positive amount + unique no.
db_exec "INSERT INTO lc_drawing (lc_id, drawing_no, amount, currency, created_by) VALUES (${LC_ID}, 1, 100000, 'IDR', 'admin@test.com');"
assert_match "drawing row" "$(db_query "SELECT COUNT(*) FROM lc_drawing WHERE lc_id=${LC_ID};")" "^1$"
db_exec "INSERT INTO lc_drawing (lc_id, drawing_no, amount, currency, created_by) VALUES (${LC_ID}, 2, 0, 'IDR', 'admin@test.com');" 2>/dev/null
assert_match "drawing amount check" "$(db_query "SELECT COUNT(*) FROM lc_drawing WHERE lc_id=${LC_ID};")" "^1$"

# Settlement FK drawing.
DRAW_ID="$(db_query "SELECT drawing_id FROM lc_drawing WHERE lc_id=${LC_ID} LIMIT 1;")"
db_exec "INSERT INTO lc_settlement (drawing_id, settled_amount, created_by) VALUES (${DRAW_ID}, 50000, 'admin@test.com');"
assert_match "settlement row" "$(db_query "SELECT COUNT(*) FROM lc_settlement WHERE drawing_id=${DRAW_ID};")" "^1$"

# BG domain columns + claim.
db_exec "DELETE FROM bank_guarantee WHERE guarantee_ref='BGS-T1';"
db_exec "INSERT INTO bank_guarantee (guarantee_ref, applicant_customer_ref, beneficiary_name, guarantee_type, currency, guarantee_amount, expiry_date, status, created_by) VALUES ('BGS-T1','CST-W1-1','PT Seller','PERFORMANCE','IDR',2000000,'2026-12-31','ISSUED','admin@test.com');"
BG_ID="$(db_query "SELECT id FROM bank_guarantee WHERE guarantee_ref='BGS-T1';")"
assert_match "bg inserted" "$BG_ID" "^[0-9]+$"
db_exec "INSERT INTO bg_claim (guarantee_id, claim_ref, amount, created_by) VALUES (${BG_ID}, 'BGC-T1', 100000, 'admin@test.com');"
assert_match "bg claim row" "$(db_query "SELECT COUNT(*) FROM bg_claim WHERE guarantee_id=${BG_ID};")" "^1$"
db_exec "INSERT INTO bg_claim (guarantee_id, claim_ref, amount, created_by) VALUES (${BG_ID}, 'BGC-T1', 1, 'admin@test.com');" 2>/dev/null
assert_match "bg claim unique" "$(db_query "SELECT COUNT(*) FROM bg_claim WHERE guarantee_id=${BG_ID};")" "^1$"

# Cleanup.
db_exec "DELETE FROM letter_of_credit WHERE lc_ref='LCS-T1';"
db_exec "DELETE FROM bank_guarantee WHERE guarantee_ref='BGS-T1';"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
