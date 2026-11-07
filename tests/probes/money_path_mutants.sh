#!/usr/bin/env bash
# PR-043 mutation probe: money-path guards, one mutant at a time.
# Each mutant neuters a single guard, rebuilds, runs the mapped suite(s),
# and MUST fail (>=1 test) to prove the suite guards the invariant.
# Restores + rebuilds after every mutant (trap-safe); the tree is left
# byte-identical (verified with git diff at the end).
#
# M9 (version check) is deliberately absent: TXM_UPDATE/LSC_UPDATE carry no
# caller version in contract (deprecated path) and bind the DB-loaded
# version, so there is no working check to remove. Evidence: probe67
# (stale version accepted, 1->2->3). A real optimistic-locking contract
# belongs to a design PR, not a mutant.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT" || exit 1

PATCHED=()
restore_all() {
    local f
    for f in "${PATCHED[@]}"; do
        if [ -f "$f.mutantbak" ]; then
            mv -f "$f.mutantbak" "$f"
        fi
    done
    PATCHED=()
}
trap restore_all EXIT INT TERM

mutate() { # $1=file $2=python-patch-stdin expected-count
    local file="$1"
    if [ ! -f "$file.mutantbak" ]; then
        cp "$file" "$file.mutantbak"
        PATCHED+=("$file")
    fi
}

PASS=0; FAIL=0
run_mutant() { # $1=id $2=desc $3=suites...
    local id="$1" desc="$2"
    shift 2
    echo "=== MUTANT $id: $desc ==="
    if ! ./build.sh >/tmp/mutant_build.log 2>&1; then
        echo "MUTANT $id: BUILD BROKEN (mutant does not compile — harness bug, not a suite gap)"
        tail -5 /tmp/mutant_build.log
        exit 1
    fi
    local s failed=0
    for s in "$@"; do
        if bash "$s" >/tmp/mutant_suite.log 2>&1; then
            : # suite passed despite mutant
        else
            failed=1
        fi
    done
    if [ "$failed" = "1" ]; then
        echo "MUTANT $id: KILLED (suite failed as required)"
        PASS=$((PASS + 1))
    else
        echo "MUTANT $id: SURVIVED (no test caught it) <-- INVESTIGATE"
        FAIL=$((FAIL + 1))
    fi
}

py_patch() {
    python3 - "$@" <<'PYEOF'
import sys
path, old, new, expect = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4])
src = open(path).read()
n = src.count(old)
assert n == expect, f'{path}: anchor x{n}, expected x{expect}'
open(path, 'w').write(src.replace(old, new))
print(f'patched {path}')
PYEOF
}

W=cobol/src/wallet_core.cob
G=cobol/src/gl_core.cob
WR=cobol/src/wallet_reversal_core.cob
WH=cobol/src/wallet_hold_core.cob

# M1: drop TRANSFER balance check.
mutate "$W"
py_patch "$W" \
'                IF WS-BALANCE-NUM < WS-AMOUNT-NUM + WS-FEE-NUM
                    SET WS-TRANSFER-FAIL-INSUF TO TRUE' \
'                IF WS-BALANCE-NUM < WS-AMOUNT-NUM + WS-FEE-NUM
                    CONTINUE *>MUTANT M1 no-op (was SET FAIL-INSUF)' 1
run_mutant "M1" "no balance check" tests/db/wallet_invariants_db_tests.sh
restore_all

# M2: drop BOTH idempotency flags (replay branch + intent-insert error
# branch): without either, a duplicate key proceeds as a new transfer.
mutate "$W"
py_patch "$W" \
'                    CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                    IF WS-RESULT(1:5) = "ERROR"
                        SET WS-TRANSFER-FAIL-IDEMP TO TRUE' \
'                    CALL "GET_RESULT" USING BY REFERENCE WS-RESULT END-CALL
                    IF WS-RESULT(1:5) = "ERROR"
                        CONTINUE *>MUTANT M2 no-op (was SET FAIL-IDEMP)' 1
py_patch "$W" \
'                            ELSE
                                SET WS-TRANSFER-FAIL-IDEMP TO TRUE
                            END-IF' \
'                            ELSE
                                CONTINUE *>MUTANT M2 no-op (was SET FAIL-IDEMP)' 1
run_mutant "M2" "no idempotency flags (both sites)" tests/db/wallet_invariants_db_tests.sh
restore_all

