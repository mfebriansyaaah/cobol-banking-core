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

echo "=== [1/53] Docs integrity check ==="
./tests/docs_check.sh

echo "=== [2/53] Static COBOL checks ==="
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

echo "=== [3/53] Build ==="
build_log=$(./build.sh 2>&1 || true)
echo "$build_log" | grep -E "^cobol.*error:" && { echo "BUILD FAILED"; exit 1; }
echo "$build_log" | grep -q "SUCCESS: Binary created" || { echo "BUILD FAILED"; exit 1; }
echo "Build OK"

echo "=== [4/53] Functional suite ==="
func_out=$(./tests/test_suite.sh 2>/dev/null)
echo "$func_out" | tail -1
func_fail=$(echo "$func_out" | grep -oE '[0-9]+ failed' | grep -oE '[0-9]+' | head -1 || echo 0)
func_fail=${func_fail:-0}
[ "$func_fail" -eq 0 ] || { echo "FUNCTIONAL SUITE FAILED"; exit 1; }
func_pass=$(echo "$func_out" | grep -c '\[PASS\]' || true)
echo "functional $func_pass" >> "$BASELINE_RUN"

echo "=== [5/53] Atomic transaction suite ==="
atomic_out=$(./tests/test_atomic_txn.sh 2>/dev/null)
atomic_pass=$(echo "$atomic_out" | grep -c '\[0;32mPASS' || true)
atomic_fail=$(echo "$atomic_out" | grep -c '\[0;31mFAIL' || true)
echo "atomic: $atomic_pass passed, $atomic_fail failed"
echo "atomic $atomic_pass" >> "$BASELINE_RUN"
[ "$atomic_fail" -eq 0 ] || { echo "ATOMIC SUITE FAILED"; exit 1; }

echo "=== [6/53] Ledger atomic suite ==="
ledger_out=$(./tests/test_ledger_atomic.sh 2>/dev/null)
ledger_pass=$(echo "$ledger_out" | grep -c '\[0;32mPASS' || true)
ledger_fail=$(echo "$ledger_out" | grep -c '\[0;31mFAIL' || true)
echo "ledger: $ledger_pass passed, $ledger_fail failed"
echo "ledger-atomic $ledger_pass" >> "$BASELINE_RUN"
[ "$ledger_fail" -eq 0 ] || { echo "LEDGER SUITE FAILED"; exit 1; }

echo "=== [7/53] Reconciliation suite ==="
recon_out=$(./tests/test_reconciliation.sh 2>/dev/null)
recon_pass=$(echo "$recon_out" | grep -c '\[0;32mPASS' || true)
recon_fail=$(echo "$recon_out" | grep -c '\[0;31mFAIL' || true)
echo "reconciliation: $recon_pass passed, $recon_fail failed"
echo "reconciliation $recon_pass" >> "$BASELINE_RUN"
[ "$recon_fail" -eq 0 ] || { echo "RECONCILIATION SUITE FAILED"; exit 1; }

echo "=== [8/53] Auth login suite ==="
auth_out=$(./tests/test_auth_login.sh 2>/dev/null)
auth_pass=$(echo "$auth_out" | grep -c '\[0;32mPASS' || true)
auth_fail=$(echo "$auth_out" | grep -c '\[0;31mFAIL' || true)
echo "auth: $auth_pass passed, $auth_fail failed"
echo "auth-login $auth_pass" >> "$BASELINE_RUN"
[ "$auth_fail" -eq 0 ] || { echo "AUTH SUITE FAILED"; exit 1; }

echo "=== [9/53] Signup + verify suite ==="
signup_out=$(./tests/test_signup_verify.sh 2>/dev/null)
signup_pass=$(echo "$signup_out" | grep -c '\[0;32mPASS' || true)
signup_fail=$(echo "$signup_out" | grep -c '\[0;31mFAIL' || true)
echo "signup/verify: $signup_pass passed, $signup_fail failed"
echo "signup-verify $signup_pass" >> "$BASELINE_RUN"
[ "$signup_fail" -eq 0 ] || { echo "SIGNUP SUITE FAILED"; exit 1; }

