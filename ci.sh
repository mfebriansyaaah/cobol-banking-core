#!/bin/bash
# One-shot CI: docs integrity -> static COBOL checks -> build -> both test suites.
# Usage: ./ci.sh

set -e

echo "=== [1/13] Docs integrity check ==="
./tests/docs_check.sh

echo "=== [2/13] Static COBOL checks ==="
viol=0

# Violation 1: sentence period inside an inline IF/ELSE scope.
# Paragraph headers (line that is nothing but an identifier ending in '.')
# reset the IF depth. Covers every module actually compiled by build.sh.
BUILT_COB="cobol/src/main_logic.cob cobol/src/user_core.cob cobol/src/wallet_core.cob cobol/src/auth_core.cob"
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

# Violation 2: GOBACK outside the entry paragraph of any built module
# (GOBACK inside a performed paragraph kills the whole program silently).
for f in $BUILT_COB; do
    if awk '
        /^[[:space:]]*[A-Z0-9][A-Z0-9-]*\.[[:space:]]*$/ {gsub(/[[:space:].]/,""); para=$0; next}
        /GOBACK/ && para != "MAIN-LOGIC" {
            print FILENAME ":" NR ": GOBACK inside paragraph " para
            found=1
        }
        END {exit found ? 1 : 0}' "$f"; then
        :
    else
        viol=1
    fi
done

# Violation 3: one routing literal is a prefix of another. Prefix matching makes
# that a silent mis-route (the CHECK_BALANCE vs GET_BALANCE class of bug).
if awk '
    /IF CMD-ACTION\(1:[0-9]+\) = "-?[A-Z_]+"|ELSE IF CMD-ACTION\(1:[0-9]+\) = "[A-Z_]+"/ {
        line=$0
        while (match(line, /= "[A-Z_]+"/)) {
            lit=substr(line, RSTART+3, RLENGTH-4)
            names[++n]=lit
            line=substr(line, RSTART+RLENGTH)
        }
    }
    END {
        for (i=1; i<=n; i++)
            for (j=1; j<=n; j++)
                if (i != j && index(names[j], names[i]) == 1) {
                    print "router: `" names[i] "` is a prefix of `" names[j] "`"
                    found=1
                }
        exit found ? 1 : 0
    }' cobol/src/main_logic.cob; then
    :
else
    viol=1
fi

if [ "$viol" = 1 ]; then
    echo "=== Static checks FAILED ==="
    exit 1
fi
echo "OK"

echo "=== [3/13] Build ==="
build_log=$(./build.sh 2>&1 || true)
echo "$build_log" | grep -E "^cobol.*error:" && { echo "BUILD FAILED"; exit 1; }
echo "$build_log" | grep -q "SUCCESS: Binary created" || { echo "BUILD FAILED"; exit 1; }
echo "Build OK"

echo "=== [4/13] Functional suite ==="
func_out=$(./tests/test_suite.sh 2>/dev/null)
echo "$func_out" | tail -1
func_fail=$(echo "$func_out" | grep -oE '[0-9]+ failed' | grep -oE '[0-9]+' | head -1 || echo 0)
func_fail=${func_fail:-0}
[ "$func_fail" -eq 0 ] || { echo "FUNCTIONAL SUITE FAILED"; exit 1; }

echo "=== [5/13] Atomic transaction suite ==="
atomic_out=$(./tests/test_atomic_txn.sh 2>/dev/null)
atomic_pass=$(echo "$atomic_out" | grep -c '\[0;32mPASS' || true)
atomic_fail=$(echo "$atomic_out" | grep -c '\[0;31mFAIL' || true)
echo "atomic: $atomic_pass passed, $atomic_fail failed"
[ "$atomic_fail" -eq 0 ] || { echo "ATOMIC SUITE FAILED"; exit 1; }

echo "=== [6/13] Ledger atomic suite ==="
ledger_out=$(./tests/test_ledger_atomic.sh 2>/dev/null)
ledger_pass=$(echo "$ledger_out" | grep -c '\[0;32mPASS' || true)
ledger_fail=$(echo "$ledger_out" | grep -c '\[0;31mFAIL' || true)
echo "ledger: $ledger_pass passed, $ledger_fail failed"
[ "$ledger_fail" -eq 0 ] || { echo "LEDGER SUITE FAILED"; exit 1; }

