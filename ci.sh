#!/bin/bash
# One-shot CI: docs integrity -> static COBOL checks -> build -> both test suites.
# Usage: ./ci.sh

set -e

echo "=== [1/11] Docs integrity check ==="
./tests/docs_check.sh

echo "=== [2/11] Static COBOL checks ==="
viol=0

# Violation 1: sentence period inside an inline IF/ELSE scope.
# Paragraph headers (line that is nothing but an identifier ending in '.')
# reset the IF depth. Only checks files that are actually compiled by build.sh.
BUILT_COB="cobol/src/main_logic.cob cobol/src/user_core.cob cobol/src/wallet_core.cob"
for f in $BUILT_COB; do
    awk '
        /^[[:space:]]*[A-Z0-9][A-Z0-9-]*\.[[:space:]]*$/ {ifdepth=0; next}
        /^[[:space:]]*\*>/ {next}
        /^[[:space:]]*IF[[:space:]]/ {ifdepth++}
        /^[[:space:]]*END-IF\./ {ifdepth--; if(ifdepth<0) ifdepth=0}
        {line=$0; sub(/[[:space:]]+$/, "", line)}
        ifdepth>0 && line ~ /[.][[:space:]]*$/ && line !~ /END-IF\.|END-STRING\.|END-EVALUATE\.|END-UNSTRING\.|END-PERFORM\.|END-READ\./ {
            print FILENAME ":" NR ": period inside inline IF scope: " line
            found=1
        }
    END {exit found ? 1 : 0}' "$f" || viol=1
done

# Violation 2: GOBACK inside performed helper paragraphs of wallet_core
# (GOBACK there kills the whole program silently at runtime).
if awk '
    /^[[:space:]]*[A-Z0-9][A-Z0-9-]*\.[[:space:]]*$/ {gsub(/[[:space:].]/,""); para=$0; next}
    para ~ /^(TRIM-PARAM1|TRIM-PARAM2|TRIM-PARAM3|GET-BALANCE-LOGIC|TRANSFER-LOGIC)$/ && /GOBACK/ {
        print FILENAME ":" NR ": GOBACK inside performed paragraph " para
        found=1
    }
    END {exit found ? 1 : 0}' cobol/src/wallet_core.cob; then
    :
else
    viol=1
fi

if [ "$viol" = 1 ]; then
    echo "=== Static checks FAILED ==="
    exit 1
fi
echo "OK"

echo "=== [3/11] Build ==="
build_log=$(./build.sh 2>&1 || true)
echo "$build_log" | grep -E "^cobol.*error:" && { echo "BUILD FAILED"; exit 1; }
echo "$build_log" | grep -q "SUCCESS: Binary created" || { echo "BUILD FAILED"; exit 1; }
echo "Build OK"

echo "=== [4/11] Functional suite ==="
func_out=$(./tests/test_suite.sh 2>/dev/null)
echo "$func_out" | tail -1
func_fail=$(echo "$func_out" | grep -oE '[0-9]+ failed' | grep -oE '[0-9]+' | head -1 || echo 0)
func_fail=${func_fail:-0}
[ "$func_fail" -eq 0 ] || { echo "FUNCTIONAL SUITE FAILED"; exit 1; }

echo "=== [5/11] Atomic transaction suite ==="
atomic_out=$(./tests/test_atomic_txn.sh 2>/dev/null)
atomic_pass=$(echo "$atomic_out" | grep -c '\[0;32mPASS' || true)
atomic_fail=$(echo "$atomic_out" | grep -c '\[0;31mFAIL' || true)
echo "atomic: $atomic_pass passed, $atomic_fail failed"
[ "$atomic_fail" -eq 0 ] || { echo "ATOMIC SUITE FAILED"; exit 1; }

echo "=== [6/11] Ledger atomic suite ==="
ledger_out=$(./tests/test_ledger_atomic.sh 2>/dev/null)
ledger_pass=$(echo "$ledger_out" | grep -c '\[0;32mPASS' || true)
ledger_fail=$(echo "$ledger_out" | grep -c '\[0;31mFAIL' || true)
echo "ledger: $ledger_pass passed, $ledger_fail failed"
[ "$ledger_fail" -eq 0 ] || { echo "LEDGER SUITE FAILED"; exit 1; }

echo "=== [7/11] Reconciliation suite ==="
recon_out=$(./tests/test_reconciliation.sh 2>/dev/null)
recon_pass=$(echo "$recon_out" | grep -c '\[0;32mPASS' || true)
recon_fail=$(echo "$recon_out" | grep -c '\[0;31mFAIL' || true)
echo "reconciliation: $recon_pass passed, $recon_fail failed"
[ "$recon_fail" -eq 0 ] || { echo "RECONCILIATION SUITE FAILED"; exit 1; }

echo "=== [8/11] Auth login suite ==="
auth_out=$(./tests/test_auth_login.sh 2>/dev/null)
auth_pass=$(echo "$auth_out" | grep -c '\[0;32mPASS' || true)
auth_fail=$(echo "$auth_out" | grep -c '\[0;31mFAIL' || true)
echo "auth: $auth_pass passed, $auth_fail failed"
[ "$auth_fail" -eq 0 ] || { echo "AUTH SUITE FAILED"; exit 1; }

echo "=== [9/11] Signup + verify suite ==="
signup_out=$(./tests/test_signup_verify.sh 2>/dev/null)
signup_pass=$(echo "$signup_out" | grep -c '\[0;32mPASS' || true)
signup_fail=$(echo "$signup_out" | grep -c '\[0;31mFAIL' || true)
echo "signup/verify: $signup_pass passed, $signup_fail failed"
[ "$signup_fail" -eq 0 ] || { echo "SIGNUP SUITE FAILED"; exit 1; }

echo "=== [10/11] Role suite ==="
role_out=$(./tests/test_roles.sh 2>/dev/null)
role_pass=$(echo "$role_out" | grep -c '\[0;32mPASS' || true)
role_fail=$(echo "$role_out" | grep -c '\[0;31mFAIL' || true)
echo "roles: $role_pass passed, $role_fail failed"
[ "$role_fail" -eq 0 ] || { echo "ROLE SUITE FAILED"; exit 1; }

echo "=== [11/11] User profile suite ==="
profile_out=$(./tests/test_user_profile.sh 2>/dev/null)
profile_pass=$(echo "$profile_out" | grep -c '\[0;32mPASS' || true)
profile_fail=$(echo "$profile_out" | grep -c '\[0;31mFAIL' || true)
echo "profile: $profile_pass passed, $profile_fail failed"
[ "$profile_fail" -eq 0 ] || { echo "PROFILE SUITE FAILED"; exit 1; }

echo "=== ALL GREEN ==="
