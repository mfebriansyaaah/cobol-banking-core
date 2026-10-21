#!/bin/bash
# One-shot CI: docs integrity -> static COBOL checks -> build -> both test suites.
# Usage: ./ci.sh

set -e

# Keep the KDF cheap for the test run; production uses the compiled default
# (600000). The KDF suite sets its own costs per call and asserts the compiled
# default, so this only affects the unrelated suites' fixture hashing.
export PBKDF2_ITERATIONS="${PBKDF2_ITERATIONS:-10000}"

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

echo "=== [1/90] Docs integrity check ==="
./tests/docs_check.sh

echo "=== [2/90] Static COBOL checks ==="
./tests/static_checks.sh

echo "=== [3/90] Build ==="
if build_log=$(./build.sh 2>&1); then build_rc=0; else build_rc=$?; fi
[ "$build_rc" -eq 0 ] || { echo "BUILD FAILED (rc=$build_rc)"; echo "$build_log" | tail -20; exit 1; }
echo "$build_log" | grep -E "^cobol.*error:" && { echo "BUILD FAILED"; exit 1; }
echo "$build_log" | grep -q "SUCCESS: Binary created" || { echo "BUILD FAILED"; exit 1; }
bw_log="$(mktemp)"
printf '%s\n' "$build_log" > "$bw_log"
./tests/warning_check.sh "$bw_log"
rm -f "$bw_log"
echo "Build OK"

echo "=== [4/90] Functional suite ==="
run_step func_out func_rc ./tests/test_suite.sh
[ "$func_rc" -eq 0 ] || { echo "FUNCTIONAL (rc=$func_rc)"; echo "$func_out" | tail -5; exit 1; }
echo "$func_out" | tail -1
func_fail=$(echo "$func_out" | grep -oE '[0-9]+ failed' | grep -oE '[0-9]+' | head -1 || echo 0)
func_fail=${func_fail:-0}
[ "$func_fail" -eq 0 ] || { echo "FUNCTIONAL SUITE FAILED"; exit 1; }
func_pass=$(echo "$func_out" | count_matches '\\[PASS\\]')
echo "functional $func_pass" >> "$BASELINE_RUN"

echo "=== [5/90] Atomic transaction suite ==="
run_step atomic_out atomic_rc ./tests/test_atomic_txn.sh
[ "$atomic_rc" -eq 0 ] || { echo "ATOMIC (rc=$atomic_rc)"; echo "$atomic_out" | tail -5; exit 1; }
atomic_pass=$(echo "$atomic_out" | count_matches '\\[0;32mPASS')
atomic_fail=$(echo "$atomic_out" | count_matches '\\[0;31mFAIL')
echo "atomic: $atomic_pass passed, $atomic_fail failed"
echo "atomic $atomic_pass" >> "$BASELINE_RUN"
[ "$atomic_fail" -eq 0 ] || { echo "ATOMIC SUITE FAILED"; exit 1; }

echo "=== [6/90] Ledger atomic suite ==="
run_step ledger_out ledger_rc ./tests/test_ledger_atomic.sh
[ "$ledger_rc" -eq 0 ] || { echo "LEDGER (rc=$ledger_rc)"; echo "$ledger_out" | tail -5; exit 1; }
ledger_pass=$(echo "$ledger_out" | count_matches '\\[0;32mPASS')
ledger_fail=$(echo "$ledger_out" | count_matches '\\[0;31mFAIL')
echo "ledger: $ledger_pass passed, $ledger_fail failed"
echo "ledger-atomic $ledger_pass" >> "$BASELINE_RUN"
[ "$ledger_fail" -eq 0 ] || { echo "LEDGER SUITE FAILED"; exit 1; }

echo "=== [7/90] Reconciliation suite ==="
run_step recon_out recon_rc ./tests/test_reconciliation.sh
[ "$recon_rc" -eq 0 ] || { echo "RECONCILIATION (rc=$recon_rc)"; echo "$recon_out" | tail -5; exit 1; }
recon_pass=$(echo "$recon_out" | count_matches '\\[0;32mPASS')
recon_fail=$(echo "$recon_out" | count_matches '\\[0;31mFAIL')
echo "reconciliation: $recon_pass passed, $recon_fail failed"
echo "reconciliation $recon_pass" >> "$BASELINE_RUN"
[ "$recon_fail" -eq 0 ] || { echo "RECONCILIATION SUITE FAILED"; exit 1; }

echo "=== [8/90] Auth login suite ==="
run_step auth_out auth_rc ./tests/test_auth_login.sh
[ "$auth_rc" -eq 0 ] || { echo "AUTH (rc=$auth_rc)"; echo "$auth_out" | tail -5; exit 1; }
auth_pass=$(echo "$auth_out" | count_matches '\\[0;32mPASS')
auth_fail=$(echo "$auth_out" | count_matches '\\[0;31mFAIL')
echo "auth: $auth_pass passed, $auth_fail failed"
echo "auth-login $auth_pass" >> "$BASELINE_RUN"
[ "$auth_fail" -eq 0 ] || { echo "AUTH SUITE FAILED"; exit 1; }

echo "=== [9/90] Signup + verify suite ==="
run_step signup_out signup_rc ./tests/test_signup_verify.sh
[ "$signup_rc" -eq 0 ] || { echo "SIGNUP (rc=$signup_rc)"; echo "$signup_out" | tail -5; exit 1; }
signup_pass=$(echo "$signup_out" | count_matches '\\[0;32mPASS')
signup_fail=$(echo "$signup_out" | count_matches '\\[0;31mFAIL')
echo "signup/verify: $signup_pass passed, $signup_fail failed"
echo "signup-verify $signup_pass" >> "$BASELINE_RUN"
[ "$signup_fail" -eq 0 ] || { echo "SIGNUP SUITE FAILED"; exit 1; }

echo "=== [10/90] Role suite ==="
run_step role_out role_rc ./tests/test_roles.sh
[ "$role_rc" -eq 0 ] || { echo "ROLE (rc=$role_rc)"; echo "$role_out" | tail -5; exit 1; }
role_pass=$(echo "$role_out" | count_matches '\\[0;32mPASS')
role_fail=$(echo "$role_out" | count_matches '\\[0;31mFAIL')
echo "roles: $role_pass passed, $role_fail failed"
echo "roles $role_pass" >> "$BASELINE_RUN"
[ "$role_fail" -eq 0 ] || { echo "ROLE SUITE FAILED"; exit 1; }

echo "=== [11/90] User profile suite ==="
run_step profile_out profile_rc ./tests/test_user_profile.sh
[ "$profile_rc" -eq 0 ] || { echo "PROFILE (rc=$profile_rc)"; echo "$profile_out" | tail -5; exit 1; }
profile_pass=$(echo "$profile_out" | count_matches '\\[0;32mPASS')
profile_fail=$(echo "$profile_out" | count_matches '\\[0;31mFAIL')
echo "profile: $profile_pass passed, $profile_fail failed"
echo "user-profile $profile_pass" >> "$BASELINE_RUN"
[ "$profile_fail" -eq 0 ] || { echo "PROFILE SUITE FAILED"; exit 1; }

echo "=== [12/90] API gateway suite ==="
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

echo "=== [13/90] Login lockout suite ==="
run_step lockout_out lockout_rc ./tests/test_login_lockout.sh
[ "$lockout_rc" -eq 0 ] || { echo "LOCKOUT (rc=$lockout_rc)"; echo "$lockout_out" | tail -5; exit 1; }
lockout_pass=$(echo "$lockout_out" | count_matches '\\[0;32mPASS')
lockout_fail=$(echo "$lockout_out" | count_matches '\\[0;31mFAIL')
echo "lockout: $lockout_pass passed, $lockout_fail failed"
echo "lockout $lockout_pass" >> "$BASELINE_RUN"
[ "$lockout_fail" -eq 0 ] || { echo "LOCKOUT SUITE FAILED"; exit 1; }

