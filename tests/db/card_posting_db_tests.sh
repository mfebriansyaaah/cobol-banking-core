#!/usr/bin/env bash
# Card Fase 1: real posting (toward cards 10/10). CARD_CAPTURE moves money
# (CARD_RECEIVABLE debit / MERCHANT_PAYABLE credit) plus a balanced GL
# journal and links both; CARD_REPAY collects (customer wallet debit /
# CARD_RECEIVABLE credit) plus a balanced GL journal and links both;
# CARD_REVERSE on a capture refunds (MERCHANT_PAYABLE debit / CARD_RECEIVABLE
# credit) plus a balanced GL journal and links both. AUTHORIZE and
# hold-release stay memo-only (a hold locks limit, it moves no money).
# Rejected paths post nothing; double capture/reverse is refused by atomic
# guards. Green twice required.
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

cleanup_fixture() {
    db_exec "DELETE FROM ledger WHERE txn_ref LIKE 'CARD%';"
    db_exec "DELETE FROM card_transaction WHERE card_id IN (SELECT id FROM card_account WHERE customer_email IN ('${WA}','${WR}','${WP}'));"
    db_exec "DELETE FROM card_audit WHERE card_id IN (SELECT id FROM card_account WHERE customer_email IN ('${WA}','${WR}','${WP}'));"
    db_exec "DELETE FROM card_account WHERE customer_email IN ('${WA}','${WR}','${WP}');"
    db_exec "DELETE FROM journal_entries WHERE txn_ref LIKE 'CARD%';"
    db_exec "DELETE FROM gl_journal_line WHERE journal_id IN (SELECT id FROM gl_journal WHERE description LIKE 'CARD\\_%');"
    db_exec "DELETE FROM gl_journal WHERE description LIKE 'CARD\\_%';"
    db_exec "DELETE FROM ledger WHERE account_id IN (SELECT account_id FROM accounts WHERE user_id IN (SELECT id FROM users WHERE email IN ('${WA}','${WR}','${WP}')));"
    db_exec "DELETE FROM accounts WHERE user_id IN (SELECT id FROM users WHERE email IN ('${WA}','${WR}','${WP}'));"
    db_exec "DELETE FROM users WHERE email IN ('${WA}','${WR}','${WP}');"
}


db_seed
db_reset_card
# Fase 1: CAPTURE/REPAY move real money, so the cardholder owns a wallet,
# the bank-owned CARD_RECEIVABLE / MERCHANT_PAYABLE books are capitalized,
# and the GL period is open.
A="admin@test.com"
WA="crdA@test.com"
WR="crdR@test.com"
WP="crdP@test.com"
CUR="$(date +%Y-%m)"
run_cobol "GL_PERIOD_OPEN|${CUR}|||||${A}" >/dev/null
cleanup_fixture
for U in "$WA" "$WR" "$WP"; do
    db_exec "DELETE FROM ledger WHERE account_id IN (SELECT account_id FROM accounts WHERE user_id IN (SELECT id FROM users WHERE email='${U}'));"
    db_exec "DELETE FROM pending_transactions WHERE from_email='${U}' OR to_email='${U}';"
    db_exec "DELETE FROM card_transaction WHERE card_id IN (SELECT id FROM card_account WHERE customer_email='${U}');"
    db_exec "DELETE FROM card_audit WHERE card_id IN (SELECT id FROM card_account WHERE customer_email='${U}');"
    db_exec "DELETE FROM card_account WHERE customer_email='${U}';"
    db_exec "DELETE FROM accounts WHERE user_id IN (SELECT id FROM users WHERE email='${U}');"
    db_exec "DELETE FROM users WHERE email='${U}';"
    run_cobol "REQUEST_SIGNUP|${U}|Passw0rd!|Card T|1990-01-01" >/dev/null
    code="$(db_query "SELECT code FROM verification_logs WHERE email='${U}' AND is_used=0 ORDER BY id DESC LIMIT 1;")"
    run_cobol "VERIFY_EMAIL|${U}|${code}" >/dev/null
