#!/bin/bash
# One-shot CI: docs integrity -> static COBOL checks -> build -> both test suites.
# Usage: ./ci.sh

set -e

# Keep the KDF cheap for the test run; production uses the compiled default
# (600000). Individual KDF tests override this per call.
export PBKDF2_ITERATIONS="${PBKDF2_ITERATIONS:-100000}"

# Per-suite pass counts recorded during this run; the final step compares them
# against tests/baseline_counts.txt so silently dropped assertions fail CI.
BASELINE_RUN="$(mktemp)"
trap 'rm -f "$BASELINE_RUN"' EXIT

# Count matching lines; always exits 0 so an empty result is a zero,
# never a swallowed set -e trip. (Replaces grep -c ... || true.)
count_matches() { awk -v re="$1" '$0 ~ re {n++} END {print n+0}'; }

# Run a command, capturing output and exit code explicitly instead of
# masking failures. Usage: run_step <out_var> <rc_var> <command...>
run_step() {
    local __out_var="$1" __rc_var="$2"; shift 2
    local __out __rc=0
    if __out=$("$@" 2>/dev/null); then __rc=0; else __rc=$?; fi
    printf -v "$__out_var" "%s" "$__out"
    printf -v "$__rc_var" "%s" "$__rc"
    return 0
}

echo "=== [1/61] Docs integrity check ==="
./tests/docs_check.sh

echo "=== [2/61] Static COBOL checks ==="
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
# owning module (router/owner agreement - the routing contract).
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

echo "=== [3/61] Build ==="
if build_log=$(./build.sh 2>&1); then build_rc=0; else build_rc=$?; fi
[ "$build_rc" -eq 0 ] || { echo "BUILD FAILED (rc=$build_rc)"; echo "$build_log" | tail -20; exit 1; }
echo "$build_log" | grep -E "^cobol.*error:" && { echo "BUILD FAILED"; exit 1; }
echo "$build_log" | grep -q "SUCCESS: Binary created" || { echo "BUILD FAILED"; exit 1; }
echo "Build OK"

echo "=== [4/61] Functional suite ==="
run_step func_out func_rc ./tests/test_suite.sh
[ "$func_rc" -eq 0 ] || { echo "FUNCTIONAL (rc=$func_rc)"; echo "$func_out" | tail -5; exit 1; }
echo "$func_out" | tail -1
func_fail=$(echo "$func_out" | grep -oE '[0-9]+ failed' | grep -oE '[0-9]+' | head -1 || echo 0)
func_fail=${func_fail:-0}
[ "$func_fail" -eq 0 ] || { echo "FUNCTIONAL SUITE FAILED"; exit 1; }
func_pass=$(echo "$func_out" | count_matches '\\[PASS\\]')
echo "functional $func_pass" >> "$BASELINE_RUN"

echo "=== [5/61] Atomic transaction suite ==="
run_step atomic_out atomic_rc ./tests/test_atomic_txn.sh
[ "$atomic_rc" -eq 0 ] || { echo "ATOMIC (rc=$atomic_rc)"; echo "$atomic_out" | tail -5; exit 1; }
atomic_pass=$(echo "$atomic_out" | count_matches '\\[0;32mPASS')
atomic_fail=$(echo "$atomic_out" | count_matches '\\[0;31mFAIL')
echo "atomic: $atomic_pass passed, $atomic_fail failed"
echo "atomic $atomic_pass" >> "$BASELINE_RUN"
[ "$atomic_fail" -eq 0 ] || { echo "ATOMIC SUITE FAILED"; exit 1; }

echo "=== [6/61] Ledger atomic suite ==="
run_step ledger_out ledger_rc ./tests/test_ledger_atomic.sh
[ "$ledger_rc" -eq 0 ] || { echo "LEDGER (rc=$ledger_rc)"; echo "$ledger_out" | tail -5; exit 1; }
ledger_pass=$(echo "$ledger_out" | count_matches '\\[0;32mPASS')
ledger_fail=$(echo "$ledger_out" | count_matches '\\[0;31mFAIL')
echo "ledger: $ledger_pass passed, $ledger_fail failed"
echo "ledger-atomic $ledger_pass" >> "$BASELINE_RUN"
[ "$ledger_fail" -eq 0 ] || { echo "LEDGER SUITE FAILED"; exit 1; }

echo "=== [7/61] Reconciliation suite ==="
run_step recon_out recon_rc ./tests/test_reconciliation.sh
[ "$recon_rc" -eq 0 ] || { echo "RECONCILIATION (rc=$recon_rc)"; echo "$recon_out" | tail -5; exit 1; }
recon_pass=$(echo "$recon_out" | count_matches '\\[0;32mPASS')
recon_fail=$(echo "$recon_out" | count_matches '\\[0;31mFAIL')
echo "reconciliation: $recon_pass passed, $recon_fail failed"
echo "reconciliation $recon_pass" >> "$BASELINE_RUN"
[ "$recon_fail" -eq 0 ] || { echo "RECONCILIATION SUITE FAILED"; exit 1; }

