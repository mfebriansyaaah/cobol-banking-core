#!/bin/bash
# One-shot CI: docs integrity -> static COBOL checks -> build -> both test suites.
# Usage: ./ci.sh

set -e

echo "=== [1/25] Docs integrity check ==="
./tests/docs_check.sh

echo "=== [2/25] Static COBOL checks ==="
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

# Violation 4: every action the router dispatches must have a handler in the
# owning module (router/owner agreement - the routing contract in AGENTS.md).
for name in $(grep -oE 'CMD-ACTION\(1:[0-9]+\) = "[A-Z_]+"' cobol/src/main_logic.cob | grep -oE '"[A-Z_]+"' | tr -d '"'); do
    if ! grep -q "\"$name\"" cobol/src/wallet_core.cob cobol/src/user_core.cob cobol/src/auth_core.cob; then
        echo "router: action '$name' has no handler in any core module"
        viol=1
    fi
done

# Violation 5: any FK to the mutable users(email) must cascade on UPDATE,
# otherwise changing a user's email fails with errno 1451 (migration 0003).
if grep -n "REFERENCES users(email)" database/schema.sql | grep -v "ON UPDATE CASCADE" | grep -q .; then
    echo "schema: FK to users(email) missing ON UPDATE CASCADE:"
    grep -n "REFERENCES users(email)" database/schema.sql | grep -v "ON UPDATE CASCADE"
    viol=1
fi

# Violation 6: every action the router can dispatch must be reachable through the
# gateway, either as a route (action: 'X') or via an internal invoke('X')
# (PING, session store). Otherwise the feature is unreachable over HTTP.
for name in $(grep -oE 'CMD-ACTION\(1:[0-9]+\) = "[A-Z_]+"' cobol/src/main_logic.cob | grep -oE '"[A-Z_]+"' | tr -d '"'); do
    if ! grep -rqE "(action: '$name'|invoke\('$name')" middleware/src; then
        echo "gateway: action '$name' is routed but has no endpoint or internal invoke"
        viol=1
    fi
done

if [ "$viol" = 1 ]; then
    echo "=== Static checks FAILED ==="
    exit 1
fi
echo "OK"

echo "=== [3/25] Build ==="
build_log=$(./build.sh 2>&1 || true)
echo "$build_log" | grep -E "^cobol.*error:" && { echo "BUILD FAILED"; exit 1; }
echo "$build_log" | grep -q "SUCCESS: Binary created" || { echo "BUILD FAILED"; exit 1; }
echo "Build OK"

echo "=== [4/25] Functional suite ==="
func_out=$(./tests/test_suite.sh 2>/dev/null)
echo "$func_out" | tail -1
func_fail=$(echo "$func_out" | grep -oE '[0-9]+ failed' | grep -oE '[0-9]+' | head -1 || echo 0)
func_fail=${func_fail:-0}
[ "$func_fail" -eq 0 ] || { echo "FUNCTIONAL SUITE FAILED"; exit 1; }

echo "=== [5/25] Atomic transaction suite ==="
atomic_out=$(./tests/test_atomic_txn.sh 2>/dev/null)
atomic_pass=$(echo "$atomic_out" | grep -c '\[0;32mPASS' || true)
atomic_fail=$(echo "$atomic_out" | grep -c '\[0;31mFAIL' || true)
echo "atomic: $atomic_pass passed, $atomic_fail failed"
[ "$atomic_fail" -eq 0 ] || { echo "ATOMIC SUITE FAILED"; exit 1; }

echo "=== [6/25] Ledger atomic suite ==="
ledger_out=$(./tests/test_ledger_atomic.sh 2>/dev/null)
ledger_pass=$(echo "$ledger_out" | grep -c '\[0;32mPASS' || true)
ledger_fail=$(echo "$ledger_out" | grep -c '\[0;31mFAIL' || true)
echo "ledger: $ledger_pass passed, $ledger_fail failed"
[ "$ledger_fail" -eq 0 ] || { echo "LEDGER SUITE FAILED"; exit 1; }