# M3: drop already-reversed early exit (double reversal succeeds).
mutate "$WR"
py_patch "$WR" \
'            ELSE
                MOVE "ERROR|ALREADY_REVERSED" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF' \
'            ELSE
                MOVE "ERROR|ALREADY_REVERSED" TO LS-OUTPUT-BUFFER
                CONTINUE *>MUTANT M3 no-op (was EXIT: re-executes reversal)
            END-IF' 1
run_mutant "M3" "no already-reversed exit" tests/db/wallet_invariants_db_tests.sh
restore_all

# M4: drop sender frozen check.
mutate "$W"
py_patch "$W" \
'                IF WS-SENDER-STATUS NOT = "ACTIVE"
                    IF WS-SENDER-STATUS(1:6) = "FROZEN"
                        SET WS-TRANSFER-FAIL-FROZEN TO TRUE' \
'                IF WS-SENDER-STATUS NOT = "ACTIVE"
                    IF WS-SENDER-STATUS(1:6) = "FROZEN"
                        CONTINUE *>MUTANT M4 no-op (was SET FAIL-FROZEN)' 1
run_mutant "M4" "no frozen check" tests/db/wallet_invariants_db_tests.sh
restore_all

# M5: drop missing-rate check.
mutate "$W"
py_patch "$W" \
'                        IF WS-RESULT = "ERROR|NO_DATA"
                            SET WS-TRANSFER-FAIL-CURR TO TRUE' \
'                        IF WS-RESULT = "ERROR|NO_DATA"
                            CONTINUE *>MUTANT M5 no-op (was SET FAIL-CURR)' 1
run_mutant "M5" "no currency-rate check" tests/db/wallet_invariants_db_tests.sh
restore_all

# M6: swap transfer leg directions (journal must go unbalanced).
mutate "$W"
python3 - "$W" <<'PYEOF'
import sys
path = sys.argv[1]
src = open(path).read()
a = ' WS-SENDER-PREC(1:1) "), '"'"'DEBIT'"'"''
b = ' WS-TARGET-PREC(1:1) "), '"'"'CREDIT'"'"''
assert src.count(a) == 1 and src.count(b) == 1, 'M6 anchors not unique'
src = src.replace(a, ' WS-SENDER-PREC(1:1) "), '"'"'CREDIT'"'"'')
src = src.replace(b, ' WS-TARGET-PREC(1:1) "), '"'"'DEBIT'"'"'')
open(path, 'w').write(src)
print('patched M6 leg swap')
PYEOF
run_mutant "M6" "swapped debit/credit legs" tests/db/wallet_invariants_db_tests.sh
restore_all

# M7: drop ML journal-balance refusal.
mutate "$G"
py_patch "$G" \
'                   IF WS-BALANCE NOT = "BALANCED"
                       MOVE "ERROR|UNBALANCED" TO WS-ERR
                       SET STEP-FAIL TO TRUE' \
'                   IF WS-BALANCE NOT = "BALANCED"
                       CONTINUE *>MUTANT M7 no-op (was UNBALANCED refusal)' 1
run_mutant "M7" "no ML balance refusal" tests/db/payment_gl_invariants_db_tests.sh
restore_all

# M8: audit lands under a wrong action (transfer succeeds, presence test must catch it).
mutate "$W"
py_patch "$W" \
'VALUES (?, '"'"'TRANSFER'"'"', '"'"'ACCOUNT'"'"', ?, '"'"'SUCCESS'"'"', ?, @jid)" TO WS-PREP-SQL' \
'VALUES (?, '"'"'TRANSFER_MUTED'"'"', '"'"'ACCOUNT'"'"', ?, '"'"'SUCCESS'"'"', ?, @jid)" TO WS-PREP-SQL' 1
run_mutant "M8" "mislabelled transfer audit" tests/db/wallet_invariants_db_tests.sh
restore_all

# M10: drop hold-release state update.
mutate "$WH"
py_patch "$WH" \
'            MOVE "UPDATE account_holds SET state = '"'"'RELEASED'"'"' WHERE hold_id = ?" TO WS-PREP-SQL' \
'      *>MUTANT M10*             MOVE "UPDATE account_holds SET state = '"'"'RELEASED'"'"' WHERE hold_id = ?" TO WS-PREP-SQL' 1
run_mutant "M10" "no hold release" tests/db/admin_shell_db_tests.sh
restore_all