echo "=== [8/61] Auth login suite ==="
run_step auth_out auth_rc ./tests/test_auth_login.sh
[ "$auth_rc" -eq 0 ] || { echo "AUTH (rc=$auth_rc)"; echo "$auth_out" | tail -5; exit 1; }
auth_pass=$(echo "$auth_out" | count_matches '\\[0;32mPASS')
auth_fail=$(echo "$auth_out" | count_matches '\\[0;31mFAIL')
echo "auth: $auth_pass passed, $auth_fail failed"
echo "auth-login $auth_pass" >> "$BASELINE_RUN"
[ "$auth_fail" -eq 0 ] || { echo "AUTH SUITE FAILED"; exit 1; }

echo "=== [9/61] Signup + verify suite ==="
run_step signup_out signup_rc ./tests/test_signup_verify.sh
[ "$signup_rc" -eq 0 ] || { echo "SIGNUP (rc=$signup_rc)"; echo "$signup_out" | tail -5; exit 1; }
signup_pass=$(echo "$signup_out" | count_matches '\\[0;32mPASS')
signup_fail=$(echo "$signup_out" | count_matches '\\[0;31mFAIL')
echo "signup/verify: $signup_pass passed, $signup_fail failed"
echo "signup-verify $signup_pass" >> "$BASELINE_RUN"
[ "$signup_fail" -eq 0 ] || { echo "SIGNUP SUITE FAILED"; exit 1; }

echo "=== [10/61] Role suite ==="
run_step role_out role_rc ./tests/test_roles.sh
[ "$role_rc" -eq 0 ] || { echo "ROLE (rc=$role_rc)"; echo "$role_out" | tail -5; exit 1; }
role_pass=$(echo "$role_out" | count_matches '\\[0;32mPASS')
role_fail=$(echo "$role_out" | count_matches '\\[0;31mFAIL')
echo "roles: $role_pass passed, $role_fail failed"
echo "roles $role_pass" >> "$BASELINE_RUN"
[ "$role_fail" -eq 0 ] || { echo "ROLE SUITE FAILED"; exit 1; }

echo "=== [11/61] User profile suite ==="
run_step profile_out profile_rc ./tests/test_user_profile.sh
[ "$profile_rc" -eq 0 ] || { echo "PROFILE (rc=$profile_rc)"; echo "$profile_out" | tail -5; exit 1; }
profile_pass=$(echo "$profile_out" | count_matches '\\[0;32mPASS')
profile_fail=$(echo "$profile_out" | count_matches '\\[0;31mFAIL')
echo "profile: $profile_pass passed, $profile_fail failed"
echo "user-profile $profile_pass" >> "$BASELINE_RUN"
[ "$profile_fail" -eq 0 ] || { echo "PROFILE SUITE FAILED"; exit 1; }

echo "=== [12/61] API gateway suite ==="
if [ -d middleware ]; then
    npm --prefix middleware ci --silent >/dev/null 2>&1 || npm --prefix middleware install --silent >/dev/null 2>&1
    if npm --prefix middleware test --silent >/tmp/opencode/gateway.out 2>&1; then
        gw_pass=$(grep -E '^✔|^ℹ pass' /tmp/opencode/gateway.out | count_matches '^')
        echo "gateway: $(grep -E '^ℹ pass|^ℹ fail' /tmp/opencode/gateway.out | tr '\n' ' ')"
        # A skipped test reports green while covering nothing; fail loudly so
        # lost coverage (e.g. an unavailable database) can never pass silently.
        gw_skip=$(grep -E '^ℹ skipped' /tmp/opencode/gateway.out | grep -oE '[0-9]+' | head -1)
        [ "${gw_skip:-0}" -eq 0 ] || { echo "GATEWAY SUITE HAS SKIPPED TESTS (lost coverage)"; exit 1; }
        gw_total=$(grep -E '^ℹ pass' /tmp/opencode/gateway.out | grep -oE '[0-9]+' | awk '{s+=$1} END {print s+0}')
        echo "gateway $gw_total" >> "$BASELINE_RUN"
        echo "Gateway OK"
    else
        echo "GATEWAY SUITE FAILED"
        tail -20 /tmp/opencode/gateway.out
        exit 1
    fi
else
    echo "middleware/ absent; skipping"
fi

echo "=== [13/61] Login lockout suite ==="
run_step lockout_out lockout_rc ./tests/test_login_lockout.sh
[ "$lockout_rc" -eq 0 ] || { echo "LOCKOUT (rc=$lockout_rc)"; echo "$lockout_out" | tail -5; exit 1; }
lockout_pass=$(echo "$lockout_out" | count_matches '\\[0;32mPASS')
lockout_fail=$(echo "$lockout_out" | count_matches '\\[0;31mFAIL')
echo "lockout: $lockout_pass passed, $lockout_fail failed"
echo "lockout $lockout_pass" >> "$BASELINE_RUN"
[ "$lockout_fail" -eq 0 ] || { echo "LOCKOUT SUITE FAILED"; exit 1; }

echo "=== [14/61] Idempotent transfer suite ==="
run_step idem_out idem_rc ./tests/test_idempotent_transfer.sh
[ "$idem_rc" -eq 0 ] || { echo "IDEMPOTENT (rc=$idem_rc)"; echo "$idem_out" | tail -5; exit 1; }
idem_pass=$(echo "$idem_out" | count_matches '\\[0;32mPASS')
idem_fail=$(echo "$idem_out" | count_matches '\\[0;31mFAIL')
echo "idempotent transfer: $idem_pass passed, $idem_fail failed"
echo "idempotent-transfer $idem_pass" >> "$BASELINE_RUN"
[ "$idem_fail" -eq 0 ] || { echo "IDEMPOTENT SUITE FAILED"; exit 1; }