done
db_exec "INSERT INTO accounts (user_id, currency_id, balance) SELECT id, 1, 5000.00 FROM users WHERE email='${WA}';"
db_exec "INSERT INTO accounts (user_id, currency_id, account_type, balance) SELECT id, 1, 'CARD_RECEIVABLE', 1000000.00 FROM users WHERE email='${WR}';"
db_exec "INSERT INTO accounts (user_id, currency_id, account_type, balance) SELECT id, 1, 'MERCHANT_PAYABLE', 1000000.00 FROM users WHERE email='${WP}';"
ACCTW="$(db_query "SELECT account_id FROM accounts WHERE user_id=(SELECT id FROM users WHERE email='${WA}') AND currency_id=1;")"
BOOKR="$(db_query "SELECT account_id FROM accounts WHERE account_type='CARD_RECEIVABLE' AND currency_id=1;")"
BOOKP="$(db_query "SELECT account_id FROM accounts WHERE account_type='MERCHANT_PAYABLE' AND currency_id=1;")"
bal() { db_query "SELECT balance FROM accounts WHERE account_id=$1;"; }
net() { db_query "SELECT COALESCE(SUM(CASE WHEN type='CREDIT' THEN amount ELSE -amount END),0) FROM ledger WHERE account_id=$1;"; }
total() { db_query "SELECT COALESCE(SUM(balance),0) FROM accounts WHERE account_id IN (${ACCTW},${BOOKR},${BOOKP});"; }
balanced() { db_query "SELECT COUNT(*) FROM (SELECT l.journal_id FROM ledger l WHERE l.journal_id IS NOT NULL AND EXISTS (SELECT 1 FROM ledger x WHERE x.journal_id = l.journal_id AND x.account_id IN (${ACCTW},${BOOKR},${BOOKP})) GROUP BY l.journal_id HAVING ABS(SUM(CASE WHEN l.type='DEBIT' THEN l.amount ELSE -l.amount END)) > 0.0001) t;"; }


# 1-4. Issue a card; authorization is memo-only (hold, no money).
issue_out="$(run_cobol "CARD_ISSUE|CRD-P1|${WA}|CREDIT|5000.00|USD|${A}")"
assert_match "CARD_ISSUE ok" "$issue_out" "SUCCESS\|CARD_ISSUE\|[0-9]+"
CID="$(printf '%s' "$issue_out" | awk -F'|' '{print $3}')"
assert_match "card id present" "$CID" "^[0-9]+$"
auth_out="$(run_cobol "CARD_AUTHORIZE|${CID}|300.00|Shop A|USD||${A}")"
assert_match "CARD_AUTHORIZE ok" "$auth_out" "SUCCESS\|CARD_AUTHORIZE\|AUTH-"
AUTH="$(printf '%s' "$auth_out" | awk -F'|' '{print $3}')"
assert_match "hold reduces limit only" "$(db_query "SELECT CONCAT(available_limit,'|',balance) FROM card_account WHERE id=${CID};")" "^4700.0000\|0.0000$"
assert_match "authorize posts no legs" "$(db_query "SELECT COUNT(*) FROM ledger WHERE txn_ref LIKE 'CARD%';")" "^0$"

# 5-12. Capture posts money + GL and links both; double capture refused.
assert_match "CARD_CAPTURE ok" "$(run_cobol "CARD_CAPTURE|${CID}|${AUTH}||||${A}")" "SUCCESS\|CARD_CAPTURE\|300.0000"
assert_match "receivable debited" "$(bal "$BOOKR")" "^999700.0000$"
assert_match "merchant payable credited" "$(bal "$BOOKP")" "^1000300.0000$"
assert_match "two capture legs posted" "$(db_query "SELECT COUNT(*) FROM ledger WHERE txn_ref='CARDCAP-${AUTH}';")" "^2$"
assert_match "capture links journal" "$(db_query "SELECT journal_id FROM card_transaction WHERE auth_ref='${AUTH}';")" "^[0-9]+$"
assert_match "capture links gl" "$(db_query "SELECT gl_journal_id FROM card_transaction WHERE auth_ref='${AUTH}';")" "^[0-9]+$"
assert_match "capture gl balanced" "$(db_query "SELECT COUNT(*) FROM (SELECT journal_id FROM gl_journal_line WHERE journal_id=(SELECT gl_journal_id FROM card_transaction WHERE auth_ref='${AUTH}') GROUP BY journal_id HAVING ABS(SUM(debit_amount - credit_amount)) > 0.0001) t;")" "^0$"
assert_match "capture books expense side" "$(db_query "SELECT COUNT(*) FROM gl_journal_line WHERE journal_id=(SELECT gl_journal_id FROM card_transaction WHERE auth_ref='${AUTH}') AND gl_account_code='1310';")" "^1$"
assert_match "double capture refused" "$(run_cobol "CARD_CAPTURE|${CID}|${AUTH}||||${A}")" "ERROR\|INVALID_STATUS"
assert_match "no duplicate capture journal" "$(db_query "SELECT COUNT(*) FROM gl_journal WHERE description LIKE 'CARD_CAPTURE:${AUTH}%';")" "^1$"

