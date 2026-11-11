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

# 45-52. Concurrent repays at the ceiling (balance 250): two 150
# repays serialize on the guarded debit; exactly one wins, the loser
# sees OVERPAID, and only one payment posts.
G1="$(mktemp -d /tmp/cobol-test.XXXXXX)"; G2="$(mktemp -d /tmp/cobol-test.XXXXXX)"
printf 'CARD_REPAY|%s|150.00||||admin@test.com\n' "$CID" >"$G1/input.txt"
printf 'CARD_REPAY|%s|150.00||||admin@test.com\n' "$CID" >"$G2/input.txt"
BIN="$PWD/cobol/bin/main_logic"
(cd "$G1" && timeout 30s "$BIN" >/dev/null 2>&1) &
Q1=$!
(cd "$G2" && timeout 30s "$BIN" >/dev/null 2>&1) &
Q2=$!
wait $Q1; wait $Q2
GA="$(tr -d ' \n' <"$G1/output.txt")"; GB="$(tr -d ' \n' <"$G2/output.txt")"
rm -rf "$G1" "$G2"
assert_match "exactly one repay winner" "$(printf '%s\n%s\n' "$GA" "$GB" | grep -c "SUCCESS|CARD_REPAY")" "^1$"
assert_match "race loser overpays" "$(printf '%s\n%s\n' "$GA" "$GB")" "ERROR\|OVERPAID"
assert_match "ceiling holds under race" "$(db_query "SELECT balance FROM card_account WHERE id=${CID};")" "^100.0000$"
assert_match "race posted one payment" "$(db_query "SELECT COUNT(*) FROM ledger WHERE txn_ref LIKE 'CARDRP-%' AND account_id=${ACCTW} AND amount=150.0000;")" "^1$"

# 53-60. Concurrent captures of one authorization: exactly one wins and a
# single posting lands. The loser error depends on the interleaving
# (pre-check INVALID_STATUS vs in-txn guard DB_ERROR), so only the winner
# count and the single posting are asserted.
authR="$(run_cobol "CARD_AUTHORIZE|${CID}|60.00|Shop R|USD||${A}")"
authR_ref="$(printf '%s' "$authR" | awk -F'|' '{print $3}')"
H1="$(mktemp -d /tmp/cobol-test.XXXXXX)"; H2="$(mktemp -d /tmp/cobol-test.XXXXXX)"
printf 'CARD_CAPTURE|%s|%s||||admin@test.com\n' "$CID" "$authR_ref" >"$H1/input.txt"
printf 'CARD_CAPTURE|%s|%s||||admin@test.com\n' "$CID" "$authR_ref" >"$H2/input.txt"
(cd "$H1" && timeout 30s "$BIN" >/dev/null 2>&1) &
R1=$!
(cd "$H2" && timeout 30s "$BIN" >/dev/null 2>&1) &
R2=$!
wait $R1; wait $R2
HA="$(tr -d ' \n' <"$H1/output.txt")"; HB="$(tr -d ' \n' <"$H2/output.txt")"
rm -rf "$H1" "$H2"
assert_match "exactly one capture winner" "$(printf '%s\n%s\n' "$HA" "$HB" | grep -c "SUCCESS\|CARD_CAPTURE")" "^1$"
assert_match "capture loser refused" "$(printf '%s\n%s\n' "$HA" "$HB" | grep -c "ERROR")" "^1$"
assert_match "single capture posting" "$(db_query "SELECT COUNT(*) FROM ledger WHERE txn_ref='CARDCAP-${authR_ref}';")" "^2$"