echo "=== [15/61] Transfer validity suite ==="
run_step validity_out validity_rc ./tests/test_transfer_validity.sh
[ "$validity_rc" -eq 0 ] || { echo "TRANSFER VALIDITY (rc=$validity_rc)"; echo "$validity_out" | tail -5; exit 1; }
validity_pass=$(echo "$validity_out" | count_matches '\\[0;32mPASS')
validity_fail=$(echo "$validity_out" | count_matches '\\[0;31mFAIL')
echo "transfer validity: $validity_pass passed, $validity_fail failed"
echo "transfer-validity $validity_pass" >> "$BASELINE_RUN"
[ "$validity_fail" -eq 0 ] || { echo "TRANSFER VALIDITY SUITE FAILED"; exit 1; }

echo "=== [16/61] Concurrent opposing transfers ==="
run_step conc_out conc_rc ./tests/test_concurrent_transfer.sh
[ "$conc_rc" -eq 0 ] || { echo "CONCURRENT (rc=$conc_rc)"; echo "$conc_out" | tail -5; exit 1; }
conc_pass=$(echo "$conc_out" | count_matches '\\[0;32mPASS')
conc_fail=$(echo "$conc_out" | count_matches '\\[0;31mFAIL')
echo "concurrent transfer: $conc_pass passed, $conc_fail failed"
echo "concurrent $conc_pass" >> "$BASELINE_RUN"
[ "$conc_fail" -eq 0 ] || { echo "CONCURRENT SUITE FAILED"; exit 1; }

echo "=== [17/61] SQL injection mitigation suite ==="
run_step inj_out inj_rc ./tests/test_injection.sh
[ "$inj_rc" -eq 0 ] || { echo "INJECTION (rc=$inj_rc)"; echo "$inj_out" | tail -5; exit 1; }
inj_pass=$(echo "$inj_out" | count_matches '\\[0;32mPASS')
inj_fail=$(echo "$inj_out" | count_matches '\\[0;31mFAIL')
echo "injection: $inj_pass passed, $inj_fail failed"
echo "injection $inj_pass" >> "$BASELINE_RUN"
[ "$inj_fail" -eq 0 ] || { echo "INJECTION SUITE FAILED"; exit 1; }

echo "=== [18/61] Refresh session suite ==="
run_step sess_out sess_rc ./tests/test_session.sh
[ "$sess_rc" -eq 0 ] || { echo "SESSION (rc=$sess_rc)"; echo "$sess_out" | tail -5; exit 1; }
sess_pass=$(echo "$sess_out" | count_matches '\\[0;32mPASS')
sess_fail=$(echo "$sess_out" | count_matches '\\[0;31mFAIL')
echo "session: $sess_pass passed, $sess_fail failed"
echo "session $sess_pass" >> "$BASELINE_RUN"
[ "$sess_fail" -eq 0 ] || { echo "SESSION SUITE FAILED"; exit 1; }

echo "=== [19/61] Prepared statement suite ==="
run_step prep_out prep_rc ./tests/test_prepared.sh
[ "$prep_rc" -eq 0 ] || { echo "PREPARED (rc=$prep_rc)"; echo "$prep_out" | tail -5; exit 1; }
prep_pass=$(echo "$prep_out" | count_matches '\\[0;32mPASS')
prep_fail=$(echo "$prep_out" | count_matches '\\[0;31mFAIL')
echo "prepared: $prep_pass passed, $prep_fail failed"
echo "prepared $prep_pass" >> "$BASELINE_RUN"
[ "$prep_fail" -eq 0 ] || { echo "PREPARED SUITE FAILED"; exit 1; }

echo "=== [20/61] Deep health (PING) suite ==="
run_step ping_out ping_rc ./tests/test_ping.sh
[ "$ping_rc" -eq 0 ] || { echo "PING (rc=$ping_rc)"; echo "$ping_out" | tail -5; exit 1; }
ping_pass=$(echo "$ping_out" | count_matches '\\[0;32mPASS')
ping_fail=$(echo "$ping_out" | count_matches '\\[0;31mFAIL')
echo "ping: $ping_pass passed, $ping_fail failed"
echo "ping $ping_pass" >> "$BASELINE_RUN"
[ "$ping_fail" -eq 0 ] || { echo "PING SUITE FAILED"; exit 1; }

echo "=== [21/61] Migration check ==="
./database/migrate.sh --check

echo "=== [22/61] Migration tooling suite ==="
run_step mig_out mig_rc ./tests/test_migrate.sh
[ "$mig_rc" -eq 0 ] || { echo "MIGRATION (rc=$mig_rc)"; echo "$mig_out" | tail -5; exit 1; }
mig_pass=$(echo "$mig_out" | count_matches '\\[0;32mPASS')
mig_fail=$(echo "$mig_out" | count_matches '\\[0;31mFAIL')
echo "migrations: $mig_pass passed, $mig_fail failed"
echo "migrate $mig_pass" >> "$BASELINE_RUN"
[ "$mig_fail" -eq 0 ] || { echo "MIGRATION SUITE FAILED"; exit 1; }