echo "=== [10/53] Role suite ==="
role_out=$(./tests/test_roles.sh 2>/dev/null)
role_pass=$(echo "$role_out" | grep -c '\[0;32mPASS' || true)
role_fail=$(echo "$role_out" | grep -c '\[0;31mFAIL' || true)
echo "roles: $role_pass passed, $role_fail failed"
echo "roles $role_pass" >> "$BASELINE_RUN"
[ "$role_fail" -eq 0 ] || { echo "ROLE SUITE FAILED"; exit 1; }

echo "=== [11/53] User profile suite ==="
profile_out=$(./tests/test_user_profile.sh 2>/dev/null)
profile_pass=$(echo "$profile_out" | grep -c '\[0;32mPASS' || true)
profile_fail=$(echo "$profile_out" | grep -c '\[0;31mFAIL' || true)
echo "profile: $profile_pass passed, $profile_fail failed"
echo "user-profile $profile_pass" >> "$BASELINE_RUN"
[ "$profile_fail" -eq 0 ] || { echo "PROFILE SUITE FAILED"; exit 1; }

echo "=== [12/53] API gateway suite ==="
if [ -d middleware ]; then
    npm --prefix middleware ci --silent >/dev/null 2>&1 || npm --prefix middleware install --silent >/dev/null 2>&1
    if npm --prefix middleware test --silent >/tmp/opencode/gateway.out 2>&1; then
        gw_pass=$(grep -cE '^✔|^ℹ pass' /tmp/opencode/gateway.out || true)
        echo "gateway: $(grep -E '^ℹ pass|^ℹ fail' /tmp/opencode/gateway.out | tr '\n' ' ')"
        # A skipped test reports green while covering nothing; fail loudly so
        # lost coverage (e.g. an unavailable database) can never pass silently.
        gw_skip=$(grep -E '^ℹ skipped' /tmp/opencode/gateway.out | grep -oE '[0-9]+' | head -1 || true)
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

echo "=== [13/53] Login lockout suite ==="
lockout_out=$(./tests/test_login_lockout.sh 2>/dev/null)
lockout_pass=$(echo "$lockout_out" | grep -c '\[0;32mPASS' || true)
lockout_fail=$(echo "$lockout_out" | grep -c '\[0;31mFAIL' || true)
echo "lockout: $lockout_pass passed, $lockout_fail failed"
echo "lockout $lockout_pass" >> "$BASELINE_RUN"
[ "$lockout_fail" -eq 0 ] || { echo "LOCKOUT SUITE FAILED"; exit 1; }

echo "=== [14/53] Idempotent transfer suite ==="
idem_out=$(./tests/test_idempotent_transfer.sh 2>/dev/null)
idem_pass=$(echo "$idem_out" | grep -c '\[0;32mPASS' || true)
idem_fail=$(echo "$idem_out" | grep -c '\[0;31mFAIL' || true)
echo "idempotent transfer: $idem_pass passed, $idem_fail failed"
echo "idempotent-transfer $idem_pass" >> "$BASELINE_RUN"
[ "$idem_fail" -eq 0 ] || { echo "IDEMPOTENT SUITE FAILED"; exit 1; }

echo "=== [15/53] Transfer validity suite ==="
validity_out=$(./tests/test_transfer_validity.sh 2>/dev/null)
validity_pass=$(echo "$validity_out" | grep -c '\[0;32mPASS' || true)
validity_fail=$(echo "$validity_out" | grep -c '\[0;31mFAIL' || true)
echo "transfer validity: $validity_pass passed, $validity_fail failed"
echo "transfer-validity $validity_pass" >> "$BASELINE_RUN"
[ "$validity_fail" -eq 0 ] || { echo "TRANSFER VALIDITY SUITE FAILED"; exit 1; }