# 60-77. Keyed capture: same key replays the stored outcome instead of
# posting again; different amount conflicts; concurrent keys serialize;
# doomed keys stay usable; stale keys are taken over.
run_cobol "CARD_ISSUE|CRD-K1|${WA}|CREDIT|5000.00|USD|${A}" >/dev/null
KID="$(db_query "SELECT id FROM card_account WHERE card_ref='CRD-K1';")"
kauth="$(run_cobol "CARD_AUTHORIZE|${KID}|400.00|Shop K|USD||${A}")"
kauth_ref="$(printf '%s' "$kauth" | awk -F'|' '{print $3}')"
assert_match "keyed capture ok" "$(run_cobol "CARD_CAPTURE|${KID}|${kauth_ref}|||K-C1|${A}")" "SUCCESS\|CARD_CAPTURE\|400.0000"
assert_match "keyed capture replay ok" "$(run_cobol "CARD_CAPTURE|${KID}|${kauth_ref}|||K-C1|${A}")" "SUCCESS\|CARD_CAPTURE\|400.0000"
assert_match "replay posted once" "$(db_query "SELECT COUNT(*) FROM ledger WHERE txn_ref='CARDCAP-${kauth_ref}';")" "^2$"
assert_match "capture request recorded DONE" "$(db_query "SELECT status FROM card_capture_request WHERE card_id=${KID} AND idempotency_key='K-C1';")" "^DONE$"
db_exec "UPDATE card_capture_request SET amount = 1.00 WHERE card_id=${KID} AND idempotency_key='K-C1';"
assert_match "changed amount conflicts" "$(run_cobol "CARD_CAPTURE|${KID}|${kauth_ref}|||K-C1|${A}")" "ERROR\|IDEMPOTENCY_CONFLICT"
assert_match "conflict posted nothing new" "$(db_query "SELECT COUNT(*) FROM ledger WHERE txn_ref='CARDCAP-${kauth_ref}';")" "^2$"
db_exec "UPDATE card_capture_request SET amount = 400.00 WHERE card_id=${KID} AND idempotency_key='K-C1';"
kauth2="$(run_cobol "CARD_AUTHORIZE|${KID}|300.00|Shop KR|USD||${A}")"
kauth2_ref="$(printf '%s' "$kauth2" | awk -F'|' '{print $3}')"
K1="$(mktemp -d /tmp/cobol-test.XXXXXX)"; K2="$(mktemp -d /tmp/cobol-test.XXXXXX)"
printf 'CARD_CAPTURE|%s|%s|||K-CRACE|admin@test.com\n' "$KID" "$kauth2_ref" >"$K1/input.txt"
printf 'CARD_CAPTURE|%s|%s|||K-CRACE|admin@test.com\n' "$KID" "$kauth2_ref" >"$K2/input.txt"
(cd "$K1" && timeout 30s "$BIN" >/dev/null 2>&1) &
V1=$!
(cd "$K2" && timeout 30s "$BIN" >/dev/null 2>&1) &
V2=$!
wait $V1; wait $V2
VA="$(tr -d ' \n' <"$K1/output.txt")"; VB="$(tr -d ' \n' <"$K2/output.txt")"
rm -rf "$K1" "$K2"
assert_match "exactly one keyed winner" "$(printf '%s\n%s\n' "$VA" "$VB" | grep -c "SUCCESS\|CARD_CAPTURE")" "^1$"
assert_match "keyed loser in progress" "$(printf '%s\n%s\n' "$VA" "$VB")" "ERROR\|CAPTURE_IN_PROGRESS"
assert_match "keyed retry converges" "$(run_cobol "CARD_CAPTURE|${KID}|${kauth2_ref}|||K-CRACE|${A}")" "SUCCESS\|CARD_CAPTURE\|300.0000"
assert_match "single posting for key" "$(db_query "SELECT COUNT(*) FROM ledger WHERE txn_ref='CARDCAP-${kauth2_ref}';")" "^2$"
kauth3="$(run_cobol "CARD_AUTHORIZE|${KID}|50.00|Shop KD|USD||${A}")"
kauth3_ref="$(printf '%s' "$kauth3" | awk -F'|' '{print $3}')"
run_cobol "CARD_CAPTURE|${KID}|${kauth3_ref}||||${A}" >/dev/null
assert_match "keyed capture on captured refused" "$(run_cobol "CARD_CAPTURE|${KID}|${kauth3_ref}|||K-DOOM|${A}")" "ERROR\|INVALID_STATUS"
assert_match "doomed key not blocked" "$(run_cobol "CARD_CAPTURE|${KID}|${kauth3_ref}|||K-DOOM|${A}")" "ERROR\|INVALID_STATUS"
assert_match "no capture request residue" "$(db_query "SELECT COUNT(*) FROM card_capture_request WHERE card_id=${KID} AND idempotency_key='K-DOOM';")" "^0$"
kauth4="$(run_cobol "CARD_AUTHORIZE|${KID}|60.00|Shop KT|USD||${A}")"
kauth4_ref="$(printf '%s' "$kauth4" | awk -F'|' '{print $3}')"
db_exec "INSERT INTO card_capture_request (card_id, idempotency_key, amount, status, created_at, updated_at) VALUES (${KID},'K-TAKE',60.00,'PENDING',DATE_SUB(NOW(),INTERVAL 10 MINUTE),DATE_SUB(NOW(),INTERVAL 10 MINUTE));"
assert_match "capture takeover succeeds" "$(run_cobol "CARD_CAPTURE|${KID}|${kauth4_ref}|||K-TAKE|${A}")" "SUCCESS\|CARD_CAPTURE\|60.0000"
assert_match "takeover taken over and done" "$(db_query "SELECT status FROM card_capture_request WHERE card_id=${KID} AND idempotency_key='K-TAKE';")" "^DONE$"