echo "=== [7/25] Reconciliation suite ==="
recon_out=$(./tests/test_reconciliation.sh 2>/dev/null)
recon_pass=$(echo "$recon_out" | grep -c '\[0;32mPASS' || true)
recon_fail=$(echo "$recon_out" | grep -c '\[0;31mFAIL' || true)
echo "reconciliation: $recon_pass passed, $recon_fail failed"
[ "$recon_fail" -eq 0 ] || { echo "RECONCILIATION SUITE FAILED"; exit 1; }

echo "=== [8/25] Auth login suite ==="
auth_out=$(./tests/test_auth_login.sh 2>/dev/null)
auth_pass=$(echo "$auth_out" | grep -c '\[0;32mPASS' || true)
auth_fail=$(echo "$auth_out" | grep -c '\[0;31mFAIL' || true)
echo "auth: $auth_pass passed, $auth_fail failed"
[ "$auth_fail" -eq 0 ] || { echo "AUTH SUITE FAILED"; exit 1; }

echo "=== [9/25] Signup + verify suite ==="
signup_out=$(./tests/test_signup_verify.sh 2>/dev/null)
signup_pass=$(echo "$signup_out" | grep -c '\[0;32mPASS' || true)
signup_fail=$(echo "$signup_out" | grep -c '\[0;31mFAIL' || true)
echo "signup/verify: $signup_pass passed, $signup_fail failed"
[ "$signup_fail" -eq 0 ] || { echo "SIGNUP SUITE FAILED"; exit 1; }

echo "=== [10/25] Role suite ==="
role_out=$(./tests/test_roles.sh 2>/dev/null)
role_pass=$(echo "$role_out" | grep -c '\[0;32mPASS' || true)
role_fail=$(echo "$role_out" | grep -c '\[0;31mFAIL' || true)
echo "roles: $role_pass passed, $role_fail failed"
[ "$role_fail" -eq 0 ] || { echo "ROLE SUITE FAILED"; exit 1; }

echo "=== [11/25] User profile suite ==="
profile_out=$(./tests/test_user_profile.sh 2>/dev/null)
profile_pass=$(echo "$profile_out" | grep -c '\[0;32mPASS' || true)
profile_fail=$(echo "$profile_out" | grep -c '\[0;31mFAIL' || true)
echo "profile: $profile_pass passed, $profile_fail failed"
[ "$profile_fail" -eq 0 ] || { echo "PROFILE SUITE FAILED"; exit 1; }

echo "=== [12/25] API gateway suite ==="
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

echo "=== [13/25] Login lockout suite ==="
lockout_out=$(./tests/test_login_lockout.sh 2>/dev/null)
lockout_pass=$(echo "$lockout_out" | grep -c '\[0;32mPASS' || true)
lockout_fail=$(echo "$lockout_out" | grep -c '\[0;31mFAIL' || true)
echo "lockout: $lockout_pass passed, $lockout_fail failed"
[ "$lockout_fail" -eq 0 ] || { echo "LOCKOUT SUITE FAILED"; exit 1; }

echo "=== [14/25] Idempotent transfer suite ==="
idem_out=$(./tests/test_idempotent_transfer.sh 2>/dev/null)
idem_pass=$(echo "$idem_out" | grep -c '\[0;32mPASS' || true)
idem_fail=$(echo "$idem_out" | grep -c '\[0;31mFAIL' || true)
echo "idempotent transfer: $idem_pass passed, $idem_fail failed"
[ "$idem_fail" -eq 0 ] || { echo "IDEMPOTENT SUITE FAILED"; exit 1; }

echo "=== [15/25] Transfer validity suite ==="
validity_out=$(./tests/test_transfer_validity.sh 2>/dev/null)
validity_pass=$(echo "$validity_out" | grep -c '\[0;32mPASS' || true)
validity_fail=$(echo "$validity_out" | grep -c '\[0;31mFAIL' || true)
echo "transfer validity: $validity_pass passed, $validity_fail failed"
[ "$validity_fail" -eq 0 ] || { echo "TRANSFER VALIDITY SUITE FAILED"; exit 1; }