echo "=== [14/90] Idempotent transfer suite ==="
run_step idem_out idem_rc ./tests/test_idempotent_transfer.sh
[ "$idem_rc" -eq 0 ] || { echo "IDEMPOTENT (rc=$idem_rc)"; echo "$idem_out" | tail -5; exit 1; }
idem_pass=$(echo "$idem_out" | count_matches '\\[0;32mPASS')
idem_fail=$(echo "$idem_out" | count_matches '\\[0;31mFAIL')
echo "idempotent transfer: $idem_pass passed, $idem_fail failed"
echo "idempotent-transfer $idem_pass" >> "$BASELINE_RUN"
[ "$idem_fail" -eq 0 ] || { echo "IDEMPOTENT SUITE FAILED"; exit 1; }

echo "=== [15/90] Transfer validity suite ==="
run_step validity_out validity_rc ./tests/test_transfer_validity.sh
[ "$validity_rc" -eq 0 ] || { echo "TRANSFER VALIDITY (rc=$validity_rc)"; echo "$validity_out" | tail -5; exit 1; }
validity_pass=$(echo "$validity_out" | count_matches '\\[0;32mPASS')
validity_fail=$(echo "$validity_out" | count_matches '\\[0;31mFAIL')
echo "transfer validity: $validity_pass passed, $validity_fail failed"
echo "transfer-validity $validity_pass" >> "$BASELINE_RUN"
[ "$validity_fail" -eq 0 ] || { echo "TRANSFER VALIDITY SUITE FAILED"; exit 1; }

echo "=== [16/90] Concurrent opposing transfers ==="
run_step conc_out conc_rc ./tests/test_concurrent_transfer.sh
[ "$conc_rc" -eq 0 ] || { echo "CONCURRENT (rc=$conc_rc)"; echo "$conc_out" | tail -5; exit 1; }
conc_pass=$(echo "$conc_out" | count_matches '\\[0;32mPASS')
conc_fail=$(echo "$conc_out" | count_matches '\\[0;31mFAIL')
echo "concurrent transfer: $conc_pass passed, $conc_fail failed"
echo "concurrent $conc_pass" >> "$BASELINE_RUN"
[ "$conc_fail" -eq 0 ] || { echo "CONCURRENT SUITE FAILED"; exit 1; }

echo "=== [17/90] SQL injection mitigation suite ==="
run_step inj_out inj_rc ./tests/test_injection.sh
[ "$inj_rc" -eq 0 ] || { echo "INJECTION (rc=$inj_rc)"; echo "$inj_out" | tail -5; exit 1; }
inj_pass=$(echo "$inj_out" | count_matches '\\[0;32mPASS')
inj_fail=$(echo "$inj_out" | count_matches '\\[0;31mFAIL')
echo "injection: $inj_pass passed, $inj_fail failed"
echo "injection $inj_pass" >> "$BASELINE_RUN"
[ "$inj_fail" -eq 0 ] || { echo "INJECTION SUITE FAILED"; exit 1; }

echo "=== [18/90] Refresh session suite ==="
run_step sess_out sess_rc ./tests/test_session.sh
[ "$sess_rc" -eq 0 ] || { echo "SESSION (rc=$sess_rc)"; echo "$sess_out" | tail -5; exit 1; }
sess_pass=$(echo "$sess_out" | count_matches '\\[0;32mPASS')
sess_fail=$(echo "$sess_out" | count_matches '\\[0;31mFAIL')
echo "session: $sess_pass passed, $sess_fail failed"
echo "session $sess_pass" >> "$BASELINE_RUN"
[ "$sess_fail" -eq 0 ] || { echo "SESSION SUITE FAILED"; exit 1; }

echo "=== [19/90] Prepared statement suite ==="
run_step prep_out prep_rc ./tests/test_prepared.sh
[ "$prep_rc" -eq 0 ] || { echo "PREPARED (rc=$prep_rc)"; echo "$prep_out" | tail -5; exit 1; }
prep_pass=$(echo "$prep_out" | count_matches '\\[0;32mPASS')
prep_fail=$(echo "$prep_out" | count_matches '\\[0;31mFAIL')
echo "prepared: $prep_pass passed, $prep_fail failed"
echo "prepared $prep_pass" >> "$BASELINE_RUN"
[ "$prep_fail" -eq 0 ] || { echo "PREPARED SUITE FAILED"; exit 1; }

echo "=== [20/90] Deep health (PING) suite ==="
run_step ping_out ping_rc ./tests/test_ping.sh
[ "$ping_rc" -eq 0 ] || { echo "PING (rc=$ping_rc)"; echo "$ping_out" | tail -5; exit 1; }
ping_pass=$(echo "$ping_out" | count_matches '\\[0;32mPASS')
ping_fail=$(echo "$ping_out" | count_matches '\\[0;31mFAIL')
echo "ping: $ping_pass passed, $ping_fail failed"
echo "ping $ping_pass" >> "$BASELINE_RUN"
[ "$ping_fail" -eq 0 ] || { echo "PING SUITE FAILED"; exit 1; }

echo "=== [21/90] Migration check ==="
./database/migrate.sh --check

echo "=== [22/90] Migration tooling suite ==="
run_step mig_out mig_rc ./tests/test_migrate.sh
[ "$mig_rc" -eq 0 ] || { echo "MIGRATION (rc=$mig_rc)"; echo "$mig_out" | tail -5; exit 1; }
mig_pass=$(echo "$mig_out" | count_matches '\\[0;32mPASS')
mig_fail=$(echo "$mig_out" | count_matches '\\[0;31mFAIL')
echo "migrations: $mig_pass passed, $mig_fail failed"
echo "migrate $mig_pass" >> "$BASELINE_RUN"
[ "$mig_fail" -eq 0 ] || { echo "MIGRATION SUITE FAILED"; exit 1; }

echo "=== [23/90] Status/docs integrity ==="
./tests/status_check.sh
./tests/traceability_check.sh

echo "=== [24/90] End-to-end HTTP smoke ==="
run_step e2e_out e2e_rc ./tests/test_e2e_gateway.sh
[ "$e2e_rc" -eq 0 ] || { echo "E2E (rc=$e2e_rc)"; echo "$e2e_out" | tail -5; exit 1; }
e2e_pass=$(echo "$e2e_out" | count_matches '\\[0;32mPASS')
e2e_fail=$(echo "$e2e_out" | count_matches '\\[0;31mFAIL')
echo "e2e: $e2e_pass passed, $e2e_fail failed"
echo "e2e $e2e_pass" >> "$BASELINE_RUN"
[ "$e2e_fail" -eq 0 ] || { echo "E2E SUITE FAILED"; exit 1; }

echo "=== [25/90] Serve mode suite ==="
run_step serve_out serve_rc ./tests/test_serve_mode.sh
[ "$serve_rc" -eq 0 ] || { echo "SERVE MODE (rc=$serve_rc)"; echo "$serve_out" | tail -5; exit 1; }
serve_pass=$(echo "$serve_out" | count_matches '\\[0;32mPASS')
serve_fail=$(echo "$serve_out" | count_matches '\\[0;31mFAIL')
echo "serve: $serve_pass passed, $serve_fail failed"
echo "serve $serve_pass" >> "$BASELINE_RUN"
[ "$serve_fail" -eq 0 ] || { echo "SERVE MODE SUITE FAILED"; exit 1; }