echo "=== [16/53] Concurrent opposing transfers ==="
conc_out=$(./tests/test_concurrent_transfer.sh 2>/dev/null)
conc_pass=$(echo "$conc_out" | grep -c '\[0;32mPASS' || true)
conc_fail=$(echo "$conc_out" | grep -c '\[0;31mFAIL' || true)
echo "concurrent transfer: $conc_pass passed, $conc_fail failed"
echo "concurrent $conc_pass" >> "$BASELINE_RUN"
[ "$conc_fail" -eq 0 ] || { echo "CONCURRENT SUITE FAILED"; exit 1; }

echo "=== [17/53] SQL injection mitigation suite ==="
inj_out=$(./tests/test_injection.sh 2>/dev/null)
inj_pass=$(echo "$inj_out" | grep -c '\[0;32mPASS' || true)
inj_fail=$(echo "$inj_out" | grep -c '\[0;31mFAIL' || true)
echo "injection: $inj_pass passed, $inj_fail failed"
echo "injection $inj_pass" >> "$BASELINE_RUN"
[ "$inj_fail" -eq 0 ] || { echo "INJECTION SUITE FAILED"; exit 1; }

echo "=== [18/53] Refresh session suite ==="
sess_out=$(./tests/test_session.sh 2>/dev/null)
sess_pass=$(echo "$sess_out" | grep -c '\[0;32mPASS' || true)
sess_fail=$(echo "$sess_out" | grep -c '\[0;31mFAIL' || true)
echo "session: $sess_pass passed, $sess_fail failed"
echo "session $sess_pass" >> "$BASELINE_RUN"
[ "$sess_fail" -eq 0 ] || { echo "SESSION SUITE FAILED"; exit 1; }

echo "=== [19/53] Prepared statement suite ==="
prep_out=$(./tests/test_prepared.sh 2>/dev/null)
prep_pass=$(echo "$prep_out" | grep -c '\[0;32mPASS' || true)
prep_fail=$(echo "$prep_out" | grep -c '\[0;31mFAIL' || true)
echo "prepared: $prep_pass passed, $prep_fail failed"
echo "prepared $prep_pass" >> "$BASELINE_RUN"
[ "$prep_fail" -eq 0 ] || { echo "PREPARED SUITE FAILED"; exit 1; }

echo "=== [20/53] Deep health (PING) suite ==="
ping_out=$(./tests/test_ping.sh 2>/dev/null)
ping_pass=$(echo "$ping_out" | grep -c '\[0;32mPASS' || true)
ping_fail=$(echo "$ping_out" | grep -c '\[0;31mFAIL' || true)
echo "ping: $ping_pass passed, $ping_fail failed"
echo "ping $ping_pass" >> "$BASELINE_RUN"
[ "$ping_fail" -eq 0 ] || { echo "PING SUITE FAILED"; exit 1; }

echo "=== [21/53] Migration check ==="
./database/migrate.sh --check

echo "=== [22/53] Migration tooling suite ==="
mig_out=$(./tests/test_migrate.sh 2>/dev/null)
mig_pass=$(echo "$mig_out" | grep -c '\[0;32mPASS' || true)
mig_fail=$(echo "$mig_out" | grep -c '\[0;31mFAIL' || true)
echo "migrations: $mig_pass passed, $mig_fail failed"
echo "migrate $mig_pass" >> "$BASELINE_RUN"
[ "$mig_fail" -eq 0 ] || { echo "MIGRATION SUITE FAILED"; exit 1; }

echo "=== [23/53] Status/docs integrity ==="
./tests/status_check.sh

echo "=== [24/53] End-to-end HTTP smoke ==="
e2e_out=$(./tests/test_e2e_gateway.sh 2>/dev/null)
e2e_pass=$(echo "$e2e_out" | grep -c '\[0;32mPASS' || true)
e2e_fail=$(echo "$e2e_out" | grep -c '\[0;31mFAIL' || true)
echo "e2e: $e2e_pass passed, $e2e_fail failed"
echo "e2e $e2e_pass" >> "$BASELINE_RUN"
[ "$e2e_fail" -eq 0 ] || { echo "E2E SUITE FAILED"; exit 1; }