# 78-92. Keyed repay: same key replays instead of debiting twice; the
# ceiling still binds keyed calls; doomed and stale keys behave.
RP_BEFORE="$(db_query "SELECT COUNT(*) FROM ledger WHERE txn_ref LIKE 'CARDRP-%' AND account_id=${ACCTW};")"
assert_match "keyed repay ok" "$(run_cobol "CARD_REPAY|${KID}|100.00|||K-R1|${A}")" "SUCCESS\|CARD_REPAY\|100.0000"
assert_match "keyed repay replay ok" "$(run_cobol "CARD_REPAY|${KID}|100.00|||K-R1|${A}")" "SUCCESS\|CARD_REPAY\|100.0000"
assert_match "repay posted once" "$(db_query "SELECT COUNT(*) FROM ledger WHERE txn_ref LIKE 'CARDRP-%' AND account_id=${ACCTW};")" "^$((RP_BEFORE + 1))$"
assert_match "repay request recorded DONE" "$(db_query "SELECT status FROM card_repay_request WHERE card_id=${KID} AND idempotency_key='K-R1';")" "^DONE$"
db_exec "UPDATE card_repay_request SET amount = 1.00 WHERE card_id=${KID} AND idempotency_key='K-R1';"
assert_match "repay changed amount conflicts" "$(run_cobol "CARD_REPAY|${KID}|100.00|||K-R1|${A}")" "ERROR\|IDEMPOTENCY_CONFLICT"
db_exec "UPDATE card_repay_request SET amount = 100.00 WHERE card_id=${KID} AND idempotency_key='K-R1';"
J1="$(mktemp -d /tmp/cobol-test.XXXXXX)"; J2="$(mktemp -d /tmp/cobol-test.XXXXXX)"
printf 'CARD_REPAY|%s|150.00|||K-RRACE|admin@test.com\n' "$KID" >"$J1/input.txt"
printf 'CARD_REPAY|%s|150.00|||K-RRACE|admin@test.com\n' "$KID" >"$J2/input.txt"
(cd "$J1" && timeout 30s "$BIN" >/dev/null 2>&1) &
W1=$!
(cd "$J2" && timeout 30s "$BIN" >/dev/null 2>&1) &
W2=$!
wait $W1; wait $W2
JA="$(tr -d ' \n' <"$J1/output.txt")"; JB="$(tr -d ' \n' <"$J2/output.txt")"
rm -rf "$J1" "$J2"
assert_match "exactly one repay winner" "$(printf '%s\n%s\n' "$JA" "$JB" | grep -c "SUCCESS\|CARD_REPAY")" "^1$"
assert_match "repay loser refused" "$(printf '%s\n%s\n' "$JA" "$JB")" "ERROR\|"
assert_match "repay retry converges" "$(run_cobol "CARD_REPAY|${KID}|150.00|||K-RRACE|${A}")" "SUCCESS\|CARD_REPAY\|150.0000"
assert_match "over-ceiling keyed repay refused" "$(run_cobol "CARD_REPAY|${KID}|99999.00|||K-DOOMR|${A}")" "ERROR\|OVERPAID"
assert_match "over-ceiling retry in progress" "$(run_cobol "CARD_REPAY|${KID}|99999.00|||K-DOOMR|${A}")" "ERROR\|REPAY_IN_PROGRESS"
assert_match "doomed repay leaves pending" "$(db_query "SELECT status FROM card_repay_request WHERE card_id=${KID} AND idempotency_key='K-DOOMR';")" "^PENDING$"
db_exec "DELETE FROM card_repay_request WHERE card_id=${KID} AND idempotency_key='K-DOOMR';"
db_exec "INSERT INTO card_repay_request (card_id, idempotency_key, amount, status, created_at, updated_at) VALUES (${KID},'K-TAKER',75.00,'PENDING',DATE_SUB(NOW(),INTERVAL 10 MINUTE),DATE_SUB(NOW(),INTERVAL 10 MINUTE));"
assert_match "repay takeover succeeds" "$(run_cobol "CARD_REPAY|${KID}|75.00|||K-TAKER|${A}")" "SUCCESS\|CARD_REPAY\|75.0000"
assert_match "repay taken over and done" "$(db_query "SELECT status FROM card_repay_request WHERE card_id=${KID} AND idempotency_key='K-TAKER';")" "^DONE$"