# 13-16. Missing books fail closed.
db_exec "UPDATE accounts SET status='FROZEN' WHERE account_id=${BOOKR};"
auth2="$(run_cobol "CARD_AUTHORIZE|${CID}|50.00|Shop B|USD||${A}")"
auth2_ref="$(printf '%s' "$auth2" | awk -F'|' '{print $3}')"
assert_match "missing receivable fails closed" "$(run_cobol "CARD_CAPTURE|${CID}|${auth2_ref}||||${A}")" "ERROR\|CARD_RECEIVABLE_MISSING"
db_exec "UPDATE accounts SET status='ACTIVE' WHERE account_id=${BOOKR};"
db_exec "UPDATE accounts SET status='FROZEN' WHERE account_id=${BOOKP};"
assert_match "missing payable fails closed" "$(run_cobol "CARD_CAPTURE|${CID}|${auth2_ref}||||${A}")" "ERROR\|MERCHANT_PAYABLE_MISSING"
db_exec "UPDATE accounts SET status='ACTIVE' WHERE account_id=${BOOKP};"
assert_match "capture works after unfreeze" "$(run_cobol "CARD_CAPTURE|${CID}|${auth2_ref}||||${A}")" "SUCCESS\|CARD_CAPTURE\|50.0000"

# 17-26. Repay posts money + GL and links both; overpay fails closed.
assert_match "CARD_REPAY ok" "$(run_cobol "CARD_REPAY|${CID}|100.00||||${A}")" "SUCCESS\|CARD_REPAY\|100.00"
assert_match "wallet debited" "$(bal "$ACCTW")" "^4900.0000$"
assert_match "card balance paid down" "$(db_query "SELECT balance FROM card_account WHERE id=${CID};")" "^250.0000$"
assert_match "receivable credited" "$(bal "$BOOKR")" "^999750.0000$"
assert_match "two repay legs posted" "$(db_query "SELECT COUNT(*) FROM ledger WHERE txn_ref LIKE 'CARDRP-%' AND account_id IN (${ACCTW},${BOOKR});")" "^2$"
assert_match "repay links journal" "$(db_query "SELECT COUNT(DISTINCT journal_id) FROM card_transaction WHERE card_id=${CID} AND txn_type='REPAYMENT';")" "^1$"
assert_match "repay links gl" "$(db_query "SELECT COUNT(DISTINCT gl_journal_id) FROM card_transaction WHERE card_id=${CID} AND txn_type='REPAYMENT';")" "^1$"
assert_match "repay gl balanced" "$(db_query "SELECT COUNT(*) FROM (SELECT journal_id FROM gl_journal_line WHERE journal_id IN (SELECT DISTINCT journal_id FROM ledger WHERE txn_ref LIKE 'CARDRP-%') GROUP BY journal_id HAVING ABS(SUM(debit_amount - credit_amount)) > 0.0001) t;")" "^0$"
assert_match "overpay refused" "$(run_cobol "CARD_REPAY|${CID}|99999.00||||${A}")" "ERROR\|OVERPAID"
assert_match "overpay posted nothing" "$(db_query "SELECT COUNT(*) FROM ledger WHERE txn_ref LIKE 'CARDRP-%' AND amount=99999.0000;")" "^0$"

