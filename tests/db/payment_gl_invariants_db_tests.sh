#!/usr/bin/env bash
# Payment/GL invariants (PR-042, batch commit 1): clearing lifecycle sums,
# journal balancedness, closed-period refusal, allocation once-only.
# Dedicated refs; far-future period owned (stays closed, harmless).
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
A="admin@test.com"
C="CLR-INV-1"
G="GLA-INV-1"
P="2099-01"
db_exec "DELETE FROM payment_clearing WHERE clearing_ref='${C}';"
db_exec "DELETE FROM gl_allocation_audit WHERE alloc_id IN (SELECT id FROM gl_allocation WHERE alloc_ref='${G}');"
db_exec "DELETE FROM gl_allocation WHERE alloc_ref='${G}';"

# 1. Clearing lifecycle: amounts conserved end to end.
assert_match "PMC_CREATE ok" "$(run_cobol "PMC_CREATE|${C}|250.00|USD|||${A}")" "SUCCESS\|PMC_CREATE"
assert_match "duplicate ref" "$(run_cobol "PMC_CREATE|${C}|1.00|USD|||${A}")" "ERROR\|DUPLICATE"
cid="$(db_query "SELECT id FROM payment_clearing WHERE clearing_ref='${C}';")"
assert_match "clearing row" "$cid" "^[0-9]+$"
assert_match "PMC_POST ok" "$(run_cobol "PMC_POST|${cid}|250.00||||${A}")" "SUCCESS\|PMC_POST"
assert_match "over-post refused" "$(run_cobol "PMC_POST|${cid}|999.00||||${A}")" "ERROR\|INVALID_AMOUNT"
assert_match "PMC_SETTLE ok" "$(run_cobol "PMC_SETTLE|${cid}|250.00||||${A}")" "SUCCESS\|PMC_SETTLE"
assert_match "sums conserved" "$(db_query "SELECT CONCAT(amount, '|', posted_amount, '|', settled_amount, '|', status) FROM payment_clearing WHERE id=${cid};")" "^250.0000|250.0000|250.0000|SETTLED$"
assert_match "cancel settled refused" "$(run_cobol "PMC_CANCEL|${cid}|||||${A}")" "ERROR\|INVALID_STATUS"

# 2. Journal balanced: ML post nets zero per journal; trial agrees.
# Dedicated far-future period (shared months like 2026-06 get closed by
# month-end jobs outside any suite; this one stays open and harmless).
PD="2099-02"
run_cobol "GL_PERIOD_OPEN|${PD}|||||${A}" >/dev/null
assert_match "ML post ok" "$(run_cobol "GL_JOURNAL_POST_ML|${PD}-01|pginv|USD|1000:25.00:0;1100:0:25.00||${A}")" "SUCCESS\|GL_POSTED"
jid="$(db_query "SELECT id FROM gl_journal ORDER BY id DESC LIMIT 1;")"
assert_match "journal balanced" "$(db_query "SELECT IF(SUM(debit_amount)=SUM(credit_amount),'BALANCED','UNBALANCED') FROM gl_journal_line WHERE journal_id=${jid};")" "^BALANCED$"
assert_match "unbalanced rejected" "$(run_cobol "GL_JOURNAL_POST_ML|${PD}-02|pginv|USD|1000:9.99:0||${A}")" "ERROR\|UNBALANCED"
assert_match "trial balanced" "$(run_cobol "GL_TRIAL_BALANCE|${PD}-01|${PD}-28|USD|||${A}")" "SUCCESS\|GL_TRIAL\|.*BALANCED"

# 3. Closed period refuses postings (stays closed across reruns: harmless,
# far-future period owned by this suite).
run_cobol "GL_PERIOD_OPEN|${P}|||||${A}" >/dev/null
assert_match "PERIOD_CLOSE verdict" "$(run_cobol "GL_PERIOD_CLOSE|${P}|||||${A}")" "SUCCESS\|GL_PERIOD_CLOSED|ERROR\|INVALID_STATUS"
assert_match "period closed" "$(db_query "SELECT status FROM gl_period WHERE period_code='${P}';")" "^CLOSED$"
assert_match "post into closed refused" "$(run_cobol "GL_JOURNAL_POST_ML|${P}-15|pginv|USD|1000:1.00:0;1100:0:1.00||${A}")" "ERROR\|PERIOD_CLOSED"

# 4. Allocation once-only: effect counted once, lifecycle closes.
assert_match "GLA_CREATE ok" "$(run_cobol "GLA_CREATE|${G}|ALLOC-SRC-9|1510|||${A}")" "SUCCESS\|GLA_CREATE"
gid="$(db_query "SELECT id FROM gl_allocation WHERE alloc_ref='${G}';")"
assert_match "GLA_ALLO ok" "$(run_cobol "GLA_ALLO|${gid}|||||${A}")" "SUCCESS\|GLA_ALLO"
assert_match "GLA_ALLO again" "$(run_cobol "GLA_ALLO|${gid}|||||${A}")" "SUCCESS\|GLA_ALLO"
assert_match "counted once" "$(db_query "SELECT allocated_amount FROM gl_allocation WHERE id=${gid};")" "^1.0000$"
assert_match "GLA_CLOSE ok" "$(run_cobol "GLA_CLOSE|${gid}|||||${A}")" "SUCCESS\|GLA_CLOSE"
assert_match "allocation closed" "$(db_query "SELECT status FROM gl_allocation WHERE id=${gid};")" "^CLOSED$"

db_exec "DELETE FROM payment_clearing WHERE clearing_ref='${C}';"
db_exec "DELETE FROM gl_allocation_audit WHERE alloc_id IN (SELECT id FROM gl_allocation WHERE alloc_ref='${G}');"
db_exec "DELETE FROM gl_allocation WHERE alloc_ref='${G}';"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