echo "=== [25/53] Serve mode suite ==="
serve_out=$(./tests/test_serve_mode.sh 2>/dev/null)
serve_pass=$(echo "$serve_out" | grep -c '\[0;32mPASS' || true)
serve_fail=$(echo "$serve_out" | grep -c '\[0;31mFAIL' || true)
echo "serve: $serve_pass passed, $serve_fail failed"
echo "serve $serve_pass" >> "$BASELINE_RUN"
[ "$serve_fail" -eq 0 ] || { echo "SERVE MODE SUITE FAILED"; exit 1; }

echo "=== [26/53] End-to-end HTTP smoke (pool mode) ==="
pool_out=$(COBOL_POOL_SIZE=4 ./tests/test_e2e_gateway.sh 2>/dev/null)
pool_pass=$(echo "$pool_out" | grep -c '\[0;32mPASS' || true)
pool_fail=$(echo "$pool_out" | grep -c '\[0;31mFAIL' || true)
echo "e2e pool: $pool_pass passed, $pool_fail failed"
echo "e2e-pool $pool_pass" >> "$BASELINE_RUN"
[ "$pool_fail" -eq 0 ] || { echo "E2E POOL SUITE FAILED"; exit 1; }

echo "=== [27/53] Password reset/change suite ==="
pw_out=$(./tests/test_password.sh 2>/dev/null)
pw_pass=$(echo "$pw_out" | grep -c '\[0;32mPASS' || true)
pw_fail=$(echo "$pw_out" | grep -c '\[0;31mFAIL' || true)
echo "password: $pw_pass passed, $pw_fail failed"
echo "password $pw_pass" >> "$BASELINE_RUN"
[ "$pw_fail" -eq 0 ] || { echo "PASSWORD SUITE FAILED"; exit 1; }

echo "=== [28/53] Verification attempt cap suite ==="
cap_out=$(./tests/test_verify_cap.sh 2>/dev/null)
cap_pass=$(echo "$cap_out" | grep -c '\[0;32mPASS' || true)
cap_fail=$(echo "$cap_out" | grep -c '\[0;31mFAIL' || true)
echo "verify-cap: $cap_pass passed, $cap_fail failed"
echo "verify-cap $cap_pass" >> "$BASELINE_RUN"
[ "$cap_fail" -eq 0 ] || { echo "VERIFY CAP SUITE FAILED"; exit 1; }

echo "=== [29/53] Password KDF suite ==="
kdf_out=$(./tests/test_password_kdf.sh 2>/dev/null)
kdf_pass=$(echo "$kdf_out" | grep -c '\[0;32mPASS' || true)
kdf_fail=$(echo "$kdf_out" | grep -c '\[0;31mFAIL' || true)
echo "kdf: $kdf_pass passed, $kdf_fail failed"
echo "kdf $kdf_pass" >> "$BASELINE_RUN"
[ "$kdf_fail" -eq 0 ] || { echo "KDF SUITE FAILED"; exit 1; }

echo "=== [30/53] MFA (TOTP) suite ==="
mfa_out=$(./tests/test_mfa.sh 2>/dev/null)
mfa_pass=$(echo "$mfa_out" | grep -c '\[0;32mPASS' || true)
mfa_fail=$(echo "$mfa_out" | grep -c '\[0;31mFAIL' || true)
echo "mfa: $mfa_pass passed, $mfa_fail failed"
echo "mfa $mfa_pass" >> "$BASELINE_RUN"
[ "$mfa_fail" -eq 0 ] || { echo "MFA SUITE FAILED"; exit 1; }

echo "=== [31/53] Session management suite ==="
sess_out=$(./tests/test_sessions_manage.sh 2>/dev/null)
sess_pass=$(echo "$sess_out" | grep -c '\[0;32mPASS' || true)
sess_fail=$(echo "$sess_out" | grep -c '\[0;31mFAIL' || true)
echo "sessions: $sess_pass passed, $sess_fail failed"
echo "sessions-manage $sess_pass" >> "$BASELINE_RUN"
[ "$sess_fail" -eq 0 ] || { echo "SESSION SUITE FAILED"; exit 1; }