echo "=== [23/61] Status/docs integrity ==="
./tests/status_check.sh
./tests/traceability_check.sh

echo "=== [24/61] End-to-end HTTP smoke ==="
run_step e2e_out e2e_rc ./tests/test_e2e_gateway.sh
[ "$e2e_rc" -eq 0 ] || { echo "E2E (rc=$e2e_rc)"; echo "$e2e_out" | tail -5; exit 1; }
e2e_pass=$(echo "$e2e_out" | count_matches '\\[0;32mPASS')
e2e_fail=$(echo "$e2e_out" | count_matches '\\[0;31mFAIL')
echo "e2e: $e2e_pass passed, $e2e_fail failed"
echo "e2e $e2e_pass" >> "$BASELINE_RUN"
[ "$e2e_fail" -eq 0 ] || { echo "E2E SUITE FAILED"; exit 1; }

echo "=== [25/61] Serve mode suite ==="
run_step serve_out serve_rc ./tests/test_serve_mode.sh
[ "$serve_rc" -eq 0 ] || { echo "SERVE MODE (rc=$serve_rc)"; echo "$serve_out" | tail -5; exit 1; }
serve_pass=$(echo "$serve_out" | count_matches '\\[0;32mPASS')
serve_fail=$(echo "$serve_out" | count_matches '\\[0;31mFAIL')
echo "serve: $serve_pass passed, $serve_fail failed"
echo "serve $serve_pass" >> "$BASELINE_RUN"
[ "$serve_fail" -eq 0 ] || { echo "SERVE MODE SUITE FAILED"; exit 1; }

echo "=== [26/61] End-to-end HTTP smoke (pool mode) ==="
run_step pool_out pool_rc env COBOL_POOL_SIZE=4 ./tests/test_e2e_gateway.sh
[ "$pool_rc" -eq 0 ] || { echo "E2E POOL (rc=$pool_rc)"; echo "$pool_out" | tail -5; exit 1; }
pool_pass=$(echo "$pool_out" | count_matches '\\[0;32mPASS')
pool_fail=$(echo "$pool_out" | count_matches '\\[0;31mFAIL')
echo "e2e pool: $pool_pass passed, $pool_fail failed"
echo "e2e-pool $pool_pass" >> "$BASELINE_RUN"
[ "$pool_fail" -eq 0 ] || { echo "E2E POOL SUITE FAILED"; exit 1; }

echo "=== [27/61] Password reset/change suite ==="
run_step pw_out pw_rc ./tests/test_password.sh
[ "$pw_rc" -eq 0 ] || { echo "PASSWORD (rc=$pw_rc)"; echo "$pw_out" | tail -5; exit 1; }
pw_pass=$(echo "$pw_out" | count_matches '\\[0;32mPASS')
pw_fail=$(echo "$pw_out" | count_matches '\\[0;31mFAIL')
echo "password: $pw_pass passed, $pw_fail failed"
echo "password $pw_pass" >> "$BASELINE_RUN"
[ "$pw_fail" -eq 0 ] || { echo "PASSWORD SUITE FAILED"; exit 1; }

echo "=== [28/61] Verification attempt cap suite ==="
run_step cap_out cap_rc ./tests/test_verify_cap.sh
[ "$cap_rc" -eq 0 ] || { echo "VERIFY CAP (rc=$cap_rc)"; echo "$cap_out" | tail -5; exit 1; }
cap_pass=$(echo "$cap_out" | count_matches '\\[0;32mPASS')
cap_fail=$(echo "$cap_out" | count_matches '\\[0;31mFAIL')
echo "verify-cap: $cap_pass passed, $cap_fail failed"
echo "verify-cap $cap_pass" >> "$BASELINE_RUN"
[ "$cap_fail" -eq 0 ] || { echo "VERIFY CAP SUITE FAILED"; exit 1; }

echo "=== [29/61] Password KDF suite ==="
run_step kdf_out kdf_rc ./tests/test_password_kdf.sh
[ "$kdf_rc" -eq 0 ] || { echo "KDF (rc=$kdf_rc)"; echo "$kdf_out" | tail -5; exit 1; }
kdf_pass=$(echo "$kdf_out" | count_matches '\\[0;32mPASS')
kdf_fail=$(echo "$kdf_out" | count_matches '\\[0;31mFAIL')
echo "kdf: $kdf_pass passed, $kdf_fail failed"
echo "kdf $kdf_pass" >> "$BASELINE_RUN"
[ "$kdf_fail" -eq 0 ] || { echo "KDF SUITE FAILED"; exit 1; }

echo "=== [30/61] MFA (TOTP) suite ==="
run_step mfa_out mfa_rc ./tests/test_mfa.sh
[ "$mfa_rc" -eq 0 ] || { echo "MFA (rc=$mfa_rc)"; echo "$mfa_out" | tail -5; exit 1; }
mfa_pass=$(echo "$mfa_out" | count_matches '\\[0;32mPASS')
mfa_fail=$(echo "$mfa_out" | count_matches '\\[0;31mFAIL')
echo "mfa: $mfa_pass passed, $mfa_fail failed"
echo "mfa $mfa_pass" >> "$BASELINE_RUN"
[ "$mfa_fail" -eq 0 ] || { echo "MFA SUITE FAILED"; exit 1; }