echo "=== [26/90] End-to-end HTTP smoke (pool mode) ==="
run_step pool_out pool_rc env COBOL_POOL_SIZE=4 ./tests/test_e2e_gateway.sh
[ "$pool_rc" -eq 0 ] || { echo "E2E POOL (rc=$pool_rc)"; echo "$pool_out" | tail -5; exit 1; }
pool_pass=$(echo "$pool_out" | count_matches '\\[0;32mPASS')
pool_fail=$(echo "$pool_out" | count_matches '\\[0;31mFAIL')
echo "e2e pool: $pool_pass passed, $pool_fail failed"
echo "e2e-pool $pool_pass" >> "$BASELINE_RUN"
[ "$pool_fail" -eq 0 ] || { echo "E2E POOL SUITE FAILED"; exit 1; }

echo "=== [27/90] Password reset/change suite ==="
run_step pw_out pw_rc ./tests/test_password.sh
[ "$pw_rc" -eq 0 ] || { echo "PASSWORD (rc=$pw_rc)"; echo "$pw_out" | tail -5; exit 1; }
pw_pass=$(echo "$pw_out" | count_matches '\\[0;32mPASS')
pw_fail=$(echo "$pw_out" | count_matches '\\[0;31mFAIL')
echo "password: $pw_pass passed, $pw_fail failed"
echo "password $pw_pass" >> "$BASELINE_RUN"
[ "$pw_fail" -eq 0 ] || { echo "PASSWORD SUITE FAILED"; exit 1; }

echo "=== [28/90] Verification attempt cap suite ==="
run_step cap_out cap_rc ./tests/test_verify_cap.sh
[ "$cap_rc" -eq 0 ] || { echo "VERIFY CAP (rc=$cap_rc)"; echo "$cap_out" | tail -5; exit 1; }
cap_pass=$(echo "$cap_out" | count_matches '\\[0;32mPASS')
cap_fail=$(echo "$cap_out" | count_matches '\\[0;31mFAIL')
echo "verify-cap: $cap_pass passed, $cap_fail failed"
echo "verify-cap $cap_pass" >> "$BASELINE_RUN"
[ "$cap_fail" -eq 0 ] || { echo "VERIFY CAP SUITE FAILED"; exit 1; }

echo "=== [29/90] Password KDF suite ==="
run_step kdf_out kdf_rc ./tests/test_password_kdf.sh
[ "$kdf_rc" -eq 0 ] || { echo "KDF (rc=$kdf_rc)"; echo "$kdf_out" | tail -5; exit 1; }
kdf_pass=$(echo "$kdf_out" | count_matches '\\[0;32mPASS')
kdf_fail=$(echo "$kdf_out" | count_matches '\\[0;31mFAIL')
echo "kdf: $kdf_pass passed, $kdf_fail failed"
echo "kdf $kdf_pass" >> "$BASELINE_RUN"
[ "$kdf_fail" -eq 0 ] || { echo "KDF SUITE FAILED"; exit 1; }

echo "=== [30/90] MFA (TOTP) suite ==="
run_step mfa_out mfa_rc ./tests/test_mfa.sh
[ "$mfa_rc" -eq 0 ] || { echo "MFA (rc=$mfa_rc)"; echo "$mfa_out" | tail -5; exit 1; }
mfa_pass=$(echo "$mfa_out" | count_matches '\\[0;32mPASS')
mfa_fail=$(echo "$mfa_out" | count_matches '\\[0;31mFAIL')
echo "mfa: $mfa_pass passed, $mfa_fail failed"
echo "mfa $mfa_pass" >> "$BASELINE_RUN"
[ "$mfa_fail" -eq 0 ] || { echo "MFA SUITE FAILED"; exit 1; }

echo "=== [31/90] Session management suite ==="
run_step sess_out sess_rc ./tests/test_sessions_manage.sh
[ "$sess_rc" -eq 0 ] || { echo "SESSION (rc=$sess_rc)"; echo "$sess_out" | tail -5; exit 1; }
sess_pass=$(echo "$sess_out" | count_matches '\\[0;32mPASS')
sess_fail=$(echo "$sess_out" | count_matches '\\[0;31mFAIL')
echo "sessions: $sess_pass passed, $sess_fail failed"
echo "sessions-manage $sess_pass" >> "$BASELINE_RUN"
[ "$sess_fail" -eq 0 ] || { echo "SESSION SUITE FAILED"; exit 1; }

echo "=== [32/90] Account status suite ==="
run_step stat_out stat_rc ./tests/test_account_status.sh
[ "$stat_rc" -eq 0 ] || { echo "ACCOUNT STATUS (rc=$stat_rc)"; echo "$stat_out" | tail -5; exit 1; }
stat_pass=$(echo "$stat_out" | count_matches '\\[0;32mPASS')
stat_fail=$(echo "$stat_out" | count_matches '\\[0;31mFAIL')
echo "account-status: $stat_pass passed, $stat_fail failed"
echo "account-status $stat_pass" >> "$BASELINE_RUN"
[ "$stat_fail" -eq 0 ] || { echo "ACCOUNT STATUS SUITE FAILED"; exit 1; }

echo "=== [33/90] Transfer limits suite ==="
run_step lim_out lim_rc ./tests/test_transfer_limits.sh
[ "$lim_rc" -eq 0 ] || { echo "TRANSFER LIMITS (rc=$lim_rc)"; echo "$lim_out" | tail -5; exit 1; }
lim_pass=$(echo "$lim_out" | count_matches '\\[0;32mPASS')
lim_fail=$(echo "$lim_out" | count_matches '\\[0;31mFAIL')
echo "limits: $lim_pass passed, $lim_fail failed"
echo "transfer-limits $lim_pass" >> "$BASELINE_RUN"
[ "$lim_fail" -eq 0 ] || { echo "TRANSFER LIMITS SUITE FAILED"; exit 1; }

echo "=== [34/90] Transfer reversal suite ==="
run_step rev_out rev_rc ./tests/test_transfer_reversal.sh
[ "$rev_rc" -eq 0 ] || { echo "REVERSAL (rc=$rev_rc)"; echo "$rev_out" | tail -5; exit 1; }
rev_pass=$(echo "$rev_out" | count_matches '\\[0;32mPASS')
rev_fail=$(echo "$rev_out" | count_matches '\\[0;31mFAIL')
echo "reversal: $rev_pass passed, $rev_fail failed"
echo "reversal $rev_pass" >> "$BASELINE_RUN"
[ "$rev_fail" -eq 0 ] || { echo "REVERSAL SUITE FAILED"; exit 1; }

echo "=== [35/90] Journal suite ==="
run_step journal_out journal_rc ./tests/test_journal.sh
[ "$journal_rc" -eq 0 ] || { echo "JOURNAL (rc=$journal_rc)"; echo "$journal_out" | tail -5; exit 1; }
journal_pass=$(echo "$journal_out" | count_matches '\\[0;32mPASS')
journal_fail=$(echo "$journal_out" | count_matches '\\[0;31mFAIL')
echo "journal: $journal_pass passed, $journal_fail failed"
echo "journal $journal_pass" >> "$BASELINE_RUN"
[ "$journal_fail" -eq 0 ] || { echo "JOURNAL SUITE FAILED"; exit 1; }