# 27-32. No wallet + outstanding balance fails closed on the wallet
# (the ceiling passes since 50 <= 100 owed); nothing moves.
run_cobol "REQUEST_SIGNUP|crdNW@test.com|Passw0rd!|Card Nw|1990-01-01" >/dev/null
nwcode="$(db_query "SELECT code FROM verification_logs WHERE email='crdNW@test.com' AND is_used=0 ORDER BY id DESC LIMIT 1;")"
run_cobol "VERIFY_EMAIL|crdNW@test.com|${nwcode}" >/dev/null
run_cobol "CARD_ISSUE|CRD-NW|crdNW@test.com|CREDIT|1000.00|USD|${A}" >/dev/null
NWCID="$(db_query "SELECT id FROM card_account WHERE card_ref='CRD-NW';")"
nw_auth="$(run_cobol "CARD_AUTHORIZE|${NWCID}|100.00|Shop N|USD||${A}")"
nw_ref="$(printf '%s' "$nw_auth" | awk -F'|' '{print $3}')"
run_cobol "CARD_CAPTURE|${NWCID}|${nw_ref}||||${A}" >/dev/null
assert_match "walletless repay refused" "$(run_cobol "CARD_REPAY|${NWCID}|50.00||||${A}")" "ERROR\|ACCOUNT_NOT_FOUND"
assert_match "walletless repay moved nothing" "$(db_query "SELECT COUNT(*) FROM ledger WHERE txn_ref LIKE 'CARDRP-%' AND amount=50.0000;")" "^0$"
assert_match "walletless balance unchanged" "$(db_query "SELECT balance FROM card_account WHERE id=${NWCID};")" "^100.0000$"
db_exec "DELETE FROM card_transaction WHERE card_id=${NWCID}; DELETE FROM card_account WHERE id=${NWCID}; DELETE FROM users WHERE email='crdNW@test.com';"

# 31-38. Reverse of an authorization releases the hold with no posting;
# reverse of a capture refunds with posting + linkage.
auth3="$(run_cobol "CARD_AUTHORIZE|${CID}|70.00|Shop C|USD||${A}")"
auth3_ref="$(printf '%s' "$auth3" | awk -F'|' '{print $3}')"
assert_match "reverse auth ok" "$(run_cobol "CARD_REVERSE|${CID}|${auth3_ref}||||${A}")" "SUCCESS\|CARD_REVERSE"
assert_match "hold released, nothing posted" "$(db_query "SELECT COUNT(*) FROM ledger WHERE txn_ref LIKE 'CARDCAP-${auth3_ref}' OR txn_ref LIKE 'CARDRC-${auth3_ref}';")" "^0$"
rev3="$(run_cobol "CARD_AUTHORIZE|${CID}|80.00|Shop D|USD||${A}")"
rev3_ref="$(printf '%s' "$rev3" | awk -F'|' '{print $3}')"
run_cobol "CARD_CAPTURE|${CID}|${rev3_ref}||||${A}" >/dev/null
assert_match "reverse capture ok" "$(run_cobol "CARD_REVERSE|${CID}|${rev3_ref}||||${A}")" "SUCCESS\|CARD_REVERSE\|80.0000"
assert_match "refund posts two legs" "$(db_query "SELECT COUNT(*) FROM ledger WHERE txn_ref='CARDRC-${rev3_ref}';")" "^2$"
assert_match "refund links both" "$(db_query "SELECT COUNT(*) FROM card_transaction WHERE auth_ref='${rev3_ref}' AND journal_id IS NOT NULL AND gl_journal_id IS NOT NULL;")" "^1$"
assert_match "refund gl balanced" "$(db_query "SELECT COUNT(*) FROM (SELECT journal_id FROM gl_journal_line WHERE journal_id=(SELECT gl_journal_id FROM card_transaction WHERE auth_ref='${rev3_ref}') GROUP BY journal_id HAVING ABS(SUM(debit_amount - credit_amount)) > 0.0001) t;")" "^0$"
assert_match "double reverse refused" "$(run_cobol "CARD_REVERSE|${CID}|${rev3_ref}||||${A}")" "ERROR\|INVALID_STATUS"

# 39-44. Conservation: every unit accounted, journals balanced.
assert_match "wallet net equals spend" "$(net "$ACCTW")" "^-100.0000$"
assert_match "receivable net equals lending" "$(net "$BOOKR")" "^-350.0000$"
assert_match "payable net equals settlements" "$(net "$BOOKP")" "^450.0000$"
assert_match "all journals balanced" "$(balanced)" "^0$"
assert_match "no negatives" "$(db_query "SELECT COUNT(*) FROM accounts WHERE account_id IN (${ACCTW},${BOOKR},${BOOKP}) AND balance < 0;")" "^0$"
assert_match "total conserved" "$(total)" "^2005000.0000$"

cleanup_fixture
print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