echo "=== [31/61] Session management suite ==="
run_step sess_out sess_rc ./tests/test_sessions_manage.sh
[ "$sess_rc" -eq 0 ] || { echo "SESSION (rc=$sess_rc)"; echo "$sess_out" | tail -5; exit 1; }
sess_pass=$(echo "$sess_out" | count_matches '\\[0;32mPASS')
sess_fail=$(echo "$sess_out" | count_matches '\\[0;31mFAIL')
echo "sessions: $sess_pass passed, $sess_fail failed"
echo "sessions-manage $sess_pass" >> "$BASELINE_RUN"
[ "$sess_fail" -eq 0 ] || { echo "SESSION SUITE FAILED"; exit 1; }

echo "=== [32/61] Account status suite ==="
run_step stat_out stat_rc ./tests/test_account_status.sh
[ "$stat_rc" -eq 0 ] || { echo "ACCOUNT STATUS (rc=$stat_rc)"; echo "$stat_out" | tail -5; exit 1; }
stat_pass=$(echo "$stat_out" | count_matches '\\[0;32mPASS')
stat_fail=$(echo "$stat_out" | count_matches '\\[0;31mFAIL')
echo "account-status: $stat_pass passed, $stat_fail failed"
echo "account-status $stat_pass" >> "$BASELINE_RUN"
[ "$stat_fail" -eq 0 ] || { echo "ACCOUNT STATUS SUITE FAILED"; exit 1; }

echo "=== [33/61] Transfer limits suite ==="
run_step lim_out lim_rc ./tests/test_transfer_limits.sh
[ "$lim_rc" -eq 0 ] || { echo "TRANSFER LIMITS (rc=$lim_rc)"; echo "$lim_out" | tail -5; exit 1; }
lim_pass=$(echo "$lim_out" | count_matches '\\[0;32mPASS')
lim_fail=$(echo "$lim_out" | count_matches '\\[0;31mFAIL')
echo "limits: $lim_pass passed, $lim_fail failed"
echo "transfer-limits $lim_pass" >> "$BASELINE_RUN"
[ "$lim_fail" -eq 0 ] || { echo "TRANSFER LIMITS SUITE FAILED"; exit 1; }

echo "=== [34/61] Transfer reversal suite ==="
run_step rev_out rev_rc ./tests/test_transfer_reversal.sh
[ "$rev_rc" -eq 0 ] || { echo "REVERSAL (rc=$rev_rc)"; echo "$rev_out" | tail -5; exit 1; }
rev_pass=$(echo "$rev_out" | count_matches '\\[0;32mPASS')
rev_fail=$(echo "$rev_out" | count_matches '\\[0;31mFAIL')
echo "reversal: $rev_pass passed, $rev_fail failed"
echo "reversal $rev_pass" >> "$BASELINE_RUN"
[ "$rev_fail" -eq 0 ] || { echo "REVERSAL SUITE FAILED"; exit 1; }

echo "=== [35/61] Journal suite ==="
run_step journal_out journal_rc ./tests/test_journal.sh
[ "$journal_rc" -eq 0 ] || { echo "JOURNAL (rc=$journal_rc)"; echo "$journal_out" | tail -5; exit 1; }
journal_pass=$(echo "$journal_out" | count_matches '\\[0;32mPASS')
journal_fail=$(echo "$journal_out" | count_matches '\\[0;31mFAIL')
echo "journal: $journal_pass passed, $journal_fail failed"
echo "journal $journal_pass" >> "$BASELINE_RUN"
[ "$journal_fail" -eq 0 ] || { echo "JOURNAL SUITE FAILED"; exit 1; }

echo "=== [39/61] Holds and fees suite ==="
run_step holds_out holds_rc ./tests/test_holds.sh
[ "$holds_rc" -eq 0 ] || { echo "HOLDS (rc=$holds_rc)"; echo "$holds_out" | tail -5; exit 1; }
holds_pass=$(echo "$holds_out" | count_matches '\\[0;32mPASS')
holds_fail=$(echo "$holds_out" | count_matches '\\[0;31mFAIL')
echo "holds: $holds_pass passed, $holds_fail failed"
echo "holds $holds_pass" >> "$BASELINE_RUN"
[ "$holds_fail" -eq 0 ] || { echo "HOLDS SUITE FAILED"; exit 1; }

echo "=== [37/61] Dual control suite ==="
run_step dual_out dual_rc ./tests/test_dual_control.sh
[ "$dual_rc" -eq 0 ] || { echo "DUAL CONTROL (rc=$dual_rc)"; echo "$dual_out" | tail -5; exit 1; }
dual_pass=$(echo "$dual_out" | count_matches '\\[0;32mPASS')
dual_fail=$(echo "$dual_out" | count_matches '\\[0;31mFAIL')
echo "dual-control: $dual_pass passed, $dual_fail failed"
echo "dual-control $dual_pass" >> "$BASELINE_RUN"
[ "$dual_fail" -eq 0 ] || { echo "DUAL CONTROL SUITE FAILED"; exit 1; }