echo "=== [39/90] Holds and fees suite ==="
run_step holds_out holds_rc ./tests/test_holds.sh
[ "$holds_rc" -eq 0 ] || { echo "HOLDS (rc=$holds_rc)"; echo "$holds_out" | tail -5; exit 1; }
holds_pass=$(echo "$holds_out" | count_matches '\\[0;32mPASS')
holds_fail=$(echo "$holds_out" | count_matches '\\[0;31mFAIL')
echo "holds: $holds_pass passed, $holds_fail failed"
echo "holds $holds_pass" >> "$BASELINE_RUN"
[ "$holds_fail" -eq 0 ] || { echo "HOLDS SUITE FAILED"; exit 1; }

echo "=== [37/90] Dual control suite ==="
run_step dual_out dual_rc ./tests/test_dual_control.sh
[ "$dual_rc" -eq 0 ] || { echo "DUAL CONTROL (rc=$dual_rc)"; echo "$dual_out" | tail -5; exit 1; }
dual_pass=$(echo "$dual_out" | count_matches '\\[0;32mPASS')
dual_fail=$(echo "$dual_out" | count_matches '\\[0;31mFAIL')
echo "dual-control: $dual_pass passed, $dual_fail failed"
echo "dual-control $dual_pass" >> "$BASELINE_RUN"
[ "$dual_fail" -eq 0 ] || { echo "DUAL CONTROL SUITE FAILED"; exit 1; }

echo "=== [38/90] Outbox suite ==="
run_step outbox_out outbox_rc ./tests/test_outbox.sh
[ "$outbox_rc" -eq 0 ] || { echo "OUTBOX (rc=$outbox_rc)"; echo "$outbox_out" | tail -5; exit 1; }
outbox_pass=$(echo "$outbox_out" | count_matches '\\[0;32mPASS')
outbox_fail=$(echo "$outbox_out" | count_matches '\\[0;31mFAIL')
echo "outbox: $outbox_pass passed, $outbox_fail failed"
echo "outbox $outbox_pass" >> "$BASELINE_RUN"
[ "$outbox_fail" -eq 0 ] || { echo "OUTBOX SUITE FAILED"; exit 1; }

echo "=== [36/90] Reconciliation runs suite ==="
run_step reconruns_out reconruns_rc ./tests/test_reconciliation_runs.sh
[ "$reconruns_rc" -eq 0 ] || { echo "RECONCILIATION RUNS (rc=$reconruns_rc)"; echo "$reconruns_out" | tail -5; exit 1; }
reconruns_pass=$(echo "$reconruns_out" | count_matches '\\[0;32mPASS')
reconruns_fail=$(echo "$reconruns_out" | count_matches '\\[0;31mFAIL')
echo "recon-runs: $reconruns_pass passed, $reconruns_fail failed"
echo "recon-runs $reconruns_pass" >> "$BASELINE_RUN"
[ "$reconruns_fail" -eq 0 ] || { echo "RECONCILIATION RUNS SUITE FAILED"; exit 1; }

echo "=== [40/90] Wallet observability suite ==="
run_step obs_out obs_rc ./tests/test_wallet_observability.sh
[ "$obs_rc" -eq 0 ] || { echo "OBSERVABILITY (rc=$obs_rc)"; echo "$obs_out" | tail -5; exit 1; }
obs_pass=$(echo "$obs_out" | count_matches '\\[0;32mPASS')
obs_fail=$(echo "$obs_out" | count_matches '\\[0;31mFAIL')
echo "observability: $obs_pass passed, $obs_fail failed"
echo "observability $obs_pass" >> "$BASELINE_RUN"
[ "$obs_fail" -eq 0 ] || { echo "OBSERVABILITY SUITE FAILED"; exit 1; }

echo "=== [41/90] Account lifecycle suite ==="
run_step lc_out lc_rc ./tests/test_account_lifecycle.sh
[ "$lc_rc" -eq 0 ] || { echo "ACCOUNT LIFECYCLE (rc=$lc_rc)"; echo "$lc_out" | tail -5; exit 1; }
lc_pass=$(echo "$lc_out" | count_matches '\\[0;32mPASS')
lc_fail=$(echo "$lc_out" | count_matches '\\[0;31mFAIL')
echo "lifecycle: $lc_pass passed, $lc_fail failed"
echo "lifecycle $lc_pass" >> "$BASELINE_RUN"
[ "$lc_fail" -eq 0 ] || { echo "ACCOUNT LIFECYCLE SUITE FAILED"; exit 1; }

echo "=== [42/90] Token rotation suite ==="
run_step rot_out rot_rc ./tests/test_token_rotation.sh
[ "$rot_rc" -eq 0 ] || { echo "TOKEN ROTATION (rc=$rot_rc)"; echo "$rot_out" | tail -5; exit 1; }
rot_pass=$(echo "$rot_out" | count_matches '\\[0;32mPASS')
rot_fail=$(echo "$rot_out" | count_matches '\\[0;31mFAIL')
echo "rotation: $rot_pass passed, $rot_fail failed"
echo "rotation $rot_pass" >> "$BASELINE_RUN"
[ "$rot_fail" -eq 0 ] || { echo "TOKEN ROTATION SUITE FAILED"; exit 1; }

echo "=== [43/90] Admin role-hierarchy suite ==="
run_step hier_out hier_rc ./tests/test_admin_hierarchy.sh
[ "$hier_rc" -eq 0 ] || { echo "ADMIN HIERARCHY (rc=$hier_rc)"; echo "$hier_out" | tail -5; exit 1; }
hier_pass=$(echo "$hier_out" | count_matches '\\[0;32mPASS')
hier_fail=$(echo "$hier_out" | count_matches '\\[0;31mFAIL')
echo "hierarchy: $hier_pass passed, $hier_fail failed"
echo "admin-hierarchy $hier_pass" >> "$BASELINE_RUN"
[ "$hier_fail" -eq 0 ] || { echo "ADMIN HIERARCHY SUITE FAILED"; exit 1; }

echo "=== [44/90] Last-admin protection suite ==="
run_step la_out la_rc ./tests/test_last_admin.sh
[ "$la_rc" -eq 0 ] || { echo "LAST-ADMIN (rc=$la_rc)"; echo "$la_out" | tail -5; exit 1; }
la_pass=$(echo "$la_out" | count_matches '\\[0;32mPASS')
la_fail=$(echo "$la_out" | count_matches '\\[0;31mFAIL')
echo "last-admin: $la_pass passed, $la_fail failed"
echo "last-admin $la_pass" >> "$BASELINE_RUN"
[ "$la_fail" -eq 0 ] || { echo "LAST-ADMIN SUITE FAILED"; exit 1; }

echo "=== [45/90] Audit actor-attribution suite ==="
run_step aa_out aa_rc ./tests/test_audit_actor.sh
[ "$aa_rc" -eq 0 ] || { echo "AUDIT ACTOR (rc=$aa_rc)"; echo "$aa_out" | tail -5; exit 1; }
aa_pass=$(echo "$aa_out" | count_matches '\\[0;32mPASS')
aa_fail=$(echo "$aa_out" | count_matches '\\[0;31mFAIL')
echo "audit-actor: $aa_pass passed, $aa_fail failed"
echo "audit-actor $aa_pass" >> "$BASELINE_RUN"
[ "$aa_fail" -eq 0 ] || { echo "AUDIT ACTOR SUITE FAILED"; exit 1; }

echo "=== [46/90] Audit read suite ==="
run_step ar_out ar_rc ./tests/test_audit_read.sh
[ "$ar_rc" -eq 0 ] || { echo "AUDIT READ (rc=$ar_rc)"; echo "$ar_out" | tail -5; exit 1; }
ar_pass=$(echo "$ar_out" | count_matches '\\[0;32mPASS')
ar_fail=$(echo "$ar_out" | count_matches '\\[0;31mFAIL')
echo "audit-read: $ar_pass passed, $ar_fail failed"
echo "audit-read $ar_pass" >> "$BASELINE_RUN"
[ "$ar_fail" -eq 0 ] || { echo "AUDIT READ SUITE FAILED"; exit 1; }