echo "=== [16/25] Concurrent opposing transfers ==="
conc_out=$(./tests/test_concurrent_transfer.sh 2>/dev/null)
conc_pass=$(echo "$conc_out" | grep -c '\[0;32mPASS' || true)
conc_fail=$(echo "$conc_out" | grep -c '\[0;31mFAIL' || true)
echo "concurrent transfer: $conc_pass passed, $conc_fail failed"
[ "$conc_fail" -eq 0 ] || { echo "CONCURRENT SUITE FAILED"; exit 1; }

echo "=== [17/25] SQL injection mitigation suite ==="
inj_out=$(./tests/test_injection.sh 2>/dev/null)
inj_pass=$(echo "$inj_out" | grep -c '\[0;32mPASS' || true)
inj_fail=$(echo "$inj_out" | grep -c '\[0;31mFAIL' || true)
echo "injection: $inj_pass passed, $inj_fail failed"
[ "$inj_fail" -eq 0 ] || { echo "INJECTION SUITE FAILED"; exit 1; }

echo "=== [18/25] Refresh session suite ==="
sess_out=$(./tests/test_session.sh 2>/dev/null)
sess_pass=$(echo "$sess_out" | grep -c '\[0;32mPASS' || true)
sess_fail=$(echo "$sess_out" | grep -c '\[0;31mFAIL' || true)
echo "session: $sess_pass passed, $sess_fail failed"
[ "$sess_fail" -eq 0 ] || { echo "SESSION SUITE FAILED"; exit 1; }

echo "=== [19/25] Prepared statement suite ==="
prep_out=$(./tests/test_prepared.sh 2>/dev/null)
prep_pass=$(echo "$prep_out" | grep -c '\[0;32mPASS' || true)
prep_fail=$(echo "$prep_out" | grep -c '\[0;31mFAIL' || true)
echo "prepared: $prep_pass passed, $prep_fail failed"
[ "$prep_fail" -eq 0 ] || { echo "PREPARED SUITE FAILED"; exit 1; }

echo "=== [20/25] Deep health (PING) suite ==="
ping_out=$(./tests/test_ping.sh 2>/dev/null)
ping_pass=$(echo "$ping_out" | grep -c '\[0;32mPASS' || true)
ping_fail=$(echo "$ping_out" | grep -c '\[0;31mFAIL' || true)
echo "ping: $ping_pass passed, $ping_fail failed"
[ "$ping_fail" -eq 0 ] || { echo "PING SUITE FAILED"; exit 1; }

echo "=== [21/25] Migration check ==="
./database/migrate.sh --check

echo "=== [22/25] Migration tooling suite ==="
mig_out=$(./tests/test_migrate.sh 2>/dev/null)
mig_pass=$(echo "$mig_out" | grep -c '\[0;32mPASS' || true)
mig_fail=$(echo "$mig_out" | grep -c '\[0;31mFAIL' || true)
echo "migrations: $mig_pass passed, $mig_fail failed"
[ "$mig_fail" -eq 0 ] || { echo "MIGRATION SUITE FAILED"; exit 1; }

echo "=== [23/25] Status/docs integrity ==="
./tests/status_check.sh

echo "=== [24/25] End-to-end HTTP smoke ==="
e2e_out=$(./tests/test_e2e_gateway.sh 2>/dev/null)
e2e_pass=$(echo "$e2e_out" | grep -c '\[0;32mPASS' || true)
e2e_fail=$(echo "$e2e_out" | grep -c '\[0;31mFAIL' || true)
echo "e2e: $e2e_pass passed, $e2e_fail failed"
[ "$e2e_fail" -eq 0 ] || { echo "E2E SUITE FAILED"; exit 1; }

echo "=== [25/25] Serve mode suite ==="
serve_out=$(./tests/test_serve_mode.sh 2>/dev/null)
serve_pass=$(echo "$serve_out" | grep -c '\[0;32mPASS' || true)
serve_fail=$(echo "$serve_out" | grep -c '\[0;31mFAIL' || true)
echo "serve: $serve_pass passed, $serve_fail failed"
[ "$serve_fail" -eq 0 ] || { echo "SERVE MODE SUITE FAILED"; exit 1; }

echo "=== ALL GREEN ==="