echo "=== [38/61] Outbox suite ==="
run_step outbox_out outbox_rc ./tests/test_outbox.sh
[ "$outbox_rc" -eq 0 ] || { echo "OUTBOX (rc=$outbox_rc)"; echo "$outbox_out" | tail -5; exit 1; }
outbox_pass=$(echo "$outbox_out" | count_matches '\\[0;32mPASS')
outbox_fail=$(echo "$outbox_out" | count_matches '\\[0;31mFAIL')
echo "outbox: $outbox_pass passed, $outbox_fail failed"
echo "outbox $outbox_pass" >> "$BASELINE_RUN"
[ "$outbox_fail" -eq 0 ] || { echo "OUTBOX SUITE FAILED"; exit 1; }

echo "=== [36/61] Reconciliation runs suite ==="
run_step reconruns_out reconruns_rc ./tests/test_reconciliation_runs.sh
[ "$reconruns_rc" -eq 0 ] || { echo "RECONCILIATION RUNS (rc=$reconruns_rc)"; echo "$reconruns_out" | tail -5; exit 1; }
reconruns_pass=$(echo "$reconruns_out" | count_matches '\\[0;32mPASS')
reconruns_fail=$(echo "$reconruns_out" | count_matches '\\[0;31mFAIL')
echo "recon-runs: $reconruns_pass passed, $reconruns_fail failed"
echo "recon-runs $reconruns_pass" >> "$BASELINE_RUN"
[ "$reconruns_fail" -eq 0 ] || { echo "RECONCILIATION RUNS SUITE FAILED"; exit 1; }

echo "=== [40/61] Wallet observability suite ==="
run_step obs_out obs_rc ./tests/test_wallet_observability.sh
[ "$obs_rc" -eq 0 ] || { echo "OBSERVABILITY (rc=$obs_rc)"; echo "$obs_out" | tail -5; exit 1; }
obs_pass=$(echo "$obs_out" | count_matches '\\[0;32mPASS')
obs_fail=$(echo "$obs_out" | count_matches '\\[0;31mFAIL')
echo "observability: $obs_pass passed, $obs_fail failed"
echo "observability $obs_pass" >> "$BASELINE_RUN"
[ "$obs_fail" -eq 0 ] || { echo "OBSERVABILITY SUITE FAILED"; exit 1; }

echo "=== [41/61] Account lifecycle suite ==="
run_step lc_out lc_rc ./tests/test_account_lifecycle.sh
[ "$lc_rc" -eq 0 ] || { echo "ACCOUNT LIFECYCLE (rc=$lc_rc)"; echo "$lc_out" | tail -5; exit 1; }
lc_pass=$(echo "$lc_out" | count_matches '\\[0;32mPASS')
lc_fail=$(echo "$lc_out" | count_matches '\\[0;31mFAIL')
echo "lifecycle: $lc_pass passed, $lc_fail failed"
echo "lifecycle $lc_pass" >> "$BASELINE_RUN"
[ "$lc_fail" -eq 0 ] || { echo "ACCOUNT LIFECYCLE SUITE FAILED"; exit 1; }

echo "=== [42/61] Token rotation suite ==="
run_step rot_out rot_rc ./tests/test_token_rotation.sh
[ "$rot_rc" -eq 0 ] || { echo "TOKEN ROTATION (rc=$rot_rc)"; echo "$rot_out" | tail -5; exit 1; }
rot_pass=$(echo "$rot_out" | count_matches '\\[0;32mPASS')
rot_fail=$(echo "$rot_out" | count_matches '\\[0;31mFAIL')
echo "rotation: $rot_pass passed, $rot_fail failed"
echo "rotation $rot_pass" >> "$BASELINE_RUN"
[ "$rot_fail" -eq 0 ] || { echo "TOKEN ROTATION SUITE FAILED"; exit 1; }

echo "=== [43/61] Admin role-hierarchy suite ==="
run_step hier_out hier_rc ./tests/test_admin_hierarchy.sh
[ "$hier_rc" -eq 0 ] || { echo "ADMIN HIERARCHY (rc=$hier_rc)"; echo "$hier_out" | tail -5; exit 1; }
hier_pass=$(echo "$hier_out" | count_matches '\\[0;32mPASS')
hier_fail=$(echo "$hier_out" | count_matches '\\[0;31mFAIL')
echo "hierarchy: $hier_pass passed, $hier_fail failed"
echo "admin-hierarchy $hier_pass" >> "$BASELINE_RUN"
[ "$hier_fail" -eq 0 ] || { echo "ADMIN HIERARCHY SUITE FAILED"; exit 1; }

echo "=== [44/61] Last-admin protection suite ==="
run_step la_out la_rc ./tests/test_last_admin.sh
[ "$la_rc" -eq 0 ] || { echo "LAST-ADMIN (rc=$la_rc)"; echo "$la_out" | tail -5; exit 1; }
la_pass=$(echo "$la_out" | count_matches '\\[0;32mPASS')
la_fail=$(echo "$la_out" | count_matches '\\[0;31mFAIL')
echo "last-admin: $la_pass passed, $la_fail failed"
echo "last-admin $la_pass" >> "$BASELINE_RUN"
[ "$la_fail" -eq 0 ] || { echo "LAST-ADMIN SUITE FAILED"; exit 1; }