echo "=== [32/53] Account status suite ==="
stat_out=$(./tests/test_account_status.sh 2>/dev/null)
stat_pass=$(echo "$stat_out" | grep -c '\[0;32mPASS' || true)
stat_fail=$(echo "$stat_out" | grep -c '\[0;31mFAIL' || true)
echo "account-status: $stat_pass passed, $stat_fail failed"
echo "account-status $stat_pass" >> "$BASELINE_RUN"
[ "$stat_fail" -eq 0 ] || { echo "ACCOUNT STATUS SUITE FAILED"; exit 1; }

echo "=== [33/53] Transfer limits suite ==="
lim_out=$(./tests/test_transfer_limits.sh 2>/dev/null)
lim_pass=$(echo "$lim_out" | grep -c '\[0;32mPASS' || true)
lim_fail=$(echo "$lim_out" | grep -c '\[0;31mFAIL' || true)
echo "limits: $lim_pass passed, $lim_fail failed"
echo "transfer-limits $lim_pass" >> "$BASELINE_RUN"
[ "$lim_fail" -eq 0 ] || { echo "TRANSFER LIMITS SUITE FAILED"; exit 1; }

echo "=== [34/53] Transfer reversal suite ==="
rev_out=$(./tests/test_transfer_reversal.sh 2>/dev/null)
rev_pass=$(echo "$rev_out" | grep -c '\[0;32mPASS' || true)
rev_fail=$(echo "$rev_out" | grep -c '\[0;31mFAIL' || true)
echo "reversal: $rev_pass passed, $rev_fail failed"
echo "reversal $rev_pass" >> "$BASELINE_RUN"
[ "$rev_fail" -eq 0 ] || { echo "REVERSAL SUITE FAILED"; exit 1; }

echo "=== [35/53] Wallet observability suite ==="
obs_out=$(./tests/test_wallet_observability.sh 2>/dev/null)
obs_pass=$(echo "$obs_out" | grep -c '\[0;32mPASS' || true)
obs_fail=$(echo "$obs_out" | grep -c '\[0;31mFAIL' || true)
echo "observability: $obs_pass passed, $obs_fail failed"
echo "observability $obs_pass" >> "$BASELINE_RUN"
[ "$obs_fail" -eq 0 ] || { echo "OBSERVABILITY SUITE FAILED"; exit 1; }

echo "=== [36/53] Account lifecycle suite ==="
lc_out=$(./tests/test_account_lifecycle.sh 2>/dev/null)
lc_pass=$(echo "$lc_out" | grep -c '\[0;32mPASS' || true)
lc_fail=$(echo "$lc_out" | grep -c '\[0;31mFAIL' || true)
echo "lifecycle: $lc_pass passed, $lc_fail failed"
echo "lifecycle $lc_pass" >> "$BASELINE_RUN"
[ "$lc_fail" -eq 0 ] || { echo "ACCOUNT LIFECYCLE SUITE FAILED"; exit 1; }

echo "=== [37/53] Token rotation suite ==="
rot_out=$(./tests/test_token_rotation.sh 2>/dev/null)
rot_pass=$(echo "$rot_out" | grep -c '\[0;32mPASS' || true)
rot_fail=$(echo "$rot_out" | grep -c '\[0;31mFAIL' || true)
echo "rotation: $rot_pass passed, $rot_fail failed"
echo "rotation $rot_pass" >> "$BASELINE_RUN"
[ "$rot_fail" -eq 0 ] || { echo "TOKEN ROTATION SUITE FAILED"; exit 1; }

echo "=== [38/53] Admin role-hierarchy suite ==="
hier_out=$(./tests/test_admin_hierarchy.sh 2>/dev/null)
hier_pass=$(echo "$hier_out" | grep -c '\[0;32mPASS' || true)
hier_fail=$(echo "$hier_out" | grep -c '\[0;31mFAIL' || true)
echo "hierarchy: $hier_pass passed, $hier_fail failed"
echo "admin-hierarchy $hier_pass" >> "$BASELINE_RUN"
[ "$hier_fail" -eq 0 ] || { echo "ADMIN HIERARCHY SUITE FAILED"; exit 1; }