echo "=== [47/90] Audit integrity suite ==="
run_step ai_out ai_rc ./tests/test_audit_integrity.sh
[ "$ai_rc" -eq 0 ] || { echo "AUDIT INTEGRITY (rc=$ai_rc)"; echo "$ai_out" | tail -5; exit 1; }
ai_pass=$(echo "$ai_out" | count_matches '\\[0;32mPASS')
ai_fail=$(echo "$ai_out" | count_matches '\\[0;31mFAIL')
echo "audit-integrity: $ai_pass passed, $ai_fail failed"
echo "audit-integrity $ai_pass" >> "$BASELINE_RUN"
[ "$ai_fail" -eq 0 ] || { echo "AUDIT INTEGRITY SUITE FAILED"; exit 1; }

echo "=== [48/90] Admin recovery suite ==="
run_step ar2_out ar2_rc ./tests/test_admin_recovery.sh
[ "$ar2_rc" -eq 0 ] || { echo "ADMIN RECOVERY (rc=$ar2_rc)"; echo "$ar2_out" | tail -5; exit 1; }
ar2_pass=$(echo "$ar2_out" | count_matches '\\[0;32mPASS')
ar2_fail=$(echo "$ar2_out" | count_matches '\\[0;31mFAIL')
echo "admin-recovery: $ar2_pass passed, $ar2_fail failed"
echo "admin-recovery $ar2_pass" >> "$BASELINE_RUN"
[ "$ar2_fail" -eq 0 ] || { echo "ADMIN RECOVERY SUITE FAILED"; exit 1; }

echo "=== [49/90] Step-up (re-authentication) suite ==="
run_step su_out su_rc ./tests/test_stepup.sh
[ "$su_rc" -eq 0 ] || { echo "STEP-UP (rc=$su_rc)"; echo "$su_out" | tail -5; exit 1; }
su_pass=$(echo "$su_out" | count_matches '\\[0;32mPASS')
su_fail=$(echo "$su_out" | count_matches '\\[0;31mFAIL')
echo "step-up: $su_pass passed, $su_fail failed"
echo "step-up $su_pass" >> "$BASELINE_RUN"
[ "$su_fail" -eq 0 ] || { echo "STEP-UP SUITE FAILED"; exit 1; }

echo "=== [50/90] MFA-state suite ==="
run_step ms_out ms_rc ./tests/test_mfa_state.sh
[ "$ms_rc" -eq 0 ] || { echo "MFA STATE (rc=$ms_rc)"; echo "$ms_out" | tail -5; exit 1; }
ms_pass=$(echo "$ms_out" | count_matches '\\[0;32mPASS')
ms_fail=$(echo "$ms_out" | count_matches '\\[0;31mFAIL')
echo "mfa-state: $ms_pass passed, $ms_fail failed"
echo "mfa-state $ms_pass" >> "$BASELINE_RUN"
[ "$ms_fail" -eq 0 ] || { echo "MFA STATE SUITE FAILED"; exit 1; }

echo "=== [51/90] MFA recovery suite ==="
run_step mfar_out mfar_rc ./tests/test_mfa_recovery.sh
[ "$mfar_rc" -eq 0 ] || { echo "MFA RECOVERY (rc=$mfar_rc)"; echo "$mfar_out" | tail -5; exit 1; }
mfar_pass=$(echo "$mfar_out" | count_matches '\\[0;32mPASS')
mfar_fail=$(echo "$mfar_out" | count_matches '\\[0;31mFAIL')
echo "mfa-recovery: $mfar_pass passed, $mfar_fail failed"
echo "mfa-recovery $mfar_pass" >> "$BASELINE_RUN"
[ "$mfar_fail" -eq 0 ] || { echo "MFA RECOVERY SUITE FAILED"; exit 1; }

echo "=== [52/90] Statements suite ==="
run_step stmt_out stmt_rc ./tests/test_statements.sh
[ "$stmt_rc" -eq 0 ] || { echo "STATEMENTS (rc=$stmt_rc)"; echo "$stmt_out" | tail -5; exit 1; }
stmt_pass=$(echo "$stmt_out" | count_matches '\\[0;32mPASS')
stmt_fail=$(echo "$stmt_out" | count_matches '\\[0;31mFAIL')
echo "statements: $stmt_pass passed, $stmt_fail failed"
echo "statements $stmt_pass" >> "$BASELINE_RUN"
[ "$stmt_fail" -eq 0 ] || { echo "STATEMENTS SUITE FAILED"; exit 1; }

echo "=== [53/90] Disputes suite ==="
run_step dsp_out dsp_rc ./tests/test_disputes.sh
[ "$dsp_rc" -eq 0 ] || { echo "DISPUTES (rc=$dsp_rc)"; echo "$dsp_out" | tail -5; exit 1; }
dsp_pass=$(echo "$dsp_out" | count_matches '\\[0;32mPASS')
dsp_fail=$(echo "$dsp_out" | count_matches '\\[0;31mFAIL')
echo "disputes: $dsp_pass passed, $dsp_fail failed"
echo "disputes $dsp_pass" >> "$BASELINE_RUN"
[ "$dsp_fail" -eq 0 ] || { echo "DISPUTES SUITE FAILED"; exit 1; }

echo "=== [54/90] Backup/restore suite ==="
run_step bkr_out bkr_rc ./tests/test_backup_restore.sh
[ "$bkr_rc" -eq 0 ] || { echo "BACKUP RESTORE (rc=$bkr_rc)"; echo "$bkr_out" | tail -5; exit 1; }
bkr_pass=$(echo "$bkr_out" | count_matches '\\[0;32mPASS')
bkr_fail=$(echo "$bkr_out" | count_matches '\\[0;31mFAIL')
echo "backup_restore: $bkr_pass passed, $bkr_fail failed"
echo "backup_restore $bkr_pass" >> "$BASELINE_RUN"
[ "$bkr_fail" -eq 0 ] || { echo "BACKUP RESTORE SUITE FAILED"; exit 1; }

echo "=== [55/90] Ledger integrity suite ==="
run_step li_out li_rc ./tests/test_ledger_integrity.sh
[ "$li_rc" -eq 0 ] || { echo "LEDGER INTEGRITY (rc=$li_rc)"; echo "$li_out" | tail -5; exit 1; }
li_pass=$(echo "$li_out" | count_matches '\\[0;32mPASS')
li_fail=$(echo "$li_out" | count_matches '\\[0;31mFAIL')
echo "ledger-integrity: $li_pass passed, $li_fail failed"
echo "ledger-integrity $li_pass" >> "$BASELINE_RUN"
[ "$li_fail" -eq 0 ] || { echo "LEDGER INTEGRITY SUITE FAILED"; exit 1; }

echo "=== [56/90] RNG (CSPRNG) suite ==="
run_step rng_out rng_rc ./tests/test_rng.sh
[ "$rng_rc" -eq 0 ] || { echo "RNG (rc=$rng_rc)"; echo "$rng_out" | tail -5; exit 1; }
rng_pass=$(echo "$rng_out" | count_matches '\\[0;32mPASS')
rng_fail=$(echo "$rng_out" | count_matches '\\[0;31mFAIL')
echo "rng: $rng_pass passed, $rng_fail failed"
echo "rng $rng_pass" >> "$BASELINE_RUN"
[ "$rng_fail" -eq 0 ] || { echo "RNG SUITE FAILED"; exit 1; }