echo "=== [7/13] Reconciliation suite ==="
recon_out=$(./tests/test_reconciliation.sh 2>/dev/null)
recon_pass=$(echo "$recon_out" | grep -c '\[0;32mPASS' || true)
recon_fail=$(echo "$recon_out" | grep -c '\[0;31mFAIL' || true)
echo "reconciliation: $recon_pass passed, $recon_fail failed"
[ "$recon_fail" -eq 0 ] || { echo "RECONCILIATION SUITE FAILED"; exit 1; }

echo "=== [8/13] Auth login suite ==="
auth_out=$(./tests/test_auth_login.sh 2>/dev/null)
auth_pass=$(echo "$auth_out" | grep -c '\[0;32mPASS' || true)
auth_fail=$(echo "$auth_out" | grep -c '\[0;31mFAIL' || true)
echo "auth: $auth_pass passed, $auth_fail failed"
[ "$auth_fail" -eq 0 ] || { echo "AUTH SUITE FAILED"; exit 1; }

echo "=== [9/13] Signup + verify suite ==="
signup_out=$(./tests/test_signup_verify.sh 2>/dev/null)
signup_pass=$(echo "$signup_out" | grep -c '\[0;32mPASS' || true)
signup_fail=$(echo "$signup_out" | grep -c '\[0;31mFAIL' || true)
echo "signup/verify: $signup_pass passed, $signup_fail failed"
[ "$signup_fail" -eq 0 ] || { echo "SIGNUP SUITE FAILED"; exit 1; }

echo "=== [10/13] Role suite ==="
role_out=$(./tests/test_roles.sh 2>/dev/null)
role_pass=$(echo "$role_out" | grep -c '\[0;32mPASS' || true)
role_fail=$(echo "$role_out" | grep -c '\[0;31mFAIL' || true)
echo "roles: $role_pass passed, $role_fail failed"
[ "$role_fail" -eq 0 ] || { echo "ROLE SUITE FAILED"; exit 1; }

echo "=== [11/13] User profile suite ==="
profile_out=$(./tests/test_user_profile.sh 2>/dev/null)
profile_pass=$(echo "$profile_out" | grep -c '\[0;32mPASS' || true)
profile_fail=$(echo "$profile_out" | grep -c '\[0;31mFAIL' || true)
echo "profile: $profile_pass passed, $profile_fail failed"
[ "$profile_fail" -eq 0 ] || { echo "PROFILE SUITE FAILED"; exit 1; }

echo "=== [12/13] API gateway suite ==="
if [ -d middleware ]; then
    npm --prefix middleware ci --silent >/dev/null 2>&1 || npm --prefix middleware install --silent >/dev/null 2>&1
    if npm --prefix middleware test --silent >/tmp/opencode/gateway.out 2>&1; then
        gw_pass=$(grep -cE '^✔|^ℹ pass' /tmp/opencode/gateway.out || true)
        echo "gateway: $(grep -E '^ℹ pass|^ℹ fail' /tmp/opencode/gateway.out | tr '\n' ' ')"
        echo "Gateway OK"
    else
        echo "GATEWAY SUITE FAILED"
        tail -20 /tmp/opencode/gateway.out
        exit 1
    fi
else
    echo "middleware/ absent; skipping"
fi

echo "=== [13/13] Login lockout suite ==="
lockout_out=$(./tests/test_login_lockout.sh 2>/dev/null)
lockout_pass=$(echo "$lockout_out" | grep -c '\[0;32mPASS' || true)
lockout_fail=$(echo "$lockout_out" | grep -c '\[0;31mFAIL' || true)
echo "lockout: $lockout_pass passed, $lockout_fail failed"
[ "$lockout_fail" -eq 0 ] || { echo "LOCKOUT SUITE FAILED"; exit 1; }

echo "=== ALL GREEN ==="