echo "=== [45/61] Audit actor-attribution suite ==="
run_step aa_out aa_rc ./tests/test_audit_actor.sh
[ "$aa_rc" -eq 0 ] || { echo "AUDIT ACTOR (rc=$aa_rc)"; echo "$aa_out" | tail -5; exit 1; }
aa_pass=$(echo "$aa_out" | count_matches '\\[0;32mPASS')
aa_fail=$(echo "$aa_out" | count_matches '\\[0;31mFAIL')
echo "audit-actor: $aa_pass passed, $aa_fail failed"
echo "audit-actor $aa_pass" >> "$BASELINE_RUN"
[ "$aa_fail" -eq 0 ] || { echo "AUDIT ACTOR SUITE FAILED"; exit 1; }

echo "=== [46/61] Audit read suite ==="
run_step ar_out ar_rc ./tests/test_audit_read.sh
[ "$ar_rc" -eq 0 ] || { echo "AUDIT READ (rc=$ar_rc)"; echo "$ar_out" | tail -5; exit 1; }
ar_pass=$(echo "$ar_out" | count_matches '\\[0;32mPASS')
ar_fail=$(echo "$ar_out" | count_matches '\\[0;31mFAIL')
echo "audit-read: $ar_pass passed, $ar_fail failed"
echo "audit-read $ar_pass" >> "$BASELINE_RUN"
[ "$ar_fail" -eq 0 ] || { echo "AUDIT READ SUITE FAILED"; exit 1; }

echo "=== [47/61] Audit integrity suite ==="
run_step ai_out ai_rc ./tests/test_audit_integrity.sh
[ "$ai_rc" -eq 0 ] || { echo "AUDIT INTEGRITY (rc=$ai_rc)"; echo "$ai_out" | tail -5; exit 1; }
ai_pass=$(echo "$ai_out" | count_matches '\\[0;32mPASS')
ai_fail=$(echo "$ai_out" | count_matches '\\[0;31mFAIL')
echo "audit-integrity: $ai_pass passed, $ai_fail failed"
echo "audit-integrity $ai_pass" >> "$BASELINE_RUN"
[ "$ai_fail" -eq 0 ] || { echo "AUDIT INTEGRITY SUITE FAILED"; exit 1; }

echo "=== [48/61] Admin recovery suite ==="
run_step ar2_out ar2_rc ./tests/test_admin_recovery.sh
[ "$ar2_rc" -eq 0 ] || { echo "ADMIN RECOVERY (rc=$ar2_rc)"; echo "$ar2_out" | tail -5; exit 1; }
ar2_pass=$(echo "$ar2_out" | count_matches '\\[0;32mPASS')
ar2_fail=$(echo "$ar2_out" | count_matches '\\[0;31mFAIL')
echo "admin-recovery: $ar2_pass passed, $ar2_fail failed"
echo "admin-recovery $ar2_pass" >> "$BASELINE_RUN"
[ "$ar2_fail" -eq 0 ] || { echo "ADMIN RECOVERY SUITE FAILED"; exit 1; }

echo "=== [49/61] Step-up (re-authentication) suite ==="
run_step su_out su_rc ./tests/test_stepup.sh
[ "$su_rc" -eq 0 ] || { echo "STEP-UP (rc=$su_rc)"; echo "$su_out" | tail -5; exit 1; }
su_pass=$(echo "$su_out" | count_matches '\\[0;32mPASS')
su_fail=$(echo "$su_out" | count_matches '\\[0;31mFAIL')
echo "step-up: $su_pass passed, $su_fail failed"
echo "step-up $su_pass" >> "$BASELINE_RUN"
[ "$su_fail" -eq 0 ] || { echo "STEP-UP SUITE FAILED"; exit 1; }

echo "=== [50/61] MFA-state suite ==="
run_step ms_out ms_rc ./tests/test_mfa_state.sh
[ "$ms_rc" -eq 0 ] || { echo "MFA STATE (rc=$ms_rc)"; echo "$ms_out" | tail -5; exit 1; }
ms_pass=$(echo "$ms_out" | count_matches '\\[0;32mPASS')
ms_fail=$(echo "$ms_out" | count_matches '\\[0;31mFAIL')
echo "mfa-state: $ms_pass passed, $ms_fail failed"
echo "mfa-state $ms_pass" >> "$BASELINE_RUN"
[ "$ms_fail" -eq 0 ] || { echo "MFA STATE SUITE FAILED"; exit 1; }

echo "=== [51/61] Ledger integrity suite ==="
run_step li_out li_rc ./tests/test_ledger_integrity.sh
[ "$li_rc" -eq 0 ] || { echo "LEDGER INTEGRITY (rc=$li_rc)"; echo "$li_out" | tail -5; exit 1; }
li_pass=$(echo "$li_out" | count_matches '\\[0;32mPASS')
li_fail=$(echo "$li_out" | count_matches '\\[0;31mFAIL')
echo "ledger-integrity: $li_pass passed, $li_fail failed"
echo "ledger-integrity $li_pass" >> "$BASELINE_RUN"
[ "$li_fail" -eq 0 ] || { echo "LEDGER INTEGRITY SUITE FAILED"; exit 1; }