echo "=== [57/90] Least-privilege database suite ==="
run_step gr_out gr_rc ./tests/test_grants.sh
[ "$gr_rc" -eq 0 ] || { echo "GRANTS (rc=$gr_rc)"; echo "$gr_out" | tail -5; exit 1; }
gr_pass=$(echo "$gr_out" | count_matches '\\[0;32mPASS')
gr_fail=$(echo "$gr_out" | count_matches '\\[0;31mFAIL')
echo "grants: $gr_pass passed, $gr_fail failed"
echo "grants $gr_pass" >> "$BASELINE_RUN"
[ "$gr_fail" -eq 0 ] || { echo "GRANTS SUITE FAILED"; exit 1; }

echo "=== [58/90] Resend cooldown suite ==="
run_step rc_out rc_rc ./tests/test_resend_cooldown.sh
[ "$rc_rc" -eq 0 ] || { echo "RESEND COOLDOWN (rc=$rc_rc)"; echo "$rc_out" | tail -5; exit 1; }
rc_pass=$(echo "$rc_out" | count_matches '\\[0;32mPASS')
rc_fail=$(echo "$rc_out" | count_matches '\\[0;31mFAIL')
echo "resend-cooldown: $rc_pass passed, $rc_fail failed"
echo "resend-cooldown $rc_pass" >> "$BASELINE_RUN"
[ "$rc_fail" -eq 0 ] || { echo "RESEND COOLDOWN SUITE FAILED"; exit 1; }

echo "=== [59/90] C memory-boundary suite ==="
run_step cm_out cm_rc ./tests/test_c_memory.sh
[ "$cm_rc" -eq 0 ] || { echo "C MEMORY (rc=$cm_rc)"; echo "$cm_out" | tail -5; exit 1; }
cm_pass=$(echo "$cm_out" | count_matches '\\[0;32mPASS')
cm_fail=$(echo "$cm_out" | count_matches '\\[0;31mFAIL')
echo "c-memory: $cm_pass passed, $cm_fail failed"
echo "c-memory $cm_pass" >> "$BASELINE_RUN"
[ "$cm_fail" -eq 0 ] || { echo "C MEMORY SUITE FAILED"; exit 1; }

echo "=== [60/90] Bridge transaction suite ==="
run_step bt_out bt_rc ./tests/test_bridge_txn.sh
[ "$bt_rc" -eq 0 ] || { echo "BRIDGE TXN (rc=$bt_rc)"; echo "$bt_out" | tail -5; exit 1; }
bt_pass=$(echo "$bt_out" | count_matches '\\[0;32mPASS')
bt_fail=$(echo "$bt_out" | count_matches '\\[0;31mFAIL')
echo "bridge-txn: $bt_pass passed, $bt_fail failed"
echo "bridge-txn $bt_pass" >> "$BASELINE_RUN"
[ "$bt_fail" -eq 0 ] || { echo "BRIDGE TXN SUITE FAILED"; exit 1; }

echo "=== [61/90] Buffer contract check ==="
./tests/buffer_contract_check.sh

echo "=== [62/90] Seed idempotency suite ==="
run_step seed_out seed_rc ./tests/test_seed.sh
[ "$seed_rc" -eq 0 ] || { echo "SEED (rc=$seed_rc)"; echo "$seed_out" | tail -5; exit 1; }
seed_pass=$(echo "$seed_out" | count_matches '\\[0;32mPASS')
seed_fail=$(echo "$seed_out" | count_matches '\\[0;31mFAIL')
echo "seed: $seed_pass passed, $seed_fail failed"
echo "seed $seed_pass" >> "$BASELINE_RUN"
[ "$seed_fail" -eq 0 ] || { echo "SEED SUITE FAILED"; exit 1; }

echo "=== [63/90] Env coverage check ==="
./tests/env_check.sh

echo "=== [64/90] Dependency audit ==="
if npm --prefix middleware audit --omit=dev --audit-level=high > /tmp/opencode/dep_audit.out 2>&1; then
    tail -3 /tmp/opencode/dep_audit.out
    echo "dependency audit clean (high/critical)"
else
    tail -5 /tmp/opencode/dep_audit.out
    echo "DEPENDENCY AUDIT FAILED: resolve or record an exception per docs/patch-policy.md"
    exit 1
fi

echo "=== [65/90] Git hook hygiene suite ==="
run_step hk_out hk_rc ./tests/test_hooks.sh
[ "$hk_rc" -eq 0 ] || { echo "HOOKS (rc=$hk_rc)"; echo "$hk_out" | tail -5; exit 1; }
hk_pass=$(echo "$hk_out" | count_matches '\\[0;32mPASS')
hk_fail=$(echo "$hk_out" | count_matches '\\[0;31mFAIL')
echo "hooks: $hk_pass passed, $hk_fail failed"
echo "hooks $hk_pass" >> "$BASELINE_RUN"
[ "$hk_fail" -eq 0 ] || { echo "HOOKS SUITE FAILED"; exit 1; }

echo "=== [66/90] Control-account uniqueness suite ==="
run_step ctl_out ctl_rc ./tests/test_control_accounts.sh
[ "$ctl_rc" -eq 0 ] || { echo "CONTROL ACCOUNTS (rc=$ctl_rc)"; echo "$ctl_out" | tail -5; exit 1; }
ctl_pass=$(echo "$ctl_out" | count_matches '\\[0;32mPASS')
ctl_fail=$(echo "$ctl_out" | count_matches '\\[0;31mFAIL')
echo "control-accounts: $ctl_pass passed, $ctl_fail failed"
echo "control-accounts $ctl_pass" >> "$BASELINE_RUN"
[ "$ctl_fail" -eq 0 ] || { echo "CONTROL ACCOUNTS SUITE FAILED"; exit 1; }

echo "=== [67/90] Access review suite ==="
run_step ar_out ar_rc ./tests/test_access_reviews.sh
[ "$ar_rc" -eq 0 ] || { echo "ACCESS REVIEWS (rc=$ar_rc)"; echo "$ar_out" | tail -5; exit 1; }
ar_pass=$(echo "$ar_out" | count_matches '\\[0;32mPASS')
ar_fail=$(echo "$ar_out" | count_matches '\\[0;31mFAIL')
echo "access-reviews: $ar_pass passed, $ar_fail failed"
echo "access-reviews $ar_pass" >> "$BASELINE_RUN"
[ "$ar_fail" -eq 0 ] || { echo "ACCESS REVIEWS SUITE FAILED"; exit 1; }

echo "=== [68/90] Scoped permission suite ==="
run_step perm_out perm_rc ./tests/test_permissions.sh
[ "$perm_rc" -eq 0 ] || { echo "PERMISSIONS (rc=$perm_rc)"; echo "$perm_out" | tail -5; exit 1; }
perm_pass=$(echo "$perm_out" | count_matches '\\[0;32mPASS')
perm_fail=$(echo "$perm_out" | count_matches '\\[0;31mFAIL')
echo "permissions: $perm_pass passed, $perm_fail failed"
echo "permissions $perm_pass" >> "$BASELINE_RUN"
[ "$perm_fail" -eq 0 ] || { echo "PERMISSIONS SUITE FAILED"; exit 1; }