echo "=== [39/53] Last-admin protection suite ==="
la_out=$(./tests/test_last_admin.sh 2>/dev/null)
la_pass=$(echo "$la_out" | grep -c '\[0;32mPASS' || true)
la_fail=$(echo "$la_out" | grep -c '\[0;31mFAIL' || true)
echo "last-admin: $la_pass passed, $la_fail failed"
echo "last-admin $la_pass" >> "$BASELINE_RUN"
[ "$la_fail" -eq 0 ] || { echo "LAST-ADMIN SUITE FAILED"; exit 1; }

echo "=== [40/53] Audit actor-attribution suite ==="
aa_out=$(./tests/test_audit_actor.sh 2>/dev/null)
aa_pass=$(echo "$aa_out" | grep -c '\[0;32mPASS' || true)
aa_fail=$(echo "$aa_out" | grep -c '\[0;31mFAIL' || true)
echo "audit-actor: $aa_pass passed, $aa_fail failed"
echo "audit-actor $aa_pass" >> "$BASELINE_RUN"
[ "$aa_fail" -eq 0 ] || { echo "AUDIT ACTOR SUITE FAILED"; exit 1; }

echo "=== [41/53] Audit read suite ==="
ar_out=$(./tests/test_audit_read.sh 2>/dev/null)
ar_pass=$(echo "$ar_out" | grep -c '\[0;32mPASS' || true)
ar_fail=$(echo "$ar_out" | grep -c '\[0;31mFAIL' || true)
echo "audit-read: $ar_pass passed, $ar_fail failed"
echo "audit-read $ar_pass" >> "$BASELINE_RUN"
[ "$ar_fail" -eq 0 ] || { echo "AUDIT READ SUITE FAILED"; exit 1; }

echo "=== [42/53] Audit integrity suite ==="
ai_out=$(./tests/test_audit_integrity.sh 2>/dev/null)
ai_pass=$(echo "$ai_out" | grep -c '\[0;32mPASS' || true)
ai_fail=$(echo "$ai_out" | grep -c '\[0;31mFAIL' || true)
echo "audit-integrity: $ai_pass passed, $ai_fail failed"
echo "audit-integrity $ai_pass" >> "$BASELINE_RUN"
[ "$ai_fail" -eq 0 ] || { echo "AUDIT INTEGRITY SUITE FAILED"; exit 1; }

echo "=== [43/53] Admin recovery suite ==="
ar2_out=$(./tests/test_admin_recovery.sh 2>/dev/null)
ar2_pass=$(echo "$ar2_out" | grep -c '\[0;32mPASS' || true)
ar2_fail=$(echo "$ar2_out" | grep -c '\[0;31mFAIL' || true)
echo "admin-recovery: $ar2_pass passed, $ar2_fail failed"
echo "admin-recovery $ar2_pass" >> "$BASELINE_RUN"
[ "$ar2_fail" -eq 0 ] || { echo "ADMIN RECOVERY SUITE FAILED"; exit 1; }

echo "=== [44/53] Step-up (re-authentication) suite ==="
su_out=$(./tests/test_stepup.sh 2>/dev/null)
su_pass=$(echo "$su_out" | grep -c '\[0;32mPASS' || true)
su_fail=$(echo "$su_out" | grep -c '\[0;31mFAIL' || true)
echo "step-up: $su_pass passed, $su_fail failed"
echo "step-up $su_pass" >> "$BASELINE_RUN"
[ "$su_fail" -eq 0 ] || { echo "STEP-UP SUITE FAILED"; exit 1; }

echo "=== [45/53] MFA-state suite ==="
ms_out=$(./tests/test_mfa_state.sh 2>/dev/null)
ms_pass=$(echo "$ms_out" | grep -c '\[0;32mPASS' || true)
ms_fail=$(echo "$ms_out" | grep -c '\[0;31mFAIL' || true)
echo "mfa-state: $ms_pass passed, $ms_fail failed"
echo "mfa-state $ms_pass" >> "$BASELINE_RUN"
[ "$ms_fail" -eq 0 ] || { echo "MFA STATE SUITE FAILED"; exit 1; }