echo "=== [52/61] RNG (CSPRNG) suite ==="
run_step rng_out rng_rc ./tests/test_rng.sh
[ "$rng_rc" -eq 0 ] || { echo "RNG (rc=$rng_rc)"; echo "$rng_out" | tail -5; exit 1; }
rng_pass=$(echo "$rng_out" | count_matches '\\[0;32mPASS')
rng_fail=$(echo "$rng_out" | count_matches '\\[0;31mFAIL')
echo "rng: $rng_pass passed, $rng_fail failed"
echo "rng $rng_pass" >> "$BASELINE_RUN"
[ "$rng_fail" -eq 0 ] || { echo "RNG SUITE FAILED"; exit 1; }

echo "=== [53/61] Least-privilege database suite ==="
run_step gr_out gr_rc ./tests/test_grants.sh
[ "$gr_rc" -eq 0 ] || { echo "GRANTS (rc=$gr_rc)"; echo "$gr_out" | tail -5; exit 1; }
gr_pass=$(echo "$gr_out" | count_matches '\\[0;32mPASS')
gr_fail=$(echo "$gr_out" | count_matches '\\[0;31mFAIL')
echo "grants: $gr_pass passed, $gr_fail failed"
echo "grants $gr_pass" >> "$BASELINE_RUN"
[ "$gr_fail" -eq 0 ] || { echo "GRANTS SUITE FAILED"; exit 1; }

echo "=== [54/61] Resend cooldown suite ==="
run_step rc_out rc_rc ./tests/test_resend_cooldown.sh
[ "$rc_rc" -eq 0 ] || { echo "RESEND COOLDOWN (rc=$rc_rc)"; echo "$rc_out" | tail -5; exit 1; }
rc_pass=$(echo "$rc_out" | count_matches '\\[0;32mPASS')
rc_fail=$(echo "$rc_out" | count_matches '\\[0;31mFAIL')
echo "resend-cooldown: $rc_pass passed, $rc_fail failed"
echo "resend-cooldown $rc_pass" >> "$BASELINE_RUN"
[ "$rc_fail" -eq 0 ] || { echo "RESEND COOLDOWN SUITE FAILED"; exit 1; }

echo "=== [55/61] C memory-boundary suite ==="
run_step cm_out cm_rc ./tests/test_c_memory.sh
[ "$cm_rc" -eq 0 ] || { echo "C MEMORY (rc=$cm_rc)"; echo "$cm_out" | tail -5; exit 1; }
cm_pass=$(echo "$cm_out" | count_matches '\\[0;32mPASS')
cm_fail=$(echo "$cm_out" | count_matches '\\[0;31mFAIL')
echo "c-memory: $cm_pass passed, $cm_fail failed"
echo "c-memory $cm_pass" >> "$BASELINE_RUN"
[ "$cm_fail" -eq 0 ] || { echo "C MEMORY SUITE FAILED"; exit 1; }

echo "=== [56/61] Bridge transaction suite ==="
run_step bt_out bt_rc ./tests/test_bridge_txn.sh
[ "$bt_rc" -eq 0 ] || { echo "BRIDGE TXN (rc=$bt_rc)"; echo "$bt_out" | tail -5; exit 1; }
bt_pass=$(echo "$bt_out" | count_matches '\\[0;32mPASS')
bt_fail=$(echo "$bt_out" | count_matches '\\[0;31mFAIL')
echo "bridge-txn: $bt_pass passed, $bt_fail failed"
echo "bridge-txn $bt_pass" >> "$BASELINE_RUN"
[ "$bt_fail" -eq 0 ] || { echo "BRIDGE TXN SUITE FAILED"; exit 1; }

echo "=== [57/61] Buffer contract check ==="
./tests/buffer_contract_check.sh

echo "=== [58/61] Seed idempotency suite ==="
run_step seed_out seed_rc ./tests/test_seed.sh
[ "$seed_rc" -eq 0 ] || { echo "SEED (rc=$seed_rc)"; echo "$seed_out" | tail -5; exit 1; }
seed_pass=$(echo "$seed_out" | count_matches '\\[0;32mPASS')
seed_fail=$(echo "$seed_out" | count_matches '\\[0;31mFAIL')
echo "seed: $seed_pass passed, $seed_fail failed"
echo "seed $seed_pass" >> "$BASELINE_RUN"
[ "$seed_fail" -eq 0 ] || { echo "SEED SUITE FAILED"; exit 1; }

echo "=== [59/61] Env coverage check ==="
./tests/env_check.sh

echo "=== [60/61] Git hook hygiene suite ==="
run_step hk_out hk_rc ./tests/test_hooks.sh
[ "$hk_rc" -eq 0 ] || { echo "HOOKS (rc=$hk_rc)"; echo "$hk_out" | tail -5; exit 1; }
hk_pass=$(echo "$hk_out" | count_matches '\\[0;32mPASS')
hk_fail=$(echo "$hk_out" | count_matches '\\[0;31mFAIL')
echo "hooks: $hk_pass passed, $hk_fail failed"
echo "hooks $hk_pass" >> "$BASELINE_RUN"
[ "$hk_fail" -eq 0 ] || { echo "HOOKS SUITE FAILED"; exit 1; }

echo "=== [61/61] Assertion-count baseline ==="
./tests/baseline_check.sh "$BASELINE_RUN"

echo "=== ALL GREEN ==="