echo "=== [69/90] Password policy suite ==="
run_step pwpol_out pwpol_rc ./tests/test_password_policy.sh
[ "$pwpol_rc" -eq 0 ] || { echo "PASSWORD POLICY (rc=$pwpol_rc)"; echo "$pwpol_out" | tail -5; exit 1; }
pwpol_pass=$(echo "$pwpol_out" | count_matches '\\[0;32mPASS')
pwpol_fail=$(echo "$pwpol_out" | count_matches '\\[0;31mFAIL')
echo "password-policy: $pwpol_pass passed, $pwpol_fail failed"
echo "password-policy $pwpol_pass" >> "$BASELINE_RUN"
[ "$pwpol_fail" -eq 0 ] || { echo "PASSWORD POLICY SUITE FAILED"; exit 1; }

echo "=== [70/90] Customer step-up policy suite ==="
run_step stepup_out stepup_rc ./tests/test_step_up_policy.sh
[ "$stepup_rc" -eq 0 ] || { echo "STEP-UP POLICY (rc=$stepup_rc)"; echo "$stepup_out" | tail -5; exit 1; }
stepup_pass=$(echo "$stepup_out" | count_matches '\\[0;32mPASS')
stepup_fail=$(echo "$stepup_out" | count_matches '\\[0;31mFAIL')
echo "step-up-policy: $stepup_pass passed, $stepup_fail failed"
echo "step-up-policy $stepup_pass" >> "$BASELINE_RUN"
[ "$stepup_fail" -eq 0 ] || { echo "STEP-UP POLICY SUITE FAILED"; exit 1; }

echo "=== [71/90] Dormant lifecycle suite ==="
run_step dorm_out dorm_rc ./tests/test_dormancy.sh
[ "$dorm_rc" -eq 0 ] || { echo "DORMANCY (rc=$dorm_rc)"; echo "$dorm_out" | tail -5; exit 1; }
dorm_pass=$(echo "$dorm_out" | count_matches '\\[0;32mPASS')
dorm_fail=$(echo "$dorm_out" | count_matches '\\[0;31mFAIL')
echo "dormancy: $dorm_pass passed, $dorm_fail failed"
echo "dormancy $dorm_pass" >> "$BASELINE_RUN"
[ "$dorm_fail" -eq 0 ] || { echo "DORMANCY SUITE FAILED"; exit 1; }

echo "=== [72/90] Session security suite ==="
run_step ss_out ss_rc ./tests/test_session_security.sh
[ "$ss_rc" -eq 0 ] || { echo "SESSION SECURITY (rc=$ss_rc)"; echo "$ss_out" | tail -5; exit 1; }
ss_pass=$(echo "$ss_out" | count_matches '\\[0;32mPASS')
ss_fail=$(echo "$ss_out" | count_matches '\\[0;31mFAIL')
echo "session-security: $ss_pass passed, $ss_fail failed"
echo "session-security $ss_pass" >> "$BASELINE_RUN"
[ "$ss_fail" -eq 0 ] || { echo "SESSION SECURITY SUITE FAILED"; exit 1; }

echo "=== [73/90] Reference engine suite ==="
run_step refeng_out refeng_rc ./tests/test_ref_engine.sh
[ "$refeng_rc" -eq 0 ] || { echo "REFERENCE ENGINE (rc=$refeng_rc)"; echo "$refeng_out" | tail -5; exit 1; }
refeng_pass=$(echo "$refeng_out" | count_matches '\\[0;32mPASS')
refeng_fail=$(echo "$refeng_out" | count_matches '\\[0;31mFAIL')
echo "ref-engine: $refeng_pass passed, $refeng_fail failed"
echo "ref_engine $refeng_pass" >> "$BASELINE_RUN"
[ "$refeng_fail" -eq 0 ] || { echo "REFERENCE ENGINE SUITE FAILED"; exit 1; }

echo "=== [74/90] General ledger suite ==="
run_step gl_out gl_rc ./tests/test_gl.sh
[ "$gl_rc" -eq 0 ] || { echo "GENERAL LEDGER (rc=$gl_rc)"; echo "$gl_out" | tail -5; exit 1; }
gl_pass=$(echo "$gl_out" | count_matches '\\[0;32mPASS')
gl_fail=$(echo "$gl_out" | count_matches '\\[0;31mFAIL')
echo "gl: $gl_pass passed, $gl_fail failed"
echo "gl $gl_pass" >> "$BASELINE_RUN"
[ "$gl_fail" -eq 0 ] || { echo "GENERAL LEDGER SUITE FAILED"; exit 1; }

echo "=== [75/90] Batch/EOD foundation suite ==="
run_step batch_out batch_rc ./tests/test_batch.sh
[ "$batch_rc" -eq 0 ] || { echo "BATCH/EOD (rc=$batch_rc)"; echo "$batch_out" | tail -5; exit 1; }
batch_pass=$(echo "$batch_out" | count_matches '\\[0;32mPASS')
batch_fail=$(echo "$batch_out" | count_matches '\\[0;31mFAIL')
echo "batch: $batch_pass passed, $batch_fail failed"
echo "batch $batch_pass" >> "$BASELINE_RUN"
[ "$batch_fail" -eq 0 ] || { echo "BATCH/EOD SUITE FAILED"; exit 1; }

echo "=== [76/90] Report engine suite ==="
run_step report_out report_rc ./tests/test_report.sh
[ "$report_rc" -eq 0 ] || { echo "REPORT ENGINE (rc=$report_rc)"; echo "$report_out" | tail -5; exit 1; }
report_pass=$(echo "$report_out" | count_matches '\\[0;32mPASS')
report_fail=$(echo "$report_out" | count_matches '\\[0;31mFAIL')
echo "report: $report_pass passed, $report_fail failed"
echo "report $report_pass" >> "$BASELINE_RUN"
[ "$report_fail" -eq 0 ] || { echo "REPORT ENGINE SUITE FAILED"; exit 1; }

echo "=== [77/90] Import/export foundation suite ==="
run_step import_out import_rc ./tests/test_import.sh
[ "$import_rc" -eq 0 ] || { echo "IMPORT/EXPORT (rc=$import_rc)"; echo "$import_out" | tail -5; exit 1; }
import_pass=$(echo "$import_out" | count_matches '\\[0;32mPASS')
import_fail=$(echo "$import_out" | count_matches '\\[0;31mFAIL')
echo "import: $import_pass passed, $import_fail failed"
echo "import $import_pass" >> "$BASELINE_RUN"
[ "$import_fail" -eq 0 ] || { echo "IMPORT/EXPORT SUITE FAILED"; exit 1; }

echo "=== [78/90] Fee / velocity suite ==="
run_step fee_out fee_rc ./tests/test_fee.sh
[ "$fee_rc" -eq 0 ] || { echo "FEE/VELOCITY (rc=$fee_rc)"; echo "$fee_out" | tail -5; exit 1; }
fee_pass=$(echo "$fee_out" | count_matches '\\[0;32mPASS')
fee_fail=$(echo "$fee_out" | count_matches '\\[0;31mFAIL')
echo "fee: $fee_pass passed, $fee_fail failed"
echo "fee $fee_pass" >> "$BASELINE_RUN"
[ "$fee_fail" -eq 0 ] || { echo "FEE/VELOCITY SUITE FAILED"; exit 1; }

echo "=== [79/90] EOD calendar / run suite ==="
run_step eod_out eod_rc ./tests/test_eod.sh
[ "$eod_rc" -eq 0 ] || { echo "EOD (rc=$eod_rc)"; echo "$eod_out" | tail -5; exit 1; }
eod_pass=$(echo "$eod_out" | count_matches '\\[0;32mPASS')
eod_fail=$(echo "$eod_out" | count_matches '\\[0;31mFAIL')
echo "eod: $eod_pass passed, $eod_fail failed"
echo "eod $eod_pass" >> "$BASELINE_RUN"
[ "$eod_fail" -eq 0 ] || { echo "EOD SUITE FAILED"; exit 1; }