# 93-104. Keyed reverse: replay, conflict, doomed key, takeover.
rauth="$(run_cobol "CARD_AUTHORIZE|${KID}|120.00|Shop KV|USD||${A}")"
rauth_ref="$(printf '%s' "$rauth" | awk -F'|' '{print $3}')"
run_cobol "CARD_CAPTURE|${KID}|${rauth_ref}||||${A}" >/dev/null
assert_match "keyed reverse ok" "$(run_cobol "CARD_REVERSE|${KID}|${rauth_ref}|||K-V1|${A}")" "SUCCESS\|CARD_REVERSE\|120.0000"
assert_match "keyed reverse replay ok" "$(run_cobol "CARD_REVERSE|${KID}|${rauth_ref}|||K-V1|${A}")" "SUCCESS\|CARD_REVERSE\|120.0000"
assert_match "refund posted once" "$(db_query "SELECT COUNT(*) FROM ledger WHERE txn_ref='CARDRC-${rauth_ref}';")" "^2$"
assert_match "reverse request recorded DONE" "$(db_query "SELECT status FROM card_reverse_request WHERE card_id=${KID} AND idempotency_key='K-V1';")" "^DONE$"
db_exec "UPDATE card_reverse_request SET amount = 1.00 WHERE card_id=${KID} AND idempotency_key='K-V1';"
assert_match "reverse changed amount conflicts" "$(run_cobol "CARD_REVERSE|${KID}|${rauth_ref}|||K-V1|${A}")" "ERROR\|IDEMPOTENCY_CONFLICT"
db_exec "UPDATE card_reverse_request SET amount = 120.00 WHERE card_id=${KID} AND idempotency_key='K-V1';"
assert_match "reverse on reversed refused" "$(run_cobol "CARD_REVERSE|${KID}|${rauth_ref}|||K-VDOOM|${A}")" "ERROR\|INVALID_STATUS"
assert_match "reverse doomed key not blocked" "$(run_cobol "CARD_REVERSE|${KID}|${rauth_ref}|||K-VDOOM|${A}")" "ERROR\|INVALID_STATUS"
assert_match "no reverse request residue" "$(db_query "SELECT COUNT(*) FROM card_reverse_request WHERE card_id=${KID} AND idempotency_key='K-VDOOM';")" "^0$"
rauth2="$(run_cobol "CARD_AUTHORIZE|${KID}|90.00|Shop KW|USD||${A}")"
rauth2_ref="$(printf '%s' "$rauth2" | awk -F'|' '{print $3}')"
run_cobol "CARD_CAPTURE|${KID}|${rauth2_ref}||||${A}" >/dev/null
db_exec "INSERT INTO card_reverse_request (card_id, idempotency_key, amount, status, created_at, updated_at) VALUES (${KID},'K-VTAKE',90.00,'PENDING',DATE_SUB(NOW(),INTERVAL 10 MINUTE),DATE_SUB(NOW(),INTERVAL 10 MINUTE));"
assert_match "reverse takeover succeeds" "$(run_cobol "CARD_REVERSE|${KID}|${rauth2_ref}|||K-VTAKE|${A}")" "SUCCESS\|CARD_REVERSE\|90.0000"
assert_match "reverse taken over and done" "$(db_query "SELECT status FROM card_reverse_request WHERE card_id=${KID} AND idempotency_key='K-VTAKE';")" "^DONE$"