# JS mutants (gateway hooks): no COBOL rebuild needed; the mapped node suite
# must fail. Residue check at the end covers middleware/ too.
run_js_mutant() { # $1=id $2=desc $3=node-test-file...
    local id="$1" desc="$2"
    shift 2
    echo "=== MUTANT $id: $desc ==="
    local failed=0
    local s
    for s in "$@"; do
        if ( cd middleware && node --import ./preload.mjs --test --test-reporter=dot "$s" >/tmp/mutant_js.log 2>&1 ); then
            : # suite passed despite mutant
        else
            failed=1
        fi
    done
    if [ "$failed" = "1" ]; then
        echo "MUTANT $id: KILLED (suite failed as required)"
        PASS=$((PASS + 1))
    else
        echo "MUTANT $id: SURVIVED (no test caught it) <-- INVESTIGATE"
        FAIL=$((FAIL + 1))
    fi
}

I=middleware/src/app.js
C=cobol/src/sql_bridge.c
IDV=cobol/src/identity_core.cob

# M11: drop the TRANSFER KYC gate (large transfers flow unverified).
mutate "$W"
py_patch "$W" \
'                IF WS-RESULT NOT = "APPROVED"
                    MOVE "ERROR|KYC_REQUIRED" TO LS-OUTPUT-BUFFER
                    EXIT PARAGRAPH
                END-IF' \
'                IF WS-RESULT NOT = "APPROVED"
                    CONTINUE *>MUTANT M11 no-op (was KYC_REQUIRED refusal)' 1
run_mutant "M11" "no transfer KYC gate" tests/db/kyc_enforcement_db_tests.sh
restore_all

# M12: screening gate always passes (APPROVED without CLEAR).
mutate "$IDV"
py_patch "$IDV" \
'            IF WS-HAS-SCREENING = "N"
                MOVE "SUCCESS|KYC_PENDING|SCREENING" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF' \
'            IF WS-HAS-SCREENING = "N"
                CONTINUE *>MUTANT M12 no-op (was SCREENING gate)' 1
run_mutant "M12" "no screening gate" tests/db/screening_db_tests.sh
restore_all

# M13: review list needs no admin (stranger enumerates the queue). The
# FORBIDDEN branch becomes a no-op (structure kept so it still compiles).
mutate "$IDV"
py_patch "$IDV" \
'            PERFORM CHECK-ADMIN
            IF WS-ALLOWED NOT = 1
                MOVE "ERROR|FORBIDDEN" TO LS-OUTPUT-BUFFER
                EXIT PARAGRAPH
            END-IF.
            IF LS-PARAM2 = SPACES' \
'            PERFORM CHECK-ADMIN
            IF WS-ALLOWED NOT = 1
                CONTINUE *>MUTANT M13 no-op (was FORBIDDEN refusal)
            END-IF.
            IF LS-PARAM2 = SPACES' 1
run_mutant "M13" "no review-list auth" tests/db/screening_db_tests.sh
restore_all

# M14: pwned hook always allows (breached password signs up).
mutate "$I"
py_patch "$I" \
'          const allowed = await assertPasswordAllowed(candidate);' \
'          const allowed = true; // MUTANT M14 (was assertPasswordAllowed)' 1
run_js_mutant "M14" "no breached-password gate" test/integrations/pwned.test.js
restore_all

# M15: captcha hook skipped (bot signs up freely).
mutate "$I"
py_patch "$I" \
'        if (route.captcha) {' \
'        if (false) { // MUTANT M15 (was route.captcha)' 1
run_js_mutant "M15" "no captcha gate" test/integrations/bot.test.js
restore_all

# M16: silent truncation returns (no RESULT_TRUNCATED marker, both sites).
mutate "$C"
py_patch "$C" \
'        if (g_truncated) strncpy(G_RESULT, "ERROR|RESULT_TRUNCATED", RES_CAP);' \
'        if (g_truncated) {} // MUTANT M16: swallow (was RESULT_TRUNCATED)' 1
py_patch "$C" \
'    if (g_truncated) {
        strncpy(G_RESULT, "ERROR|RESULT_TRUNCATED", RES_CAP);
    } else if (first_row) {' \
'    if (g_truncated) {} // MUTANT M16: swallow (was RESULT_TRUNCATED)
    else if (first_row) {' 1
run_mutant "M16" "silent truncation" tests/db/truncation_db_tests.sh
restore_all

echo "=== rebuilding pristine tree ==="
./build.sh >/tmp/mutant_rebuild.log 2>&1 || { echo "FINAL REBUILD FAILED"; tail -5 /tmp/mutant_rebuild.log; exit 1; }
if git diff --quiet -- cobol/ middleware/; then
    echo "tree clean (no mutant residue)"
else
    echo "RESIDUE IN TREE:"; git diff --stat -- cobol/ middleware/; exit 1
fi
echo "=== MUTANTS: $PASS killed, $FAIL survived ==="
[ "$FAIL" -eq 0 ]