echo "=== [80/90] Statement archive suite ==="
run_step stmt_out stmt_rc ./tests/test_statement.sh
[ "$stmt_rc" -eq 0 ] || { echo "STATEMENT (rc=$stmt_rc)"; echo "$stmt_out" | tail -5; exit 1; }
stmt_pass=$(echo "$stmt_out" | count_matches '\\[0;32mPASS')
stmt_fail=$(echo "$stmt_out" | count_matches '\\[0;31mFAIL')
echo "statement: $stmt_pass passed, $stmt_fail failed"
echo "statement $stmt_pass" >> "$BASELINE_RUN"
[ "$stmt_fail" -eq 0 ] || { echo "STATEMENT SUITE FAILED"; exit 1; }

echo "=== [81/90] EOD job execution suite ==="
run_step eodjob_out eodjob_rc ./tests/test_eod_jobs.sh
[ "$eodjob_rc" -eq 0 ] || { echo "EOD JOBS (rc=$eodjob_rc)"; echo "$eodjob_out" | tail -5; exit 1; }
eodjob_pass=$(echo "$eodjob_out" | count_matches '\\[0;32mPASS')
eodjob_fail=$(echo "$eodjob_out" | count_matches '\\[0;31mFAIL')
echo "eod-jobs: $eodjob_pass passed, $eodjob_fail failed"
echo "eod_jobs $eodjob_pass" >> "$BASELINE_RUN"
[ "$eodjob_fail" -eq 0 ] || { echo "EOD JOB SUITE FAILED"; exit 1; }

echo "=== [82/90] Reference expansion suite ==="
run_step refext_out refext_rc ./tests/test_ref_ext.sh
[ "$refext_rc" -eq 0 ] || { echo "REF EXT (rc=$refext_rc)"; echo "$refext_out" | tail -5; exit 1; }
refext_pass=$(echo "$refext_out" | count_matches '\\[0;32mPASS')
refext_fail=$(echo "$refext_out" | count_matches '\\[0;31mFAIL')
echo "ref-ext: $refext_pass passed, $refext_fail failed"
echo "ref_ext $refext_pass" >> "$BASELINE_RUN"
[ "$refext_fail" -eq 0 ] || { echo "REFERENCE EXPANSION SUITE FAILED"; exit 1; }

echo "=== [83/90] Notification center suite ==="
run_step ntf_out ntf_rc ./tests/test_notification.sh
[ "$ntf_rc" -eq 0 ] || { echo "NOTIFICATION (rc=$ntf_rc)"; echo "$ntf_out" | tail -5; exit 1; }
ntf_pass=$(echo "$ntf_out" | count_matches '\\[0;32mPASS')
ntf_fail=$(echo "$ntf_out" | count_matches '\\[0;31mFAIL')
echo "notification: $ntf_pass passed, $ntf_fail failed"
echo "notification $ntf_pass" >> "$BASELINE_RUN"
[ "$ntf_fail" -eq 0 ] || { echo "NOTIFICATION SUITE FAILED"; exit 1; }

echo "=== [84/90] Payment policy suite ==="
run_step pay_out pay_rc ./tests/test_payment.sh
[ "$pay_rc" -eq 0 ] || { echo "PAYMENT (rc=$pay_rc)"; echo "$pay_out" | tail -5; exit 1; }
pay_pass=$(echo "$pay_out" | count_matches '\\[0;32mPASS')
pay_fail=$(echo "$pay_out" | count_matches '\\[0;31mFAIL')
echo "payment: $pay_pass passed, $pay_fail failed"
echo "payment $pay_pass" >> "$BASELINE_RUN"
[ "$pay_fail" -eq 0 ] || { echo "PAYMENT SUITE FAILED"; exit 1; }

echo "=== [85/90] Reconciliation reporting suite ==="
run_step recon2_out recon2_rc ./tests/test_recon.sh
[ "$recon2_rc" -eq 0 ] || { echo "RECON (rc=$recon2_rc)"; echo "$recon2_out" | tail -5; exit 1; }
recon2_pass=$(echo "$recon2_out" | count_matches '\\[0;32mPASS')
recon2_fail=$(echo "$recon2_out" | count_matches '\\[0;31mFAIL')
echo "recon-report: $recon2_pass passed, $recon2_fail failed"
echo "recon_report $recon2_pass" >> "$BASELINE_RUN"
[ "$recon2_fail" -eq 0 ] || { echo "RECON REPORT SUITE FAILED"; exit 1; }

echo "=== [86/90] Import ledger posting suite ==="
run_step impp_out impp_rc ./tests/test_import_post.sh
[ "$impp_rc" -eq 0 ] || { echo "IMPORT POST (rc=$impp_rc)"; echo "$impp_out" | tail -5; exit 1; }
impp_pass=$(echo "$impp_out" | count_matches '\\[0;32mPASS')
impp_fail=$(echo "$impp_out" | count_matches '\\[0;31mFAIL')
echo "import-post: $impp_pass passed, $impp_fail failed"
echo "import_post $impp_pass" >> "$BASELINE_RUN"
[ "$impp_fail" -eq 0 ] || { echo "IMPORT POST SUITE FAILED"; exit 1; }

echo "=== [87/90] Report delivery suite ==="
run_step rdl_out rdl_rc ./tests/test_report_delivery.sh
[ "$rdl_rc" -eq 0 ] || { echo "REPORT DELIVERY (rc=$rdl_rc)"; echo "$rdl_out" | tail -5; exit 1; }
rdl_pass=$(echo "$rdl_out" | count_matches '\\[0;32mPASS')
rdl_fail=$(echo "$rdl_out" | count_matches '\\[0;31mFAIL')
echo "report-delivery: $rdl_pass passed, $rdl_fail failed"
echo "report_delivery $rdl_pass" >> "$BASELINE_RUN"
[ "$rdl_fail" -eq 0 ] || { echo "REPORT DELIVERY SUITE FAILED"; exit 1; }

echo "=== [88/90] Dispute operations suite ==="
run_step dsp_out dsp_rc ./tests/test_dispute_ops.sh
[ "$dsp_rc" -eq 0 ] || { echo "DISPUTE OPS (rc=$dsp_rc)"; echo "$dsp_out" | tail -5; exit 1; }
dsp_pass=$(echo "$dsp_out" | count_matches '\\[0;32mPASS')
dsp_fail=$(echo "$dsp_out" | count_matches '\\[0;31mFAIL')
echo "dispute-ops: $dsp_pass passed, $dsp_fail failed"
echo "dispute_ops $dsp_pass" >> "$BASELINE_RUN"
[ "$dsp_fail" -eq 0 ] || { echo "DISPUTE OPS SUITE FAILED"; exit 1; }

echo "=== [89/90] Retained export archive suite ==="
run_step exp_out exp_rc ./tests/test_export_archive.sh
[ "$exp_rc" -eq 0 ] || { echo "EXPORT ARCHIVE (rc=$exp_rc)"; echo "$exp_out" | tail -5; exit 1; }
exp_pass=$(echo "$exp_out" | count_matches '\\[0;32mPASS')
exp_fail=$(echo "$exp_out" | count_matches '\\[0;31mFAIL')
echo "export-archive: $exp_pass passed, $exp_fail failed"
echo "export_archive $exp_pass" >> "$BASELINE_RUN"
[ "$exp_fail" -eq 0 ] || { echo "EXPORT ARCHIVE SUITE FAILED"; exit 1; }

echo "=== [90/90] Assertion-count baseline ==="
./tests/baseline_check.sh "$BASELINE_RUN"

echo "=== ALL GREEN ==="