echo "=== [46/53] Ledger integrity suite ==="
li_out=$(./tests/test_ledger_integrity.sh 2>/dev/null)
li_pass=$(echo "$li_out" | grep -c '\[0;32mPASS' || true)
li_fail=$(echo "$li_out" | grep -c '\[0;31mFAIL' || true)
echo "ledger-integrity: $li_pass passed, $li_fail failed"
echo "ledger-integrity $li_pass" >> "$BASELINE_RUN"
[ "$li_fail" -eq 0 ] || { echo "LEDGER INTEGRITY SUITE FAILED"; exit 1; }

echo "=== [47/53] RNG (CSPRNG) suite ==="
rng_out=$(./tests/test_rng.sh 2>/dev/null)
rng_pass=$(echo "$rng_out" | grep -c '\[0;32mPASS' || true)
rng_fail=$(echo "$rng_out" | grep -c '\[0;31mFAIL' || true)
echo "rng: $rng_pass passed, $rng_fail failed"
echo "rng $rng_pass" >> "$BASELINE_RUN"
[ "$rng_fail" -eq 0 ] || { echo "RNG SUITE FAILED"; exit 1; }

echo "=== [48/53] Least-privilege database suite ==="
gr_out=$(./tests/test_grants.sh 2>/dev/null)
gr_pass=$(echo "$gr_out" | grep -c '\[0;32mPASS' || true)
gr_fail=$(echo "$gr_out" | grep -c '\[0;31mFAIL' || true)
echo "grants: $gr_pass passed, $gr_fail failed"
echo "grants $gr_pass" >> "$BASELINE_RUN"
[ "$gr_fail" -eq 0 ] || { echo "GRANTS SUITE FAILED"; exit 1; }

echo "=== [49/53] Resend cooldown suite ==="
rc_out=$(./tests/test_resend_cooldown.sh 2>/dev/null)
rc_pass=$(echo "$rc_out" | grep -c '\[0;32mPASS' || true)
rc_fail=$(echo "$rc_out" | grep -c '\[0;31mFAIL' || true)
echo "resend-cooldown: $rc_pass passed, $rc_fail failed"
echo "resend-cooldown $rc_pass" >> "$BASELINE_RUN"
[ "$rc_fail" -eq 0 ] || { echo "RESEND COOLDOWN SUITE FAILED"; exit 1; }

echo "=== [50/53] C memory-boundary suite ==="
cm_out=$(./tests/test_c_memory.sh 2>/dev/null)
cm_pass=$(echo "$cm_out" | grep -c '\[0;32mPASS' || true)
cm_fail=$(echo "$cm_out" | grep -c '\[0;31mFAIL' || true)
echo "c-memory: $cm_pass passed, $cm_fail failed"
echo "c-memory $cm_pass" >> "$BASELINE_RUN"
[ "$cm_fail" -eq 0 ] || { echo "C MEMORY SUITE FAILED"; exit 1; }

echo "=== [51/53] Bridge transaction suite ==="
bt_out=$(./tests/test_bridge_txn.sh 2>/dev/null)
bt_pass=$(echo "$bt_out" | grep -c '\[0;32mPASS' || true)
bt_fail=$(echo "$bt_out" | grep -c '\[0;31mFAIL' || true)
echo "bridge-txn: $bt_pass passed, $bt_fail failed"
echo "bridge-txn $bt_pass" >> "$BASELINE_RUN"
[ "$bt_fail" -eq 0 ] || { echo "BRIDGE TXN SUITE FAILED"; exit 1; }

echo "=== [52/53] Buffer contract check ==="
./tests/buffer_contract_check.sh

echo "=== [53/53] Assertion-count baseline ==="
./tests/baseline_check.sh "$BASELINE_RUN"

echo "=== ALL GREEN ==="