# 90-96. Keyed reverse of an AUTHORIZED hold (void): no money moves, the
# hold is released, and the key still replays DONE instead of stranding
# PENDING behind a 5-minute window.
vauth="$(run_cobol "CARD_AUTHORIZE|${KID}|35.00|Shop KX|USD||${A}")"
vauth_ref="$(printf '%s' "$vauth" | awk -F'|' '{print $3}')"
assert_match "keyed void ok" "$(run_cobol "CARD_REVERSE|${KID}|${vauth_ref}|||K-VOID|${A}")" "SUCCESS\|CARD_REVERSE\|35.0000"
assert_match "keyed void replay ok" "$(run_cobol "CARD_REVERSE|${KID}|${vauth_ref}|||K-VOID|${A}")" "SUCCESS\|CARD_REVERSE\|35.0000"
assert_match "void posts no legs" "$(db_query "SELECT COUNT(*) FROM ledger WHERE txn_ref='CARDRC-${vauth_ref}';")" "^0$"
assert_match "void request recorded DONE" "$(db_query "SELECT status FROM card_reverse_request WHERE card_id=${KID} AND idempotency_key='K-VOID';")" "^DONE$"
assert_match "void on voided refused" "$(run_cobol "CARD_REVERSE|${KID}|${vauth_ref}|||K-VOID2|${A}")" "ERROR\|INVALID_STATUS"
assert_match "no void request residue" "$(db_query "SELECT COUNT(*) FROM card_reverse_request WHERE card_id=${KID} AND idempotency_key='K-VOID2';")" "^0$"

# 96-100. Concurrent authorizes against one limit (fresh card, limit
# 1000): two 700 holds serialize on the guarded debit; exactly one wins,
# the loser sees LIMIT_EXCEEDED (not DB_ERROR), the limit holds at 300,
# and a single AUTHORIZED row lands. The hold UPDATE runs before the
# auth-row INSERT so the FK S-lock never upgrades to a deadlock.
run_cobol "CARD_ISSUE|CRD-KR|${WA}|CREDIT|1000.00|USD|${A}" >/dev/null
RID="$(db_query "SELECT id FROM card_account WHERE card_ref='CRD-KR';")"
F1="$(mktemp -d /tmp/cobol-test.XXXXXX)"; F2="$(mktemp -d /tmp/cobol-test.XXXXXX)"
printf 'CARD_AUTHORIZE|%s|700.00|Shop R|USD||admin@test.com\n' "$RID" >"$F1/input.txt"
printf 'CARD_AUTHORIZE|%s|700.00|Shop R|USD||admin@test.com\n' "$RID" >"$F2/input.txt"
(cd "$F1" && timeout 30s "$BIN" >/dev/null 2>&1) &
U1=$!
(cd "$F2" && timeout 30s "$BIN" >/dev/null 2>&1) &
U2=$!
wait $U1; wait $U2
FA="$(tr -d ' \n' <"$F1/output.txt")"; FB="$(tr -d ' \n' <"$F2/output.txt")"
rm -rf "$F1" "$F2"
assert_match "exactly one authorize winner" "$(printf '%s\n%s\n' "$FA" "$FB" | grep -c "SUCCESS|CARD_AUTHORIZE")" "^1$"
assert_match "race loser limit-exceeded" "$(printf '%s\n%s\n' "$FA" "$FB")" "ERROR\|LIMIT_EXCEEDED"
assert_match "limit holds under race" "$(db_query "SELECT available_limit FROM card_account WHERE id=${RID};")" "^300.0000$"
assert_match "race authorized once" "$(db_query "SELECT COUNT(*) FROM card_transaction WHERE card_id=${RID} AND status='AUTHORIZED';")" "^1$"
db_exec "DELETE FROM card_transaction WHERE card_id=${RID};"
db_exec "DELETE FROM card_account WHERE id=${RID};"

cleanup_fixture
print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
