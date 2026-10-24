#!/bin/bash
# One-shot CI: docs integrity -> static COBOL checks -> build -> both test suites.
# Usage: ./ci.sh

set -e

# Keep the KDF cheap for the test run; production uses the compiled default
# (600000). The KDF suite sets its own costs per call and asserts the compiled
# default, so this only affects the unrelated suites' fixture hashing.
export PBKDF2_ITERATIONS="${PBKDF2_ITERATIONS:-10000}"

# CI compiles at -O0: same source and behaviour, ~65s less compile time than
# the production -O2 default. Set COBOL_OPT=-O2 to override.
export COBOL_OPT="${COBOL_OPT:--O0}"

# Backup/restore in the merge gate covers a representative slice of the money
# path and every trigger-bearing table. The full 454-table round-trip takes
# ~140s of CREATE TABLE fsync and runs in scripts/nightly.sh. Set
# BACKUP_TABLES= (empty) to force the full round-trip here.
if [ -z "${BACKUP_TABLES+x}" ]; then
    BACKUP_TABLES="accounts users ledger pending_transactions dispute_cases dispute_messages reconciliation_runs audit_trail exchange_rates schema_migrations ref_account_status"
fi
export BACKUP_TABLES

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
    local __err __out __rc=0 __t0
    __t0="$(date +%s%N)"
    __err="$(mktemp)"
    # A hung suite must fail instead of blocking the gate forever. Keep the
    # stderr stream: it is where the bridge and mysql put their diagnostics.
    if __out=$(timeout "${CI_STEP_TIMEOUT:-300}" "$@" 2>"$__err"); then __rc=0; else __rc=$?; fi
    if [ "$__rc" -ne 0 ] && [ -s "$__err" ]; then
        __out="${__out}"$'\n'"--- stderr ---"$'\n'"$(cat "$__err")"
    fi
    rm -f "$__err"
    printf -v "$__out_var" "%s" "$__out"
    printf -v "$__rc_var" "%s" "$__rc"
    # Append to a timing log so the next audit has data instead of guesses.
    printf '%6d ms  rc=%s  %s\n' \
        "$(( ($(date +%s%N) - __t0) / 1000000 ))" "$__rc" "$*" \
        >> "${CI_TIMINGS:-/tmp/opencode/ci-timings.txt}"
    return 0
}

echo "=== [1/156] Docs integrity check ==="
./tests/docs_check.sh

echo "=== [2/156] Static COBOL checks ==="
./tests/static_checks.sh

echo "=== [3/156] Build ==="
if build_log=$(./build.sh 2>&1); then build_rc=0; else build_rc=$?; fi
[ "$build_rc" -eq 0 ] || { echo "BUILD FAILED (rc=$build_rc)"; echo "$build_log" | tail -20; exit 1; }
echo "$build_log" | grep -E "^cobol.*error:" && { echo "BUILD FAILED"; exit 1; }
echo "$build_log" | grep -q "SUCCESS: Binary created" || { echo "BUILD FAILED"; exit 1; }
bw_log="$(mktemp)"
printf '%s\n' "$build_log" > "$bw_log"
./tests/warning_check.sh "$bw_log"
rm -f "$bw_log"
echo "Build OK"

echo "=== [4/156] Functional suite ==="
run_step func_out func_rc ./tests/test_suite.sh
[ "$func_rc" -eq 0 ] || { echo "FUNCTIONAL (rc=$func_rc)"; echo "$func_out" | tail -5; exit 1; }
echo "$func_out" | tail -1
func_fail=$(echo "$func_out" | grep -oE '[0-9]+ failed' | grep -oE '[0-9]+' | head -1 || echo 0)
func_fail=${func_fail:-0}
[ "$func_fail" -eq 0 ] || { echo "FUNCTIONAL SUITE FAILED"; exit 1; }
func_pass=$(echo "$func_out" | count_matches '\\[PASS\\]')
echo "functional $func_pass" >> "$BASELINE_RUN"

echo "=== [5/156] Atomic transaction suite ==="
run_step atomic_out atomic_rc ./tests/test_atomic_txn.sh
[ "$atomic_rc" -eq 0 ] || { echo "ATOMIC (rc=$atomic_rc)"; echo "$atomic_out" | tail -5; exit 1; }
atomic_pass=$(echo "$atomic_out" | count_matches '\\[0;32mPASS')
atomic_fail=$(echo "$atomic_out" | count_matches '\\[0;31mFAIL')
echo "atomic: $atomic_pass passed, $atomic_fail failed"
echo "atomic $atomic_pass" >> "$BASELINE_RUN"
[ "$atomic_fail" -eq 0 ] || { echo "ATOMIC SUITE FAILED"; exit 1; }

echo "=== [6/156] Ledger atomic suite ==="
run_step ledger_out ledger_rc ./tests/test_ledger_atomic.sh
[ "$ledger_rc" -eq 0 ] || { echo "LEDGER (rc=$ledger_rc)"; echo "$ledger_out" | tail -5; exit 1; }
ledger_pass=$(echo "$ledger_out" | count_matches '\\[0;32mPASS')
ledger_fail=$(echo "$ledger_out" | count_matches '\\[0;31mFAIL')
echo "ledger: $ledger_pass passed, $ledger_fail failed"
echo "ledger-atomic $ledger_pass" >> "$BASELINE_RUN"
[ "$ledger_fail" -eq 0 ] || { echo "LEDGER SUITE FAILED"; exit 1; }

echo "=== [7/156] Reconciliation suite ==="
run_step recon_out recon_rc ./tests/test_reconciliation.sh
[ "$recon_rc" -eq 0 ] || { echo "RECONCILIATION (rc=$recon_rc)"; echo "$recon_out" | tail -5; exit 1; }
recon_pass=$(echo "$recon_out" | count_matches '\\[0;32mPASS')
recon_fail=$(echo "$recon_out" | count_matches '\\[0;31mFAIL')
echo "reconciliation: $recon_pass passed, $recon_fail failed"
echo "reconciliation $recon_pass" >> "$BASELINE_RUN"
[ "$recon_fail" -eq 0 ] || { echo "RECONCILIATION SUITE FAILED"; exit 1; }

echo "=== [8/156] Auth login suite ==="
run_step auth_out auth_rc ./tests/test_auth_login.sh
[ "$auth_rc" -eq 0 ] || { echo "AUTH (rc=$auth_rc)"; echo "$auth_out" | tail -5; exit 1; }
auth_pass=$(echo "$auth_out" | count_matches '\\[0;32mPASS')
auth_fail=$(echo "$auth_out" | count_matches '\\[0;31mFAIL')
echo "auth: $auth_pass passed, $auth_fail failed"
echo "auth-login $auth_pass" >> "$BASELINE_RUN"
[ "$auth_fail" -eq 0 ] || { echo "AUTH SUITE FAILED"; exit 1; }

echo "=== [9/156] Signup + verify suite ==="
run_step signup_out signup_rc ./tests/test_signup_verify.sh
[ "$signup_rc" -eq 0 ] || { echo "SIGNUP (rc=$signup_rc)"; echo "$signup_out" | tail -5; exit 1; }
signup_pass=$(echo "$signup_out" | count_matches '\\[0;32mPASS')
signup_fail=$(echo "$signup_out" | count_matches '\\[0;31mFAIL')
echo "signup/verify: $signup_pass passed, $signup_fail failed"
echo "signup-verify $signup_pass" >> "$BASELINE_RUN"
[ "$signup_fail" -eq 0 ] || { echo "SIGNUP SUITE FAILED"; exit 1; }

echo "=== [10/156] Role suite ==="
run_step role_out role_rc ./tests/test_roles.sh
[ "$role_rc" -eq 0 ] || { echo "ROLE (rc=$role_rc)"; echo "$role_out" | tail -5; exit 1; }
role_pass=$(echo "$role_out" | count_matches '\\[0;32mPASS')
role_fail=$(echo "$role_out" | count_matches '\\[0;31mFAIL')
echo "roles: $role_pass passed, $role_fail failed"
echo "roles $role_pass" >> "$BASELINE_RUN"
[ "$role_fail" -eq 0 ] || { echo "ROLE SUITE FAILED"; exit 1; }

echo "=== [11/156] User profile suite ==="
run_step profile_out profile_rc ./tests/test_user_profile.sh
[ "$profile_rc" -eq 0 ] || { echo "PROFILE (rc=$profile_rc)"; echo "$profile_out" | tail -5; exit 1; }
profile_pass=$(echo "$profile_out" | count_matches '\\[0;32mPASS')
profile_fail=$(echo "$profile_out" | count_matches '\\[0;31mFAIL')
echo "profile: $profile_pass passed, $profile_fail failed"
echo "user-profile $profile_pass" >> "$BASELINE_RUN"
[ "$profile_fail" -eq 0 ] || { echo "PROFILE SUITE FAILED"; exit 1; }

echo "=== [12/156] API gateway suite ==="
if [ -d middleware ]; then
    # Reinstall only when the lockfile changes. `npm ci` is reproducible but
    # wipes node_modules; the stamp records which lockfile produced the tree.
    # No `|| npm install` fallback: that silently accepted a different tree
    # than package-lock.json describes.
    mw_hash="$(sha256sum middleware/package-lock.json | awk '{print $1}')"
    mw_stamp="middleware/node_modules/.ci-lock-${mw_hash}"
    if [ ! -f "$mw_stamp" ]; then
        rm -rf middleware/node_modules
        timeout 300 npm --prefix middleware ci --silent --no-audit --no-fund || {
            echo "GATEWAY DEPENDENCY INSTALL FAILED (npm ci)"; exit 1; }
        touch "$mw_stamp"
    fi
    if timeout 300 npm --prefix middleware test --silent >/tmp/opencode/gateway.out 2>&1; then
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

echo "=== [13/156] Login lockout suite ==="
run_step lockout_out lockout_rc ./tests/test_login_lockout.sh
[ "$lockout_rc" -eq 0 ] || { echo "LOCKOUT (rc=$lockout_rc)"; echo "$lockout_out" | tail -5; exit 1; }
lockout_pass=$(echo "$lockout_out" | count_matches '\\[0;32mPASS')
lockout_fail=$(echo "$lockout_out" | count_matches '\\[0;31mFAIL')
echo "lockout: $lockout_pass passed, $lockout_fail failed"
echo "lockout $lockout_pass" >> "$BASELINE_RUN"
[ "$lockout_fail" -eq 0 ] || { echo "LOCKOUT SUITE FAILED"; exit 1; }

echo "=== [14/156] Idempotent transfer suite ==="
run_step idem_out idem_rc ./tests/test_idempotent_transfer.sh
[ "$idem_rc" -eq 0 ] || { echo "IDEMPOTENT (rc=$idem_rc)"; echo "$idem_out" | tail -5; exit 1; }
idem_pass=$(echo "$idem_out" | count_matches '\\[0;32mPASS')
idem_fail=$(echo "$idem_out" | count_matches '\\[0;31mFAIL')
echo "idempotent transfer: $idem_pass passed, $idem_fail failed"
echo "idempotent-transfer $idem_pass" >> "$BASELINE_RUN"
[ "$idem_fail" -eq 0 ] || { echo "IDEMPOTENT SUITE FAILED"; exit 1; }

echo "=== [15/156] Transfer validity suite ==="
run_step validity_out validity_rc ./tests/test_transfer_validity.sh
[ "$validity_rc" -eq 0 ] || { echo "TRANSFER VALIDITY (rc=$validity_rc)"; echo "$validity_out" | tail -5; exit 1; }
validity_pass=$(echo "$validity_out" | count_matches '\\[0;32mPASS')
validity_fail=$(echo "$validity_out" | count_matches '\\[0;31mFAIL')
echo "transfer validity: $validity_pass passed, $validity_fail failed"
echo "transfer-validity $validity_pass" >> "$BASELINE_RUN"
[ "$validity_fail" -eq 0 ] || { echo "TRANSFER VALIDITY SUITE FAILED"; exit 1; }

echo "=== [16/156] Concurrent opposing transfers ==="
run_step conc_out conc_rc ./tests/test_concurrent_transfer.sh
[ "$conc_rc" -eq 0 ] || { echo "CONCURRENT (rc=$conc_rc)"; echo "$conc_out" | tail -5; exit 1; }
conc_pass=$(echo "$conc_out" | count_matches '\\[0;32mPASS')
conc_fail=$(echo "$conc_out" | count_matches '\\[0;31mFAIL')
echo "concurrent transfer: $conc_pass passed, $conc_fail failed"
echo "concurrent $conc_pass" >> "$BASELINE_RUN"
[ "$conc_fail" -eq 0 ] || { echo "CONCURRENT SUITE FAILED"; exit 1; }

echo "=== [17/156] SQL injection mitigation suite ==="
run_step inj_out inj_rc ./tests/test_injection.sh
[ "$inj_rc" -eq 0 ] || { echo "INJECTION (rc=$inj_rc)"; echo "$inj_out" | tail -5; exit 1; }
inj_pass=$(echo "$inj_out" | count_matches '\\[0;32mPASS')
inj_fail=$(echo "$inj_out" | count_matches '\\[0;31mFAIL')
echo "injection: $inj_pass passed, $inj_fail failed"
echo "injection $inj_pass" >> "$BASELINE_RUN"
[ "$inj_fail" -eq 0 ] || { echo "INJECTION SUITE FAILED"; exit 1; }

echo "=== [18/156] Refresh session suite ==="
run_step sess_out sess_rc ./tests/test_session.sh
[ "$sess_rc" -eq 0 ] || { echo "SESSION (rc=$sess_rc)"; echo "$sess_out" | tail -5; exit 1; }
sess_pass=$(echo "$sess_out" | count_matches '\\[0;32mPASS')
sess_fail=$(echo "$sess_out" | count_matches '\\[0;31mFAIL')
echo "session: $sess_pass passed, $sess_fail failed"
echo "session $sess_pass" >> "$BASELINE_RUN"
[ "$sess_fail" -eq 0 ] || { echo "SESSION SUITE FAILED"; exit 1; }

echo "=== [19/156] Prepared statement suite ==="
run_step prep_out prep_rc ./tests/test_prepared.sh
[ "$prep_rc" -eq 0 ] || { echo "PREPARED (rc=$prep_rc)"; echo "$prep_out" | tail -5; exit 1; }
prep_pass=$(echo "$prep_out" | count_matches '\\[0;32mPASS')
prep_fail=$(echo "$prep_out" | count_matches '\\[0;31mFAIL')
echo "prepared: $prep_pass passed, $prep_fail failed"
echo "prepared $prep_pass" >> "$BASELINE_RUN"
[ "$prep_fail" -eq 0 ] || { echo "PREPARED SUITE FAILED"; exit 1; }

echo "=== [20/156] Deep health (PING) suite ==="
run_step ping_out ping_rc ./tests/test_ping.sh
[ "$ping_rc" -eq 0 ] || { echo "PING (rc=$ping_rc)"; echo "$ping_out" | tail -5; exit 1; }
ping_pass=$(echo "$ping_out" | count_matches '\\[0;32mPASS')
ping_fail=$(echo "$ping_out" | count_matches '\\[0;31mFAIL')
echo "ping: $ping_pass passed, $ping_fail failed"
echo "ping $ping_pass" >> "$BASELINE_RUN"
[ "$ping_fail" -eq 0 ] || { echo "PING SUITE FAILED"; exit 1; }

echo "=== [21/156] Migration check ==="
./database/migrate.sh --check

echo "=== [22/156] Migration tooling suite ==="
run_step mig_out mig_rc ./tests/test_migrate.sh
[ "$mig_rc" -eq 0 ] || { echo "MIGRATION (rc=$mig_rc)"; echo "$mig_out" | tail -5; exit 1; }
mig_pass=$(echo "$mig_out" | count_matches '\\[0;32mPASS')
mig_fail=$(echo "$mig_out" | count_matches '\\[0;31mFAIL')
echo "migrations: $mig_pass passed, $mig_fail failed"
echo "migrate $mig_pass" >> "$BASELINE_RUN"
[ "$mig_fail" -eq 0 ] || { echo "MIGRATION SUITE FAILED"; exit 1; }

echo "=== [23/156] Status/docs integrity ==="
./tests/status_check.sh
./tests/traceability_check.sh

echo "=== [24/156] End-to-end HTTP smoke ==="
run_step e2e_out e2e_rc ./tests/test_e2e_gateway.sh
[ "$e2e_rc" -eq 0 ] || { echo "E2E (rc=$e2e_rc)"; echo "$e2e_out" | tail -5; exit 1; }
e2e_pass=$(echo "$e2e_out" | count_matches '\\[0;32mPASS')
e2e_fail=$(echo "$e2e_out" | count_matches '\\[0;31mFAIL')
echo "e2e: $e2e_pass passed, $e2e_fail failed"
echo "e2e $e2e_pass" >> "$BASELINE_RUN"
[ "$e2e_fail" -eq 0 ] || { echo "E2E SUITE FAILED"; exit 1; }

echo "=== [25/156] Serve mode suite ==="
run_step serve_out serve_rc ./tests/test_serve_mode.sh
[ "$serve_rc" -eq 0 ] || { echo "SERVE MODE (rc=$serve_rc)"; echo "$serve_out" | tail -5; exit 1; }
serve_pass=$(echo "$serve_out" | count_matches '\\[0;32mPASS')
serve_fail=$(echo "$serve_out" | count_matches '\\[0;31mFAIL')
echo "serve: $serve_pass passed, $serve_fail failed"
echo "serve $serve_pass" >> "$BASELINE_RUN"
[ "$serve_fail" -eq 0 ] || { echo "SERVE MODE SUITE FAILED"; exit 1; }

echo "=== [26/156] End-to-end HTTP smoke (pool mode) ==="
run_step pool_out pool_rc env COBOL_POOL_SIZE=4 ./tests/test_e2e_gateway.sh
[ "$pool_rc" -eq 0 ] || { echo "E2E POOL (rc=$pool_rc)"; echo "$pool_out" | tail -5; exit 1; }
pool_pass=$(echo "$pool_out" | count_matches '\\[0;32mPASS')
pool_fail=$(echo "$pool_out" | count_matches '\\[0;31mFAIL')
echo "e2e pool: $pool_pass passed, $pool_fail failed"
echo "e2e-pool $pool_pass" >> "$BASELINE_RUN"
[ "$pool_fail" -eq 0 ] || { echo "E2E POOL SUITE FAILED"; exit 1; }

echo "=== [27/156] Password reset/change suite ==="
run_step pw_out pw_rc ./tests/test_password.sh
[ "$pw_rc" -eq 0 ] || { echo "PASSWORD (rc=$pw_rc)"; echo "$pw_out" | tail -5; exit 1; }
pw_pass=$(echo "$pw_out" | count_matches '\\[0;32mPASS')
pw_fail=$(echo "$pw_out" | count_matches '\\[0;31mFAIL')
echo "password: $pw_pass passed, $pw_fail failed"
echo "password $pw_pass" >> "$BASELINE_RUN"
[ "$pw_fail" -eq 0 ] || { echo "PASSWORD SUITE FAILED"; exit 1; }

echo "=== [28/156] Verification attempt cap suite ==="
run_step cap_out cap_rc ./tests/test_verify_cap.sh
[ "$cap_rc" -eq 0 ] || { echo "VERIFY CAP (rc=$cap_rc)"; echo "$cap_out" | tail -5; exit 1; }
cap_pass=$(echo "$cap_out" | count_matches '\\[0;32mPASS')
cap_fail=$(echo "$cap_out" | count_matches '\\[0;31mFAIL')
echo "verify-cap: $cap_pass passed, $cap_fail failed"
echo "verify-cap $cap_pass" >> "$BASELINE_RUN"
[ "$cap_fail" -eq 0 ] || { echo "VERIFY CAP SUITE FAILED"; exit 1; }

echo "=== [29/156] Password KDF suite ==="
run_step kdf_out kdf_rc ./tests/test_password_kdf.sh
[ "$kdf_rc" -eq 0 ] || { echo "KDF (rc=$kdf_rc)"; echo "$kdf_out" | tail -5; exit 1; }
kdf_pass=$(echo "$kdf_out" | count_matches '\\[0;32mPASS')
kdf_fail=$(echo "$kdf_out" | count_matches '\\[0;31mFAIL')
echo "kdf: $kdf_pass passed, $kdf_fail failed"
echo "kdf $kdf_pass" >> "$BASELINE_RUN"
[ "$kdf_fail" -eq 0 ] || { echo "KDF SUITE FAILED"; exit 1; }

echo "=== [30/156] MFA (TOTP) suite ==="
run_step mfa_out mfa_rc ./tests/test_mfa.sh
[ "$mfa_rc" -eq 0 ] || { echo "MFA (rc=$mfa_rc)"; echo "$mfa_out" | tail -5; exit 1; }
mfa_pass=$(echo "$mfa_out" | count_matches '\\[0;32mPASS')
mfa_fail=$(echo "$mfa_out" | count_matches '\\[0;31mFAIL')
echo "mfa: $mfa_pass passed, $mfa_fail failed"
echo "mfa $mfa_pass" >> "$BASELINE_RUN"
[ "$mfa_fail" -eq 0 ] || { echo "MFA SUITE FAILED"; exit 1; }

echo "=== [31/156] Session management suite ==="
run_step sess_out sess_rc ./tests/test_sessions_manage.sh
[ "$sess_rc" -eq 0 ] || { echo "SESSION (rc=$sess_rc)"; echo "$sess_out" | tail -5; exit 1; }
sess_pass=$(echo "$sess_out" | count_matches '\\[0;32mPASS')
sess_fail=$(echo "$sess_out" | count_matches '\\[0;31mFAIL')
echo "sessions: $sess_pass passed, $sess_fail failed"
echo "sessions-manage $sess_pass" >> "$BASELINE_RUN"
[ "$sess_fail" -eq 0 ] || { echo "SESSION SUITE FAILED"; exit 1; }

echo "=== [32/156] Account status suite ==="
run_step stat_out stat_rc ./tests/test_account_status.sh
[ "$stat_rc" -eq 0 ] || { echo "ACCOUNT STATUS (rc=$stat_rc)"; echo "$stat_out" | tail -5; exit 1; }
stat_pass=$(echo "$stat_out" | count_matches '\\[0;32mPASS')
stat_fail=$(echo "$stat_out" | count_matches '\\[0;31mFAIL')
echo "account-status: $stat_pass passed, $stat_fail failed"
echo "account-status $stat_pass" >> "$BASELINE_RUN"
[ "$stat_fail" -eq 0 ] || { echo "ACCOUNT STATUS SUITE FAILED"; exit 1; }

echo "=== [33/156] Transfer limits suite ==="
run_step lim_out lim_rc ./tests/test_transfer_limits.sh
[ "$lim_rc" -eq 0 ] || { echo "TRANSFER LIMITS (rc=$lim_rc)"; echo "$lim_out" | tail -5; exit 1; }
lim_pass=$(echo "$lim_out" | count_matches '\\[0;32mPASS')
lim_fail=$(echo "$lim_out" | count_matches '\\[0;31mFAIL')
echo "limits: $lim_pass passed, $lim_fail failed"
echo "transfer-limits $lim_pass" >> "$BASELINE_RUN"
[ "$lim_fail" -eq 0 ] || { echo "TRANSFER LIMITS SUITE FAILED"; exit 1; }

echo "=== [34/156] Transfer reversal suite ==="
run_step rev_out rev_rc ./tests/test_transfer_reversal.sh
[ "$rev_rc" -eq 0 ] || { echo "REVERSAL (rc=$rev_rc)"; echo "$rev_out" | tail -5; exit 1; }
rev_pass=$(echo "$rev_out" | count_matches '\\[0;32mPASS')
rev_fail=$(echo "$rev_out" | count_matches '\\[0;31mFAIL')
echo "reversal: $rev_pass passed, $rev_fail failed"
echo "reversal $rev_pass" >> "$BASELINE_RUN"
[ "$rev_fail" -eq 0 ] || { echo "REVERSAL SUITE FAILED"; exit 1; }

echo "=== [35/156] Journal suite ==="
run_step journal_out journal_rc ./tests/test_journal.sh
[ "$journal_rc" -eq 0 ] || { echo "JOURNAL (rc=$journal_rc)"; echo "$journal_out" | tail -5; exit 1; }
journal_pass=$(echo "$journal_out" | count_matches '\\[0;32mPASS')
journal_fail=$(echo "$journal_out" | count_matches '\\[0;31mFAIL')
echo "journal: $journal_pass passed, $journal_fail failed"
echo "journal $journal_pass" >> "$BASELINE_RUN"
[ "$journal_fail" -eq 0 ] || { echo "JOURNAL SUITE FAILED"; exit 1; }

echo "=== [39/156] Holds and fees suite ==="
run_step holds_out holds_rc ./tests/test_holds.sh
[ "$holds_rc" -eq 0 ] || { echo "HOLDS (rc=$holds_rc)"; echo "$holds_out" | tail -5; exit 1; }
holds_pass=$(echo "$holds_out" | count_matches '\\[0;32mPASS')
holds_fail=$(echo "$holds_out" | count_matches '\\[0;31mFAIL')
echo "holds: $holds_pass passed, $holds_fail failed"
echo "holds $holds_pass" >> "$BASELINE_RUN"
[ "$holds_fail" -eq 0 ] || { echo "HOLDS SUITE FAILED"; exit 1; }

echo "=== [37/156] Dual control suite ==="
run_step dual_out dual_rc ./tests/test_dual_control.sh
[ "$dual_rc" -eq 0 ] || { echo "DUAL CONTROL (rc=$dual_rc)"; echo "$dual_out" | tail -5; exit 1; }
dual_pass=$(echo "$dual_out" | count_matches '\\[0;32mPASS')
dual_fail=$(echo "$dual_out" | count_matches '\\[0;31mFAIL')
echo "dual-control: $dual_pass passed, $dual_fail failed"
echo "dual-control $dual_pass" >> "$BASELINE_RUN"
[ "$dual_fail" -eq 0 ] || { echo "DUAL CONTROL SUITE FAILED"; exit 1; }

echo "=== [38/156] Outbox suite ==="
run_step outbox_out outbox_rc ./tests/test_outbox.sh
[ "$outbox_rc" -eq 0 ] || { echo "OUTBOX (rc=$outbox_rc)"; echo "$outbox_out" | tail -5; exit 1; }
outbox_pass=$(echo "$outbox_out" | count_matches '\\[0;32mPASS')
outbox_fail=$(echo "$outbox_out" | count_matches '\\[0;31mFAIL')
echo "outbox: $outbox_pass passed, $outbox_fail failed"
echo "outbox $outbox_pass" >> "$BASELINE_RUN"
[ "$outbox_fail" -eq 0 ] || { echo "OUTBOX SUITE FAILED"; exit 1; }

echo "=== [36/156] Reconciliation runs suite ==="
run_step reconruns_out reconruns_rc ./tests/test_reconciliation_runs.sh
[ "$reconruns_rc" -eq 0 ] || { echo "RECONCILIATION RUNS (rc=$reconruns_rc)"; echo "$reconruns_out" | tail -5; exit 1; }
reconruns_pass=$(echo "$reconruns_out" | count_matches '\\[0;32mPASS')
reconruns_fail=$(echo "$reconruns_out" | count_matches '\\[0;31mFAIL')
echo "recon-runs: $reconruns_pass passed, $reconruns_fail failed"
echo "recon-runs $reconruns_pass" >> "$BASELINE_RUN"
[ "$reconruns_fail" -eq 0 ] || { echo "RECONCILIATION RUNS SUITE FAILED"; exit 1; }

echo "=== [40/156] Wallet observability suite ==="
run_step obs_out obs_rc ./tests/test_wallet_observability.sh
[ "$obs_rc" -eq 0 ] || { echo "OBSERVABILITY (rc=$obs_rc)"; echo "$obs_out" | tail -5; exit 1; }
obs_pass=$(echo "$obs_out" | count_matches '\\[0;32mPASS')
obs_fail=$(echo "$obs_out" | count_matches '\\[0;31mFAIL')
echo "observability: $obs_pass passed, $obs_fail failed"
echo "observability $obs_pass" >> "$BASELINE_RUN"
[ "$obs_fail" -eq 0 ] || { echo "OBSERVABILITY SUITE FAILED"; exit 1; }

echo "=== [41/156] Account lifecycle suite ==="
run_step lc_out lc_rc ./tests/test_account_lifecycle.sh
[ "$lc_rc" -eq 0 ] || { echo "ACCOUNT LIFECYCLE (rc=$lc_rc)"; echo "$lc_out" | tail -5; exit 1; }
lc_pass=$(echo "$lc_out" | count_matches '\\[0;32mPASS')
lc_fail=$(echo "$lc_out" | count_matches '\\[0;31mFAIL')
echo "lifecycle: $lc_pass passed, $lc_fail failed"
echo "lifecycle $lc_pass" >> "$BASELINE_RUN"
[ "$lc_fail" -eq 0 ] || { echo "ACCOUNT LIFECYCLE SUITE FAILED"; exit 1; }

echo "=== [42/156] Token rotation suite ==="
run_step rot_out rot_rc ./tests/test_token_rotation.sh
[ "$rot_rc" -eq 0 ] || { echo "TOKEN ROTATION (rc=$rot_rc)"; echo "$rot_out" | tail -5; exit 1; }
rot_pass=$(echo "$rot_out" | count_matches '\\[0;32mPASS')
rot_fail=$(echo "$rot_out" | count_matches '\\[0;31mFAIL')
echo "rotation: $rot_pass passed, $rot_fail failed"
echo "rotation $rot_pass" >> "$BASELINE_RUN"
[ "$rot_fail" -eq 0 ] || { echo "TOKEN ROTATION SUITE FAILED"; exit 1; }

echo "=== [43/156] Admin role-hierarchy suite ==="
run_step hier_out hier_rc ./tests/test_admin_hierarchy.sh
[ "$hier_rc" -eq 0 ] || { echo "ADMIN HIERARCHY (rc=$hier_rc)"; echo "$hier_out" | tail -5; exit 1; }
hier_pass=$(echo "$hier_out" | count_matches '\\[0;32mPASS')
hier_fail=$(echo "$hier_out" | count_matches '\\[0;31mFAIL')
echo "hierarchy: $hier_pass passed, $hier_fail failed"
echo "admin-hierarchy $hier_pass" >> "$BASELINE_RUN"
[ "$hier_fail" -eq 0 ] || { echo "ADMIN HIERARCHY SUITE FAILED"; exit 1; }

echo "=== [44/156] Last-admin protection suite ==="
run_step la_out la_rc ./tests/test_last_admin.sh
[ "$la_rc" -eq 0 ] || { echo "LAST-ADMIN (rc=$la_rc)"; echo "$la_out" | tail -5; exit 1; }
la_pass=$(echo "$la_out" | count_matches '\\[0;32mPASS')
la_fail=$(echo "$la_out" | count_matches '\\[0;31mFAIL')
echo "last-admin: $la_pass passed, $la_fail failed"
echo "last-admin $la_pass" >> "$BASELINE_RUN"
[ "$la_fail" -eq 0 ] || { echo "LAST-ADMIN SUITE FAILED"; exit 1; }

echo "=== [45/156] Audit actor-attribution suite ==="
run_step aa_out aa_rc ./tests/test_audit_actor.sh
[ "$aa_rc" -eq 0 ] || { echo "AUDIT ACTOR (rc=$aa_rc)"; echo "$aa_out" | tail -5; exit 1; }
aa_pass=$(echo "$aa_out" | count_matches '\\[0;32mPASS')
aa_fail=$(echo "$aa_out" | count_matches '\\[0;31mFAIL')
echo "audit-actor: $aa_pass passed, $aa_fail failed"
echo "audit-actor $aa_pass" >> "$BASELINE_RUN"
[ "$aa_fail" -eq 0 ] || { echo "AUDIT ACTOR SUITE FAILED"; exit 1; }

echo "=== [46/156] Audit read suite ==="
run_step ar_out ar_rc ./tests/test_audit_read.sh
[ "$ar_rc" -eq 0 ] || { echo "AUDIT READ (rc=$ar_rc)"; echo "$ar_out" | tail -5; exit 1; }
ar_pass=$(echo "$ar_out" | count_matches '\\[0;32mPASS')
ar_fail=$(echo "$ar_out" | count_matches '\\[0;31mFAIL')
echo "audit-read: $ar_pass passed, $ar_fail failed"
echo "audit-read $ar_pass" >> "$BASELINE_RUN"
[ "$ar_fail" -eq 0 ] || { echo "AUDIT READ SUITE FAILED"; exit 1; }

echo "=== [47/156] Audit integrity suite ==="
run_step ai_out ai_rc ./tests/test_audit_integrity.sh
[ "$ai_rc" -eq 0 ] || { echo "AUDIT INTEGRITY (rc=$ai_rc)"; echo "$ai_out" | tail -5; exit 1; }
ai_pass=$(echo "$ai_out" | count_matches '\\[0;32mPASS')
ai_fail=$(echo "$ai_out" | count_matches '\\[0;31mFAIL')
echo "audit-integrity: $ai_pass passed, $ai_fail failed"
echo "audit-integrity $ai_pass" >> "$BASELINE_RUN"
[ "$ai_fail" -eq 0 ] || { echo "AUDIT INTEGRITY SUITE FAILED"; exit 1; }

echo "=== [48/156] Admin recovery suite ==="
run_step ar2_out ar2_rc ./tests/test_admin_recovery.sh
[ "$ar2_rc" -eq 0 ] || { echo "ADMIN RECOVERY (rc=$ar2_rc)"; echo "$ar2_out" | tail -5; exit 1; }
ar2_pass=$(echo "$ar2_out" | count_matches '\\[0;32mPASS')
ar2_fail=$(echo "$ar2_out" | count_matches '\\[0;31mFAIL')
echo "admin-recovery: $ar2_pass passed, $ar2_fail failed"
echo "admin-recovery $ar2_pass" >> "$BASELINE_RUN"
[ "$ar2_fail" -eq 0 ] || { echo "ADMIN RECOVERY SUITE FAILED"; exit 1; }

echo "=== [49/156] Step-up (re-authentication) suite ==="
run_step su_out su_rc ./tests/test_stepup.sh
[ "$su_rc" -eq 0 ] || { echo "STEP-UP (rc=$su_rc)"; echo "$su_out" | tail -5; exit 1; }
su_pass=$(echo "$su_out" | count_matches '\\[0;32mPASS')
su_fail=$(echo "$su_out" | count_matches '\\[0;31mFAIL')
echo "step-up: $su_pass passed, $su_fail failed"
echo "step-up $su_pass" >> "$BASELINE_RUN"
[ "$su_fail" -eq 0 ] || { echo "STEP-UP SUITE FAILED"; exit 1; }

echo "=== [50/156] MFA-state suite ==="
run_step ms_out ms_rc ./tests/test_mfa_state.sh
[ "$ms_rc" -eq 0 ] || { echo "MFA STATE (rc=$ms_rc)"; echo "$ms_out" | tail -5; exit 1; }
ms_pass=$(echo "$ms_out" | count_matches '\\[0;32mPASS')
ms_fail=$(echo "$ms_out" | count_matches '\\[0;31mFAIL')
echo "mfa-state: $ms_pass passed, $ms_fail failed"
echo "mfa-state $ms_pass" >> "$BASELINE_RUN"
[ "$ms_fail" -eq 0 ] || { echo "MFA STATE SUITE FAILED"; exit 1; }

echo "=== [51/156] MFA recovery suite ==="
run_step mfar_out mfar_rc ./tests/test_mfa_recovery.sh
[ "$mfar_rc" -eq 0 ] || { echo "MFA RECOVERY (rc=$mfar_rc)"; echo "$mfar_out" | tail -5; exit 1; }
mfar_pass=$(echo "$mfar_out" | count_matches '\\[0;32mPASS')
mfar_fail=$(echo "$mfar_out" | count_matches '\\[0;31mFAIL')
echo "mfa-recovery: $mfar_pass passed, $mfar_fail failed"
echo "mfa-recovery $mfar_pass" >> "$BASELINE_RUN"
[ "$mfar_fail" -eq 0 ] || { echo "MFA RECOVERY SUITE FAILED"; exit 1; }

echo "=== [52/156] Statements suite ==="
run_step stmt_out stmt_rc ./tests/test_statements.sh
[ "$stmt_rc" -eq 0 ] || { echo "STATEMENTS (rc=$stmt_rc)"; echo "$stmt_out" | tail -5; exit 1; }
stmt_pass=$(echo "$stmt_out" | count_matches '\\[0;32mPASS')
stmt_fail=$(echo "$stmt_out" | count_matches '\\[0;31mFAIL')
echo "statements: $stmt_pass passed, $stmt_fail failed"
echo "statements $stmt_pass" >> "$BASELINE_RUN"
[ "$stmt_fail" -eq 0 ] || { echo "STATEMENTS SUITE FAILED"; exit 1; }

echo "=== [53/156] Disputes suite ==="
run_step dsp_out dsp_rc ./tests/test_disputes.sh
[ "$dsp_rc" -eq 0 ] || { echo "DISPUTES (rc=$dsp_rc)"; echo "$dsp_out" | tail -5; exit 1; }
dsp_pass=$(echo "$dsp_out" | count_matches '\\[0;32mPASS')
dsp_fail=$(echo "$dsp_out" | count_matches '\\[0;31mFAIL')
echo "disputes: $dsp_pass passed, $dsp_fail failed"
echo "disputes $dsp_pass" >> "$BASELINE_RUN"
[ "$dsp_fail" -eq 0 ] || { echo "DISPUTES SUITE FAILED"; exit 1; }

echo "=== [54/156] Backup/restore suite ==="
run_step bkr_out bkr_rc ./tests/test_backup_restore.sh
[ "$bkr_rc" -eq 0 ] || { echo "BACKUP RESTORE (rc=$bkr_rc)"; echo "$bkr_out" | tail -5; exit 1; }
bkr_pass=$(echo "$bkr_out" | count_matches '\\[0;32mPASS')
bkr_fail=$(echo "$bkr_out" | count_matches '\\[0;31mFAIL')
echo "backup_restore: $bkr_pass passed, $bkr_fail failed"
echo "backup_restore $bkr_pass" >> "$BASELINE_RUN"
[ "$bkr_fail" -eq 0 ] || { echo "BACKUP RESTORE SUITE FAILED"; exit 1; }

echo "=== [55/156] Ledger integrity suite ==="
run_step li_out li_rc ./tests/test_ledger_integrity.sh
[ "$li_rc" -eq 0 ] || { echo "LEDGER INTEGRITY (rc=$li_rc)"; echo "$li_out" | tail -5; exit 1; }
li_pass=$(echo "$li_out" | count_matches '\\[0;32mPASS')
li_fail=$(echo "$li_out" | count_matches '\\[0;31mFAIL')
echo "ledger-integrity: $li_pass passed, $li_fail failed"
echo "ledger-integrity $li_pass" >> "$BASELINE_RUN"
[ "$li_fail" -eq 0 ] || { echo "LEDGER INTEGRITY SUITE FAILED"; exit 1; }

echo "=== [56/156] RNG (CSPRNG) suite ==="
run_step rng_out rng_rc ./tests/test_rng.sh
[ "$rng_rc" -eq 0 ] || { echo "RNG (rc=$rng_rc)"; echo "$rng_out" | tail -5; exit 1; }
rng_pass=$(echo "$rng_out" | count_matches '\\[0;32mPASS')
rng_fail=$(echo "$rng_out" | count_matches '\\[0;31mFAIL')
echo "rng: $rng_pass passed, $rng_fail failed"
echo "rng $rng_pass" >> "$BASELINE_RUN"
[ "$rng_fail" -eq 0 ] || { echo "RNG SUITE FAILED"; exit 1; }

echo "=== [57/156] Least-privilege database suite ==="
run_step gr_out gr_rc ./tests/test_grants.sh
[ "$gr_rc" -eq 0 ] || { echo "GRANTS (rc=$gr_rc)"; echo "$gr_out" | tail -5; exit 1; }
gr_pass=$(echo "$gr_out" | count_matches '\\[0;32mPASS')
gr_fail=$(echo "$gr_out" | count_matches '\\[0;31mFAIL')
echo "grants: $gr_pass passed, $gr_fail failed"
echo "grants $gr_pass" >> "$BASELINE_RUN"
[ "$gr_fail" -eq 0 ] || { echo "GRANTS SUITE FAILED"; exit 1; }

echo "=== [58/156] Resend cooldown suite ==="
run_step rc_out rc_rc ./tests/test_resend_cooldown.sh
[ "$rc_rc" -eq 0 ] || { echo "RESEND COOLDOWN (rc=$rc_rc)"; echo "$rc_out" | tail -5; exit 1; }
rc_pass=$(echo "$rc_out" | count_matches '\\[0;32mPASS')
rc_fail=$(echo "$rc_out" | count_matches '\\[0;31mFAIL')
echo "resend-cooldown: $rc_pass passed, $rc_fail failed"
echo "resend-cooldown $rc_pass" >> "$BASELINE_RUN"
[ "$rc_fail" -eq 0 ] || { echo "RESEND COOLDOWN SUITE FAILED"; exit 1; }

echo "=== [59/156] C memory-boundary suite ==="
run_step cm_out cm_rc ./tests/test_c_memory.sh
[ "$cm_rc" -eq 0 ] || { echo "C MEMORY (rc=$cm_rc)"; echo "$cm_out" | tail -5; exit 1; }
cm_pass=$(echo "$cm_out" | count_matches '\\[0;32mPASS')
cm_fail=$(echo "$cm_out" | count_matches '\\[0;31mFAIL')
echo "c-memory: $cm_pass passed, $cm_fail failed"
echo "c-memory $cm_pass" >> "$BASELINE_RUN"
[ "$cm_fail" -eq 0 ] || { echo "C MEMORY SUITE FAILED"; exit 1; }

echo "=== [60/156] Bridge transaction suite ==="
run_step bt_out bt_rc ./tests/test_bridge_txn.sh
[ "$bt_rc" -eq 0 ] || { echo "BRIDGE TXN (rc=$bt_rc)"; echo "$bt_out" | tail -5; exit 1; }
bt_pass=$(echo "$bt_out" | count_matches '\\[0;32mPASS')
bt_fail=$(echo "$bt_out" | count_matches '\\[0;31mFAIL')
echo "bridge-txn: $bt_pass passed, $bt_fail failed"
echo "bridge-txn $bt_pass" >> "$BASELINE_RUN"
[ "$bt_fail" -eq 0 ] || { echo "BRIDGE TXN SUITE FAILED"; exit 1; }

echo "=== [61/156] Buffer contract check ==="
./tests/buffer_contract_check.sh

echo "=== [62/156] Seed idempotency suite ==="
run_step seed_out seed_rc ./tests/test_seed.sh
[ "$seed_rc" -eq 0 ] || { echo "SEED (rc=$seed_rc)"; echo "$seed_out" | tail -5; exit 1; }
seed_pass=$(echo "$seed_out" | count_matches '\\[0;32mPASS')
seed_fail=$(echo "$seed_out" | count_matches '\\[0;31mFAIL')
echo "seed: $seed_pass passed, $seed_fail failed"
echo "seed $seed_pass" >> "$BASELINE_RUN"
[ "$seed_fail" -eq 0 ] || { echo "SEED SUITE FAILED"; exit 1; }

echo "=== [63/156] Env coverage check ==="
./tests/env_check.sh

echo "=== [64/156] Dependency audit ==="
if npm --prefix middleware audit --omit=dev --audit-level=high > /tmp/opencode/dep_audit.out 2>&1; then
    tail -3 /tmp/opencode/dep_audit.out
    echo "dependency audit clean (high/critical)"
else
    tail -5 /tmp/opencode/dep_audit.out
    echo "DEPENDENCY AUDIT FAILED: resolve or record an exception per docs/patch-policy.md"
    exit 1
fi

echo "=== [65/156] Git hook hygiene suite ==="
run_step hk_out hk_rc ./tests/test_hooks.sh
[ "$hk_rc" -eq 0 ] || { echo "HOOKS (rc=$hk_rc)"; echo "$hk_out" | tail -5; exit 1; }
hk_pass=$(echo "$hk_out" | count_matches '\\[0;32mPASS')
hk_fail=$(echo "$hk_out" | count_matches '\\[0;31mFAIL')
echo "hooks: $hk_pass passed, $hk_fail failed"
echo "hooks $hk_pass" >> "$BASELINE_RUN"
[ "$hk_fail" -eq 0 ] || { echo "HOOKS SUITE FAILED"; exit 1; }

echo "=== [66/156] Control-account uniqueness suite ==="
run_step ctl_out ctl_rc ./tests/test_control_accounts.sh
[ "$ctl_rc" -eq 0 ] || { echo "CONTROL ACCOUNTS (rc=$ctl_rc)"; echo "$ctl_out" | tail -5; exit 1; }
ctl_pass=$(echo "$ctl_out" | count_matches '\\[0;32mPASS')
ctl_fail=$(echo "$ctl_out" | count_matches '\\[0;31mFAIL')
echo "control-accounts: $ctl_pass passed, $ctl_fail failed"
echo "control-accounts $ctl_pass" >> "$BASELINE_RUN"
[ "$ctl_fail" -eq 0 ] || { echo "CONTROL ACCOUNTS SUITE FAILED"; exit 1; }

echo "=== [67/156] Access review suite ==="
run_step ar_out ar_rc ./tests/test_access_reviews.sh
[ "$ar_rc" -eq 0 ] || { echo "ACCESS REVIEWS (rc=$ar_rc)"; echo "$ar_out" | tail -5; exit 1; }
ar_pass=$(echo "$ar_out" | count_matches '\\[0;32mPASS')
ar_fail=$(echo "$ar_out" | count_matches '\\[0;31mFAIL')
echo "access-reviews: $ar_pass passed, $ar_fail failed"
echo "access-reviews $ar_pass" >> "$BASELINE_RUN"
[ "$ar_fail" -eq 0 ] || { echo "ACCESS REVIEWS SUITE FAILED"; exit 1; }

echo "=== [68/156] Scoped permission suite ==="
run_step perm_out perm_rc ./tests/test_permissions.sh
[ "$perm_rc" -eq 0 ] || { echo "PERMISSIONS (rc=$perm_rc)"; echo "$perm_out" | tail -5; exit 1; }
perm_pass=$(echo "$perm_out" | count_matches '\\[0;32mPASS')
perm_fail=$(echo "$perm_out" | count_matches '\\[0;31mFAIL')
echo "permissions: $perm_pass passed, $perm_fail failed"
echo "permissions $perm_pass" >> "$BASELINE_RUN"
[ "$perm_fail" -eq 0 ] || { echo "PERMISSIONS SUITE FAILED"; exit 1; }

echo "=== [69/156] Password policy suite ==="
run_step pwpol_out pwpol_rc ./tests/test_password_policy.sh
[ "$pwpol_rc" -eq 0 ] || { echo "PASSWORD POLICY (rc=$pwpol_rc)"; echo "$pwpol_out" | tail -5; exit 1; }
pwpol_pass=$(echo "$pwpol_out" | count_matches '\\[0;32mPASS')
pwpol_fail=$(echo "$pwpol_out" | count_matches '\\[0;31mFAIL')
echo "password-policy: $pwpol_pass passed, $pwpol_fail failed"
echo "password-policy $pwpol_pass" >> "$BASELINE_RUN"
[ "$pwpol_fail" -eq 0 ] || { echo "PASSWORD POLICY SUITE FAILED"; exit 1; }

echo "=== [70/156] Customer step-up policy suite ==="
run_step stepup_out stepup_rc ./tests/test_step_up_policy.sh
[ "$stepup_rc" -eq 0 ] || { echo "STEP-UP POLICY (rc=$stepup_rc)"; echo "$stepup_out" | tail -5; exit 1; }
stepup_pass=$(echo "$stepup_out" | count_matches '\\[0;32mPASS')
stepup_fail=$(echo "$stepup_out" | count_matches '\\[0;31mFAIL')
echo "step-up-policy: $stepup_pass passed, $stepup_fail failed"
echo "step-up-policy $stepup_pass" >> "$BASELINE_RUN"
[ "$stepup_fail" -eq 0 ] || { echo "STEP-UP POLICY SUITE FAILED"; exit 1; }

echo "=== [71/156] Dormant lifecycle suite ==="
run_step dorm_out dorm_rc ./tests/test_dormancy.sh
[ "$dorm_rc" -eq 0 ] || { echo "DORMANCY (rc=$dorm_rc)"; echo "$dorm_out" | tail -5; exit 1; }
dorm_pass=$(echo "$dorm_out" | count_matches '\\[0;32mPASS')
dorm_fail=$(echo "$dorm_out" | count_matches '\\[0;31mFAIL')
echo "dormancy: $dorm_pass passed, $dorm_fail failed"
echo "dormancy $dorm_pass" >> "$BASELINE_RUN"
[ "$dorm_fail" -eq 0 ] || { echo "DORMANCY SUITE FAILED"; exit 1; }

echo "=== [72/156] Session security suite ==="
run_step ss_out ss_rc ./tests/test_session_security.sh
[ "$ss_rc" -eq 0 ] || { echo "SESSION SECURITY (rc=$ss_rc)"; echo "$ss_out" | tail -5; exit 1; }
ss_pass=$(echo "$ss_out" | count_matches '\\[0;32mPASS')
ss_fail=$(echo "$ss_out" | count_matches '\\[0;31mFAIL')
echo "session-security: $ss_pass passed, $ss_fail failed"
echo "session-security $ss_pass" >> "$BASELINE_RUN"
[ "$ss_fail" -eq 0 ] || { echo "SESSION SECURITY SUITE FAILED"; exit 1; }

echo "=== [73/156] Reference engine suite ==="
run_step refeng_out refeng_rc ./tests/test_ref_engine.sh
[ "$refeng_rc" -eq 0 ] || { echo "REFERENCE ENGINE (rc=$refeng_rc)"; echo "$refeng_out" | tail -5; exit 1; }
refeng_pass=$(echo "$refeng_out" | count_matches '\\[0;32mPASS')
refeng_fail=$(echo "$refeng_out" | count_matches '\\[0;31mFAIL')
echo "ref-engine: $refeng_pass passed, $refeng_fail failed"
echo "ref_engine $refeng_pass" >> "$BASELINE_RUN"
[ "$refeng_fail" -eq 0 ] || { echo "REFERENCE ENGINE SUITE FAILED"; exit 1; }

echo "=== [74/156] General ledger suite ==="
run_step gl_out gl_rc ./tests/test_gl.sh
[ "$gl_rc" -eq 0 ] || { echo "GENERAL LEDGER (rc=$gl_rc)"; echo "$gl_out" | tail -5; exit 1; }
gl_pass=$(echo "$gl_out" | count_matches '\\[0;32mPASS')
gl_fail=$(echo "$gl_out" | count_matches '\\[0;31mFAIL')
echo "gl: $gl_pass passed, $gl_fail failed"
echo "gl $gl_pass" >> "$BASELINE_RUN"
[ "$gl_fail" -eq 0 ] || { echo "GENERAL LEDGER SUITE FAILED"; exit 1; }

echo "=== [75/156] Batch/EOD foundation suite ==="
run_step batch_out batch_rc ./tests/test_batch.sh
[ "$batch_rc" -eq 0 ] || { echo "BATCH/EOD (rc=$batch_rc)"; echo "$batch_out" | tail -5; exit 1; }
batch_pass=$(echo "$batch_out" | count_matches '\\[0;32mPASS')
batch_fail=$(echo "$batch_out" | count_matches '\\[0;31mFAIL')
echo "batch: $batch_pass passed, $batch_fail failed"
echo "batch $batch_pass" >> "$BASELINE_RUN"
[ "$batch_fail" -eq 0 ] || { echo "BATCH/EOD SUITE FAILED"; exit 1; }

echo "=== [76/156] Report engine suite ==="
run_step report_out report_rc ./tests/test_report.sh
[ "$report_rc" -eq 0 ] || { echo "REPORT ENGINE (rc=$report_rc)"; echo "$report_out" | tail -5; exit 1; }
report_pass=$(echo "$report_out" | count_matches '\\[0;32mPASS')
report_fail=$(echo "$report_out" | count_matches '\\[0;31mFAIL')
echo "report: $report_pass passed, $report_fail failed"
echo "report $report_pass" >> "$BASELINE_RUN"
[ "$report_fail" -eq 0 ] || { echo "REPORT ENGINE SUITE FAILED"; exit 1; }

echo "=== [77/156] Import/export foundation suite ==="
run_step import_out import_rc ./tests/test_import.sh
[ "$import_rc" -eq 0 ] || { echo "IMPORT/EXPORT (rc=$import_rc)"; echo "$import_out" | tail -5; exit 1; }
import_pass=$(echo "$import_out" | count_matches '\\[0;32mPASS')
import_fail=$(echo "$import_out" | count_matches '\\[0;31mFAIL')
echo "import: $import_pass passed, $import_fail failed"
echo "import $import_pass" >> "$BASELINE_RUN"
[ "$import_fail" -eq 0 ] || { echo "IMPORT/EXPORT SUITE FAILED"; exit 1; }

echo "=== [78/156] Fee / velocity suite ==="
run_step fee_out fee_rc ./tests/test_fee.sh
[ "$fee_rc" -eq 0 ] || { echo "FEE/VELOCITY (rc=$fee_rc)"; echo "$fee_out" | tail -5; exit 1; }
fee_pass=$(echo "$fee_out" | count_matches '\\[0;32mPASS')
fee_fail=$(echo "$fee_out" | count_matches '\\[0;31mFAIL')
echo "fee: $fee_pass passed, $fee_fail failed"
echo "fee $fee_pass" >> "$BASELINE_RUN"
[ "$fee_fail" -eq 0 ] || { echo "FEE/VELOCITY SUITE FAILED"; exit 1; }

echo "=== [79/156] EOD calendar / run suite ==="
run_step eod_out eod_rc ./tests/test_eod.sh
[ "$eod_rc" -eq 0 ] || { echo "EOD (rc=$eod_rc)"; echo "$eod_out" | tail -5; exit 1; }
eod_pass=$(echo "$eod_out" | count_matches '\\[0;32mPASS')
eod_fail=$(echo "$eod_out" | count_matches '\\[0;31mFAIL')
echo "eod: $eod_pass passed, $eod_fail failed"
echo "eod $eod_pass" >> "$BASELINE_RUN"
[ "$eod_fail" -eq 0 ] || { echo "EOD SUITE FAILED"; exit 1; }

echo "=== [80/156] Statement archive suite ==="
run_step stmt_out stmt_rc ./tests/test_statement.sh
[ "$stmt_rc" -eq 0 ] || { echo "STATEMENT (rc=$stmt_rc)"; echo "$stmt_out" | tail -5; exit 1; }
stmt_pass=$(echo "$stmt_out" | count_matches '\\[0;32mPASS')
stmt_fail=$(echo "$stmt_out" | count_matches '\\[0;31mFAIL')
echo "statement: $stmt_pass passed, $stmt_fail failed"
echo "statement $stmt_pass" >> "$BASELINE_RUN"
[ "$stmt_fail" -eq 0 ] || { echo "STATEMENT SUITE FAILED"; exit 1; }

echo "=== [81/156] EOD job execution suite ==="
run_step eodjob_out eodjob_rc ./tests/test_eod_jobs.sh
[ "$eodjob_rc" -eq 0 ] || { echo "EOD JOBS (rc=$eodjob_rc)"; echo "$eodjob_out" | tail -5; exit 1; }
eodjob_pass=$(echo "$eodjob_out" | count_matches '\\[0;32mPASS')
eodjob_fail=$(echo "$eodjob_out" | count_matches '\\[0;31mFAIL')
echo "eod-jobs: $eodjob_pass passed, $eodjob_fail failed"
echo "eod_jobs $eodjob_pass" >> "$BASELINE_RUN"
[ "$eodjob_fail" -eq 0 ] || { echo "EOD JOB SUITE FAILED"; exit 1; }

echo "=== [82/156] Reference expansion suite ==="
run_step refext_out refext_rc ./tests/test_ref_ext.sh
[ "$refext_rc" -eq 0 ] || { echo "REF EXT (rc=$refext_rc)"; echo "$refext_out" | tail -5; exit 1; }
refext_pass=$(echo "$refext_out" | count_matches '\\[0;32mPASS')
refext_fail=$(echo "$refext_out" | count_matches '\\[0;31mFAIL')
echo "ref-ext: $refext_pass passed, $refext_fail failed"
echo "ref_ext $refext_pass" >> "$BASELINE_RUN"
[ "$refext_fail" -eq 0 ] || { echo "REFERENCE EXPANSION SUITE FAILED"; exit 1; }

echo "=== [83/156] Notification center suite ==="
run_step ntf_out ntf_rc ./tests/test_notification.sh
[ "$ntf_rc" -eq 0 ] || { echo "NOTIFICATION (rc=$ntf_rc)"; echo "$ntf_out" | tail -5; exit 1; }
ntf_pass=$(echo "$ntf_out" | count_matches '\\[0;32mPASS')
ntf_fail=$(echo "$ntf_out" | count_matches '\\[0;31mFAIL')
echo "notification: $ntf_pass passed, $ntf_fail failed"
echo "notification $ntf_pass" >> "$BASELINE_RUN"
[ "$ntf_fail" -eq 0 ] || { echo "NOTIFICATION SUITE FAILED"; exit 1; }

echo "=== [84/156] Payment policy suite ==="
run_step pay_out pay_rc ./tests/test_payment.sh
[ "$pay_rc" -eq 0 ] || { echo "PAYMENT (rc=$pay_rc)"; echo "$pay_out" | tail -5; exit 1; }
pay_pass=$(echo "$pay_out" | count_matches '\\[0;32mPASS')
pay_fail=$(echo "$pay_out" | count_matches '\\[0;31mFAIL')
echo "payment: $pay_pass passed, $pay_fail failed"
echo "payment $pay_pass" >> "$BASELINE_RUN"
[ "$pay_fail" -eq 0 ] || { echo "PAYMENT SUITE FAILED"; exit 1; }

echo "=== [85/156] Reconciliation reporting suite ==="
run_step recon2_out recon2_rc ./tests/test_recon.sh
[ "$recon2_rc" -eq 0 ] || { echo "RECON (rc=$recon2_rc)"; echo "$recon2_out" | tail -5; exit 1; }
recon2_pass=$(echo "$recon2_out" | count_matches '\\[0;32mPASS')
recon2_fail=$(echo "$recon2_out" | count_matches '\\[0;31mFAIL')
echo "recon-report: $recon2_pass passed, $recon2_fail failed"
echo "recon_report $recon2_pass" >> "$BASELINE_RUN"
[ "$recon2_fail" -eq 0 ] || { echo "RECON REPORT SUITE FAILED"; exit 1; }

echo "=== [86/156] Import ledger posting suite ==="
run_step impp_out impp_rc ./tests/test_import_post.sh
[ "$impp_rc" -eq 0 ] || { echo "IMPORT POST (rc=$impp_rc)"; echo "$impp_out" | tail -5; exit 1; }
impp_pass=$(echo "$impp_out" | count_matches '\\[0;32mPASS')
impp_fail=$(echo "$impp_out" | count_matches '\\[0;31mFAIL')
echo "import-post: $impp_pass passed, $impp_fail failed"
echo "import_post $impp_pass" >> "$BASELINE_RUN"
[ "$impp_fail" -eq 0 ] || { echo "IMPORT POST SUITE FAILED"; exit 1; }

echo "=== [87/156] Report delivery suite ==="
run_step rdl_out rdl_rc ./tests/test_report_delivery.sh
[ "$rdl_rc" -eq 0 ] || { echo "REPORT DELIVERY (rc=$rdl_rc)"; echo "$rdl_out" | tail -5; exit 1; }
rdl_pass=$(echo "$rdl_out" | count_matches '\\[0;32mPASS')
rdl_fail=$(echo "$rdl_out" | count_matches '\\[0;31mFAIL')
echo "report-delivery: $rdl_pass passed, $rdl_fail failed"
echo "report_delivery $rdl_pass" >> "$BASELINE_RUN"
[ "$rdl_fail" -eq 0 ] || { echo "REPORT DELIVERY SUITE FAILED"; exit 1; }

echo "=== [88/156] Dispute operations suite ==="
run_step dsp_out dsp_rc ./tests/test_dispute_ops.sh
[ "$dsp_rc" -eq 0 ] || { echo "DISPUTE OPS (rc=$dsp_rc)"; echo "$dsp_out" | tail -5; exit 1; }
dsp_pass=$(echo "$dsp_out" | count_matches '\\[0;32mPASS')
dsp_fail=$(echo "$dsp_out" | count_matches '\\[0;31mFAIL')
echo "dispute-ops: $dsp_pass passed, $dsp_fail failed"
echo "dispute_ops $dsp_pass" >> "$BASELINE_RUN"
[ "$dsp_fail" -eq 0 ] || { echo "DISPUTE OPS SUITE FAILED"; exit 1; }

echo "=== [89/156] Retained export archive suite ==="
run_step exp_out exp_rc ./tests/test_export_archive.sh
[ "$exp_rc" -eq 0 ] || { echo "EXPORT ARCHIVE (rc=$exp_rc)"; echo "$exp_out" | tail -5; exit 1; }
exp_pass=$(echo "$exp_out" | count_matches '\\[0;32mPASS')
exp_fail=$(echo "$exp_out" | count_matches '\\[0;31mFAIL')
echo "export-archive: $exp_pass passed, $exp_fail failed"
echo "export_archive $exp_pass" >> "$BASELINE_RUN"
[ "$exp_fail" -eq 0 ] || { echo "EXPORT ARCHIVE SUITE FAILED"; exit 1; }

echo "=== [90/156] Reconciliation auto-assignment suite ==="
run_step rcp_out rcp_rc ./tests/test_recon_ops.sh
[ "$rcp_rc" -eq 0 ] || { echo "RECON OPS (rc=$rcp_rc)"; echo "$rcp_out" | tail -5; exit 1; }
rcp_pass=$(echo "$rcp_out" | count_matches '\\[0;32mPASS')
rcp_fail=$(echo "$rcp_out" | count_matches '\\[0;31mFAIL')
echo "recon-ops: $rcp_pass passed, $rcp_fail failed"
echo "recon_ops $rcp_pass" >> "$BASELINE_RUN"
[ "$rcp_fail" -eq 0 ] || { echo "RECON OPS SUITE FAILED"; exit 1; }

echo "=== [91/156] Operations alert center suite ==="
run_step alt_out alt_rc ./tests/test_alert_center.sh
[ "$alt_rc" -eq 0 ] || { echo "ALERT CENTER (rc=$alt_rc)"; echo "$alt_out" | tail -5; exit 1; }
alt_pass=$(echo "$alt_out" | count_matches '\\[0;32mPASS')
alt_fail=$(echo "$alt_out" | count_matches '\\[0;31mFAIL')
echo "alert-center: $alt_pass passed, $alt_fail failed"
echo "alert_center $alt_pass" >> "$BASELINE_RUN"
[ "$alt_fail" -eq 0 ] || { echo "ALERT CENTER SUITE FAILED"; exit 1; }

echo "=== [92/156] Payment policy enforcement suite ==="
run_step pe_out pe_rc ./tests/test_payment_enforcement.sh
[ "$pe_rc" -eq 0 ] || { echo "PAYMENT ENFORCEMENT (rc=$pe_rc)"; echo "$pe_out" | tail -5; exit 1; }
pe_pass=$(echo "$pe_out" | count_matches '\\[0;32mPASS')
pe_fail=$(echo "$pe_out" | count_matches '\\[0;31mFAIL')
echo "payment-enforcement: $pe_pass passed, $pe_fail failed"
echo "payment_enforcement $pe_pass" >> "$BASELINE_RUN"
[ "$pe_fail" -eq 0 ] || { echo "PAYMENT ENFORCEMENT SUITE FAILED"; exit 1; }

echo "=== [93/156] Operational dashboard suite ==="
run_step dsh_out dsh_rc ./tests/test_dashboard.sh
[ "$dsh_rc" -eq 0 ] || { echo "DASHBOARD (rc=$dsh_rc)"; echo "$dsh_out" | tail -5; exit 1; }
dsh_pass=$(echo "$dsh_out" | count_matches '\\[0;32mPASS')
dsh_fail=$(echo "$dsh_out" | count_matches '\\[0;31mFAIL')
echo "dashboard: $dsh_pass passed, $dsh_fail failed"
echo "dashboard $dsh_pass" >> "$BASELINE_RUN"
[ "$dsh_fail" -eq 0 ] || { echo "DASHBOARD SUITE FAILED"; exit 1; }

echo "=== [94/156] Statement reconciliation suite ==="
run_step src_out src_rc ./tests/test_statement_recon.sh
[ "$src_rc" -eq 0 ] || { echo "STATEMENT RECON (rc=$src_rc)"; echo "$src_out" | tail -5; exit 1; }
src_pass=$(echo "$src_out" | count_matches '\\[0;32mPASS')
src_fail=$(echo "$src_out" | count_matches '\\[0;31mFAIL')
echo "statement-recon: $src_pass passed, $src_fail failed"
echo "statement_recon $src_pass" >> "$BASELINE_RUN"
[ "$src_fail" -eq 0 ] || { echo "STATEMENT RECON SUITE FAILED"; exit 1; }

echo "=== [95/156] Report schedule history suite ==="
run_step rsh_out rsh_rc ./tests/test_schedule_history.sh
[ "$rsh_rc" -eq 0 ] || { echo "SCHEDULE HISTORY (rc=$rsh_rc)"; echo "$rsh_out" | tail -5; exit 1; }
rsh_pass=$(echo "$rsh_out" | count_matches '\\[0;32mPASS')
rsh_fail=$(echo "$rsh_out" | count_matches '\\[0;31mFAIL')
echo "schedule-history: $rsh_pass passed, $rsh_fail failed"
echo "schedule_history $rsh_pass" >> "$BASELINE_RUN"
[ "$rsh_fail" -eq 0 ] || { echo "SCHEDULE HISTORY SUITE FAILED"; exit 1; }

echo "=== [96/156] Standing payment instruction suite ==="
run_step pic_out pic_rc ./tests/test_payment_instruction.sh
[ "$pic_rc" -eq 0 ] || { echo "PAYMENT INSTRUCTION (rc=$pic_rc)"; echo "$pic_out" | tail -5; exit 1; }
pic_pass=$(echo "$pic_out" | count_matches '\\[0;32mPASS')
pic_fail=$(echo "$pic_out" | count_matches '\\[0;31mFAIL')
echo "payment-instruction: $pic_pass passed, $pic_fail failed"
echo "payment_instruction $pic_pass" >> "$BASELINE_RUN"
[ "$pic_fail" -eq 0 ] || { echo "PAYMENT INSTRUCTION SUITE FAILED"; exit 1; }

echo "=== [97/156] On-call routing suite ==="
run_step onc_out onc_rc ./tests/test_oncall.sh
[ "$onc_rc" -eq 0 ] || { echo "ONCALL (rc=$onc_rc)"; echo "$onc_out" | tail -5; exit 1; }
onc_pass=$(echo "$onc_out" | count_matches '\\[0;32mPASS')
onc_fail=$(echo "$onc_out" | count_matches '\\[0;31mFAIL')
echo "oncall: $onc_pass passed, $onc_fail failed"
echo "oncall $onc_pass" >> "$BASELINE_RUN"
[ "$onc_fail" -eq 0 ] || { echo "ONCALL SUITE FAILED"; exit 1; }

echo "=== [98/156] Audit analytics suite ==="
run_step aan_out aan_rc ./tests/test_audit_analytics.sh
[ "$aan_rc" -eq 0 ] || { echo "AUDIT ANALYTICS (rc=$aan_rc)"; echo "$aan_out" | tail -5; exit 1; }
aan_pass=$(echo "$aan_out" | count_matches '\\[0;32mPASS')
aan_fail=$(echo "$aan_out" | count_matches '\\[0;31mFAIL')
echo "audit-analytics: $aan_pass passed, $aan_fail failed"
echo "audit_analytics $aan_pass" >> "$BASELINE_RUN"
[ "$aan_fail" -eq 0 ] || { echo "AUDIT ANALYTICS SUITE FAILED"; exit 1; }

echo "=== [99/156] Import reconciliation suite ==="
run_step irc_out irc_rc ./tests/test_import_recon.sh
[ "$irc_rc" -eq 0 ] || { echo "IMPORT RECON (rc=$irc_rc)"; echo "$irc_out" | tail -5; exit 1; }
irc_pass=$(echo "$irc_out" | count_matches '\\[0;32mPASS')
irc_fail=$(echo "$irc_out" | count_matches '\\[0;31mFAIL')
echo "import-recon: $irc_pass passed, $irc_fail failed"
echo "import_recon $irc_pass" >> "$BASELINE_RUN"
[ "$irc_fail" -eq 0 ] || { echo "IMPORT RECON SUITE FAILED"; exit 1; }

echo "=== [100/156] Reconciliation exception suite ==="
run_step rex_out rex_rc ./tests/test_recon_exception.sh
[ "$rex_rc" -eq 0 ] || { echo "RECON EXCEPTION (rc=$rex_rc)"; echo "$rex_out" | tail -5; exit 1; }
rex_pass=$(echo "$rex_out" | count_matches '\\[0;32mPASS')
rex_fail=$(echo "$rex_out" | count_matches '\\[0;31mFAIL')
echo "recon-exception: $rex_pass passed, $rex_fail failed"
echo "recon_exception $rex_pass" >> "$BASELINE_RUN"
[ "$rex_fail" -eq 0 ] || { echo "RECON EXCEPTION SUITE FAILED"; exit 1; }

echo "=== [101/156] Dispute customer notification suite ==="
run_step dsn_out dsn_rc ./tests/test_dispute_notify.sh
[ "$dsn_rc" -eq 0 ] || { echo "DISPUTE NOTIFY (rc=$dsn_rc)"; echo "$dsn_out" | tail -5; exit 1; }
dsn_pass=$(echo "$dsn_out" | count_matches '\\[0;32mPASS')
dsn_fail=$(echo "$dsn_out" | count_matches '\\[0;31mFAIL')
echo "dispute-notify: $dsn_pass passed, $dsn_fail failed"
echo "dispute_notify $dsn_pass" >> "$BASELINE_RUN"
[ "$dsn_fail" -eq 0 ] || { echo "DISPUTE NOTIFY SUITE FAILED"; exit 1; }

echo "=== [102/156] Export download streaming suite ==="
run_step xst_out xst_rc ./tests/test_export_stream.sh
[ "$xst_rc" -eq 0 ] || { echo "EXPORT STREAM (rc=$xst_rc)"; echo "$xst_out" | tail -5; exit 1; }
xst_pass=$(echo "$xst_out" | count_matches '\\[0;32mPASS')
xst_fail=$(echo "$xst_out" | count_matches '\\[0;31mFAIL')
echo "export-stream: $xst_pass passed, $xst_fail failed"
echo "export_stream $xst_pass" >> "$BASELINE_RUN"
[ "$xst_fail" -eq 0 ] || { echo "EXPORT STREAM SUITE FAILED"; exit 1; }

echo "=== [103/156] Alert escalation automation suite ==="
run_step ale_out ale_rc ./tests/test_alert_escalation.sh
[ "$ale_rc" -eq 0 ] || { echo "ALERT ESCALATION (rc=$ale_rc)"; echo "$ale_out" | tail -5; exit 1; }
ale_pass=$(echo "$ale_out" | count_matches '\\[0;32mPASS')
ale_fail=$(echo "$ale_out" | count_matches '\\[0;31mFAIL')
echo "alert-escalation: $ale_pass passed, $ale_fail failed"
echo "alert_escalation $ale_pass" >> "$BASELINE_RUN"
[ "$ale_fail" -eq 0 ] || { echo "ALERT ESCALATION SUITE FAILED"; exit 1; }

echo "=== [104/156] Audit drill-down suite ==="
run_step adr_out adr_rc ./tests/test_audit_drilldown.sh
[ "$adr_rc" -eq 0 ] || { echo "AUDIT DRILLDOWN (rc=$adr_rc)"; echo "$adr_out" | tail -5; exit 1; }
adr_pass=$(echo "$adr_out" | count_matches '\\[0;32mPASS')
adr_fail=$(echo "$adr_out" | count_matches '\\[0;31mFAIL')
echo "audit-drilldown: $adr_pass passed, $adr_fail failed"
echo "audit_drilldown $adr_pass" >> "$BASELINE_RUN"
[ "$adr_fail" -eq 0 ] || { echo "AUDIT DRILLDOWN SUITE FAILED"; exit 1; }

echo "=== [105/156] Compliance export suite ==="
run_step cex_out cex_rc ./tests/test_compliance_export.sh
[ "$cex_rc" -eq 0 ] || { echo "COMPLIANCE EXPORT (rc=$cex_rc)"; echo "$cex_out" | tail -5; exit 1; }
cex_pass=$(echo "$cex_out" | count_matches '\\[0;32mPASS')
cex_fail=$(echo "$cex_out" | count_matches '\\[0;31mFAIL')
echo "compliance-export: $cex_pass passed, $cex_fail failed"
echo "compliance_export $cex_pass" >> "$BASELINE_RUN"
[ "$cex_fail" -eq 0 ] || { echo "COMPLIANCE EXPORT SUITE FAILED"; exit 1; }

echo "=== [106/156] Payment hold suite ==="
run_step phl_out phl_rc ./tests/test_payment_hold.sh
[ "$phl_rc" -eq 0 ] || { echo "PAYMENT HOLD (rc=$phl_rc)"; echo "$phl_out" | tail -5; exit 1; }
phl_pass=$(echo "$phl_out" | count_matches '\\[0;32mPASS')
phl_fail=$(echo "$phl_out" | count_matches '\\[0;31mFAIL')
echo "payment-hold: $phl_pass passed, $phl_fail failed"
echo "payment_hold $phl_pass" >> "$BASELINE_RUN"
[ "$phl_fail" -eq 0 ] || { echo "PAYMENT HOLD SUITE FAILED"; exit 1; }

echo "=== [107/156] On-call delivery suite ==="
run_step odl_out odl_rc ./tests/test_oncall_delivery.sh
[ "$odl_rc" -eq 0 ] || { echo "ONCALL DELIVERY (rc=$odl_rc)"; echo "$odl_out" | tail -5; exit 1; }
odl_pass=$(echo "$odl_out" | count_matches '\\[0;32mPASS')
odl_fail=$(echo "$odl_out" | count_matches '\\[0;31mFAIL')
echo "oncall-delivery: $odl_pass passed, $odl_fail failed"
echo "oncall_delivery $odl_pass" >> "$BASELINE_RUN"
[ "$odl_fail" -eq 0 ] || { echo "ONCALL DELIVERY SUITE FAILED"; exit 1; }

echo "=== [108/156] Compliance retention suite ==="
run_step crt_out crt_rc ./tests/test_compliance_retention.sh
[ "$crt_rc" -eq 0 ] || { echo "COMPLIANCE RETENTION (rc=$crt_rc)"; echo "$crt_out" | tail -5; exit 1; }
crt_pass=$(echo "$crt_out" | count_matches '\\[0;32mPASS')
crt_fail=$(echo "$crt_out" | count_matches '\\[0;31mFAIL')
echo "compliance-retention: $crt_pass passed, $crt_fail failed"
echo "compliance_retention $crt_pass" >> "$BASELINE_RUN"
[ "$crt_fail" -eq 0 ] || { echo "COMPLIANCE RETENTION SUITE FAILED"; exit 1; }

echo "=== [109/156] Report scheduler suite ==="
run_step rsc_out rsc_rc ./tests/test_report_scheduler.sh
[ "$rsc_rc" -eq 0 ] || { echo "REPORT SCHEDULER (rc=$rsc_rc)"; echo "$rsc_out" | tail -5; exit 1; }
rsc_pass=$(echo "$rsc_out" | count_matches '\\[0;32mPASS')
rsc_fail=$(echo "$rsc_out" | count_matches '\\[0;31mFAIL')
echo "report-scheduler: $rsc_pass passed, $rsc_fail failed"
echo "report_scheduler $rsc_pass" >> "$BASELINE_RUN"
[ "$rsc_fail" -eq 0 ] || { echo "REPORT SCHEDULER SUITE FAILED"; exit 1; }

echo "=== [110/156] Settlement reconciliation suite ==="
run_step str_out str_rc ./tests/test_settlement_recon.sh
[ "$str_rc" -eq 0 ] || { echo "SETTLEMENT RECON (rc=$str_rc)"; echo "$str_out" | tail -5; exit 1; }
str_pass=$(echo "$str_out" | count_matches '\\[0;32mPASS')
str_fail=$(echo "$str_out" | count_matches '\\[0;31mFAIL')
echo "settlement-recon: $str_pass passed, $str_fail failed"
echo "settlement_recon $str_pass" >> "$BASELINE_RUN"
[ "$str_fail" -eq 0 ] || { echo "SETTLEMENT RECON SUITE FAILED"; exit 1; }

echo "=== [111/156] Statement delivery suite ==="
run_step stl_out stl_rc ./tests/test_statement_delivery.sh
[ "$stl_rc" -eq 0 ] || { echo "STATEMENT DELIVERY (rc=$stl_rc)"; echo "$stl_out" | tail -5; exit 1; }
stl_pass=$(echo "$stl_out" | count_matches '\\[0;32mPASS')
stl_fail=$(echo "$stl_out" | count_matches '\\[0;31mFAIL')
echo "statement-delivery: $stl_pass passed, $stl_fail failed"
echo "statement_delivery $stl_pass" >> "$BASELINE_RUN"
[ "$stl_fail" -eq 0 ] || { echo "STATEMENT DELIVERY SUITE FAILED"; exit 1; }

echo "=== [112/156] Audit snapshot suite ==="
run_step asn_out asn_rc ./tests/test_audit_snapshot.sh
[ "$asn_rc" -eq 0 ] || { echo "AUDIT SNAPSHOT (rc=$asn_rc)"; echo "$asn_out" | tail -5; exit 1; }
asn_pass=$(echo "$asn_out" | count_matches '\\[0;32mPASS')
asn_fail=$(echo "$asn_out" | count_matches '\\[0;31mFAIL')
echo "audit-snapshot: $asn_pass passed, $asn_fail failed"
echo "audit_snapshot $asn_pass" >> "$BASELINE_RUN"
[ "$asn_fail" -eq 0 ] || { echo "AUDIT SNAPSHOT SUITE FAILED"; exit 1; }

echo "=== [113/156] Report archive suite ==="
run_step rpa_out rpa_rc ./tests/test_report_archive.sh
[ "$rpa_rc" -eq 0 ] || { echo "REPORT ARCHIVE (rc=$rpa_rc)"; echo "$rpa_out" | tail -5; exit 1; }
rpa_pass=$(echo "$rpa_out" | count_matches '\\[0;32mPASS')
rpa_fail=$(echo "$rpa_out" | count_matches '\\[0;31mFAIL')
echo "report-archive: $rpa_pass passed, $rpa_fail failed"
echo "report_archive $rpa_pass" >> "$BASELINE_RUN"
[ "$rpa_fail" -eq 0 ] || { echo "REPORT ARCHIVE SUITE FAILED"; exit 1; }

echo "=== [114/156] KYC review suite ==="
run_step kyc_out kyc_rc ./tests/test_kyc_review.sh
[ "$kyc_rc" -eq 0 ] || { echo "KYC REVIEW (rc=$kyc_rc)"; echo "$kyc_out" | tail -5; exit 1; }
kyc_pass=$(echo "$kyc_out" | count_matches '\\[0;32mPASS')
kyc_fail=$(echo "$kyc_out" | count_matches '\\[0;31mFAIL')
echo "kyc-review: $kyc_pass passed, $kyc_fail failed"
echo "kyc_review $kyc_pass" >> "$BASELINE_RUN"
[ "$kyc_fail" -eq 0 ] || { echo "KYC REVIEW SUITE FAILED"; exit 1; }

echo "=== [115/156] Regulatory report suite ==="
run_step reg_out reg_rc ./tests/test_regulatory_report.sh
[ "$reg_rc" -eq 0 ] || { echo "REGULATORY REPORT (rc=$reg_rc)"; echo "$reg_out" | tail -5; exit 1; }
reg_pass=$(echo "$reg_out" | count_matches '\\[0;32mPASS')
reg_fail=$(echo "$reg_out" | count_matches '\\[0;31mFAIL')
echo "regulatory-report: $reg_pass passed, $reg_fail failed"
echo "regulatory_report $reg_pass" >> "$BASELINE_RUN"
[ "$reg_fail" -eq 0 ] || { echo "REGULATORY REPORT SUITE FAILED"; exit 1; }

echo "=== [116/156] Loan suite ==="
run_step loan_out loan_rc ./tests/test_loan.sh
[ "$loan_rc" -eq 0 ] || { echo "LOAN (rc=$loan_rc)"; echo "$loan_out" | tail -5; exit 1; }
loan_pass=$(echo "$loan_out" | count_matches '\\[0;32mPASS')
loan_fail=$(echo "$loan_out" | count_matches '\\[0;31mFAIL')
echo "loan: $loan_pass passed, $loan_fail failed"
echo "loan $loan_pass" >> "$BASELINE_RUN"
[ "$loan_fail" -eq 0 ] || { echo "LOAN SUITE FAILED"; exit 1; }

echo "=== [117/156] Deposit suite ==="
run_step dep_out dep_rc ./tests/test_deposit.sh
[ "$dep_rc" -eq 0 ] || { echo "DEPOSIT (rc=$dep_rc)"; echo "$dep_out" | tail -5; exit 1; }
dep_pass=$(echo "$dep_out" | count_matches '\\[0;32mPASS')
dep_fail=$(echo "$dep_out" | count_matches '\\[0;31mFAIL')
echo "deposit: $dep_pass passed, $dep_fail failed"
echo "deposit $dep_pass" >> "$BASELINE_RUN"
[ "$dep_fail" -eq 0 ] || { echo "DEPOSIT SUITE FAILED"; exit 1; }

echo "=== [118/156] FX deal suite ==="
run_step fxd_out fxd_rc ./tests/test_fx_deal.sh
[ "$fxd_rc" -eq 0 ] || { echo "FX DEAL (rc=$fxd_rc)"; echo "$fxd_out" | tail -5; exit 1; }
fxd_pass=$(echo "$fxd_out" | count_matches '\\[0;32mPASS')
fxd_fail=$(echo "$fxd_out" | count_matches '\\[0;31mFAIL')
echo "fx-deal: $fxd_pass passed, $fxd_fail failed"
echo "fx_deal $fxd_pass" >> "$BASELINE_RUN"
[ "$fxd_fail" -eq 0 ] || { echo "FX DEAL SUITE FAILED"; exit 1; }

echo "=== [119/156] Treasury position suite ==="
run_step trp_out trp_rc ./tests/test_treasury_position.sh
[ "$trp_rc" -eq 0 ] || { echo "TREASURY POSITION (rc=$trp_rc)"; echo "$trp_out" | tail -5; exit 1; }
trp_pass=$(echo "$trp_out" | count_matches '\\[0;32mPASS')
trp_fail=$(echo "$trp_out" | count_matches '\\[0;31mFAIL')
echo "treasury-position: $trp_pass passed, $trp_fail failed"
echo "treasury_position $trp_pass" >> "$BASELINE_RUN"
[ "$trp_fail" -eq 0 ] || { echo "TREASURY POSITION SUITE FAILED"; exit 1; }

echo "=== [120/156] Card suite ==="
run_step card_out card_rc ./tests/test_card.sh
[ "$card_rc" -eq 0 ] || { echo "CARD (rc=$card_rc)"; echo "$card_out" | tail -5; exit 1; }
card_pass=$(echo "$card_out" | count_matches '\\[0;32mPASS')
card_fail=$(echo "$card_out" | count_matches '\\[0;31mFAIL')
echo "card: $card_pass passed, $card_fail failed"
echo "card $card_pass" >> "$BASELINE_RUN"
[ "$card_fail" -eq 0 ] || { echo "CARD SUITE FAILED"; exit 1; }

echo "=== [121/156] Tax report suite ==="
run_step tax_out tax_rc ./tests/test_tax_report.sh
[ "$tax_rc" -eq 0 ] || { echo "TAX REPORT (rc=$tax_rc)"; echo "$tax_out" | tail -5; exit 1; }
tax_pass=$(echo "$tax_out" | count_matches '\\[0;32mPASS')
tax_fail=$(echo "$tax_out" | count_matches '\\[0;31mFAIL')
echo "tax-report: $tax_pass passed, $tax_fail failed"
echo "tax_report $tax_pass" >> "$BASELINE_RUN"
[ "$tax_fail" -eq 0 ] || { echo "TAX REPORT SUITE FAILED"; exit 1; }

echo "=== [122/156] Policy attestation suite ==="
run_step pat_out pat_rc ./tests/test_policy_attestation.sh
[ "$pat_rc" -eq 0 ] || { echo "POLICY ATTESTATION (rc=$pat_rc)"; echo "$pat_out" | tail -5; exit 1; }
pat_pass=$(echo "$pat_out" | count_matches '\\[0;32mPASS')
pat_fail=$(echo "$pat_out" | count_matches '\\[0;31mFAIL')
echo "policy-attestation: $pat_pass passed, $pat_fail failed"
echo "policy_attestation $pat_pass" >> "$BASELINE_RUN"
[ "$pat_fail" -eq 0 ] || { echo "POLICY ATTESTATION SUITE FAILED"; exit 1; }

echo "=== [123/156] Regulatory calendar suite ==="
run_step rcl_out rcl_rc ./tests/test_regulatory_calendar.sh
[ "$rcl_rc" -eq 0 ] || { echo "REGULATORY CALENDAR (rc=$rcl_rc)"; echo "$rcl_out" | tail -5; exit 1; }
rcl_pass=$(echo "$rcl_out" | count_matches '\\[0;32mPASS')
rcl_fail=$(echo "$rcl_out" | count_matches '\\[0;31mFAIL')
echo "regulatory-calendar: $rcl_pass passed, $rcl_fail failed"
echo "regulatory_calendar $rcl_pass" >> "$BASELINE_RUN"
[ "$rcl_fail" -eq 0 ] || { echo "REGULATORY CALENDAR SUITE FAILED"; exit 1; }

echo "=== [124/156] Budget suite ==="
run_step bud_out bud_rc ./tests/test_budget.sh
[ "$bud_rc" -eq 0 ] || { echo "BUDGET (rc=$bud_rc)"; echo "$bud_out" | tail -5; exit 1; }
bud_pass=$(echo "$bud_out" | count_matches '\\[0;32mPASS')
bud_fail=$(echo "$bud_out" | count_matches '\\[0;31mFAIL')
echo "budget: $bud_pass passed, $bud_fail failed"
echo "budget $bud_pass" >> "$BASELINE_RUN"
[ "$bud_fail" -eq 0 ] || { echo "BUDGET SUITE FAILED"; exit 1; }

echo "=== [125/156] Procurement suite ==="
run_step prc_out prc_rc ./tests/test_procurement.sh
[ "$prc_rc" -eq 0 ] || { echo "PROCUREMENT (rc=$prc_rc)"; echo "$prc_out" | tail -5; exit 1; }
prc_pass=$(echo "$prc_out" | count_matches '\\[0;32mPASS')
prc_fail=$(echo "$prc_out" | count_matches '\\[0;31mFAIL')
echo "procurement: $prc_pass passed, $prc_fail failed"
echo "procurement $prc_pass" >> "$BASELINE_RUN"
[ "$prc_fail" -eq 0 ] || { echo "PROCUREMENT SUITE FAILED"; exit 1; }

echo "=== [126/156] Vendor suite ==="
run_step vnd_out vnd_rc ./tests/test_vendor.sh
[ "$vnd_rc" -eq 0 ] || { echo "VENDOR (rc=$vnd_rc)"; echo "$vnd_out" | tail -5; exit 1; }
vnd_pass=$(echo "$vnd_out" | count_matches '\\[0;32mPASS')
vnd_fail=$(echo "$vnd_out" | count_matches '\\[0;31mFAIL')
echo "vendor: $vnd_pass passed, $vnd_fail failed"
echo "vendor $vnd_pass" >> "$BASELINE_RUN"
[ "$vnd_fail" -eq 0 ] || { echo "VENDOR SUITE FAILED"; exit 1; }

echo "=== [127/156] Asset suite ==="
run_step ast_out ast_rc ./tests/test_asset.sh
[ "$ast_rc" -eq 0 ] || { echo "ASSET (rc=$ast_rc)"; echo "$ast_out" | tail -5; exit 1; }
ast_pass=$(echo "$ast_out" | count_matches '\\[0;32mPASS')
ast_fail=$(echo "$ast_out" | count_matches '\\[0;31mFAIL')
echo "asset: $ast_pass passed, $ast_fail failed"
echo "asset $ast_pass" >> "$BASELINE_RUN"
[ "$ast_fail" -eq 0 ] || { echo "ASSET SUITE FAILED"; exit 1; }

echo "=== [128/156] Vendor risk suite ==="
run_step vrk_out vrk_rc ./tests/test_vendor_risk.sh
[ "$vrk_rc" -eq 0 ] || { echo "VENDOR RISK (rc=$vrk_rc)"; echo "$vrk_out" | tail -5; exit 1; }
vrk_pass=$(echo "$vrk_out" | count_matches '\\[0;32mPASS')
vrk_fail=$(echo "$vrk_out" | count_matches '\\[0;31mFAIL')
echo "vendor-risk: $vrk_pass passed, $vrk_fail failed"
echo "vendor_risk $vrk_pass" >> "$BASELINE_RUN"
[ "$vrk_fail" -eq 0 ] || { echo "VENDOR RISK SUITE FAILED"; exit 1; }

echo "=== [129/156] Asset maintenance suite ==="
run_step amt_out amt_rc ./tests/test_asset_maintenance.sh
[ "$amt_rc" -eq 0 ] || { echo "ASSET MAINTENANCE (rc=$amt_rc)"; echo "$amt_out" | tail -5; exit 1; }
amt_pass=$(echo "$amt_out" | count_matches '\\[0;32mPASS')
amt_fail=$(echo "$amt_out" | count_matches '\\[0;31mFAIL')
echo "asset-maintenance: $amt_pass passed, $amt_fail failed"
echo "asset_maintenance $amt_pass" >> "$BASELINE_RUN"
[ "$amt_fail" -eq 0 ] || { echo "ASSET MAINTENANCE SUITE FAILED"; exit 1; }

echo "=== [131/156] Risk screening suite ==="
run_step rsk_out rsk_rc ./tests/test_risk_screening.sh
[ "$rsk_rc" -eq 0 ] || { echo "RISK SCREENING (rc=$rsk_rc)"; echo "$rsk_out" | tail -5; exit 1; }
rsk_pass=$(echo "$rsk_out" | count_matches '\\[0;32mPASS')
rsk_fail=$(echo "$rsk_out" | count_matches '\\[0;31mFAIL')
echo "risk-screening: $rsk_pass passed, $rsk_fail failed"
echo "risk_screening $rsk_pass" >> "$BASELINE_RUN"
[ "$rsk_fail" -eq 0 ] || { echo "RISK SCREENING SUITE FAILED"; exit 1; }

echo "=== [132/156] Sanctions hold suite ==="
run_step shl_out shl_rc ./tests/test_sanctions_hold.sh
[ "$shl_rc" -eq 0 ] || { echo "SANCTIONS HOLD (rc=$shl_rc)"; echo "$shl_out" | tail -5; exit 1; }
shl_pass=$(echo "$shl_out" | count_matches '\\[0;32mPASS')
shl_fail=$(echo "$shl_out" | count_matches '\\[0;31mFAIL')
echo "sanctions-hold: $shl_pass passed, $shl_fail failed"
echo "sanctions_hold $shl_pass" >> "$BASELINE_RUN"
[ "$shl_fail" -eq 0 ] || { echo "SANCTIONS HOLD SUITE FAILED"; exit 1; }

echo "=== [133/156] Fraud ops suite ==="
run_step fop_out fop_rc ./tests/test_fraud_ops.sh
[ "$fop_rc" -eq 0 ] || { echo "FRAUD OPS (rc=$fop_rc)"; echo "$fop_out" | tail -5; exit 1; }
fop_pass=$(echo "$fop_out" | count_matches '\\[0;32mPASS')
fop_fail=$(echo "$fop_out" | count_matches '\\[0;31mFAIL')
echo "fraud-ops: $fop_pass passed, $fop_fail failed"
echo "fraud_ops $fop_pass" >> "$BASELINE_RUN"
[ "$fop_fail" -eq 0 ] || { echo "FRAUD OPS SUITE FAILED"; exit 1; }

echo "=== [134/156] LBPUE suite ==="
run_step lbp_out lbp_rc ./tests/test_lbpue.sh
[ "$lbp_rc" -eq 0 ] || { echo "LBPUE (rc=$lbp_rc)"; echo "$lbp_out" | tail -5; exit 1; }
lbp_pass=$(echo "$lbp_out" | count_matches '\\[0;32mPASS')
lbp_fail=$(echo "$lbp_out" | count_matches '\\[0;31mFAIL')
echo "lbpue: $lbp_pass passed, $lbp_fail failed"
echo "lbpue $lbp_pass" >> "$BASELINE_RUN"
[ "$lbp_fail" -eq 0 ] || { echo "LBPUE SUITE FAILED"; exit 1; }

echo "=== [135/156] GL revaluation suite ==="
run_step grl_out grl_rc ./tests/test_gl_reval.sh
[ "$grl_rc" -eq 0 ] || { echo "GL REVAL (rc=$grl_rc)"; echo "$grl_out" | tail -5; exit 1; }
grl_pass=$(echo "$grl_out" | count_matches '\\[0;32mPASS')
grl_fail=$(echo "$grl_out" | count_matches '\\[0;31mFAIL')
echo "gl-reval: $grl_pass passed, $grl_fail failed"
echo "gl_reval $grl_pass" >> "$BASELINE_RUN"
[ "$grl_fail" -eq 0 ] || { echo "GL REVAL SUITE FAILED"; exit 1; }

echo "=== [136/156] GL period close suite ==="
run_step gpc_out gpc_rc ./tests/test_gl_period_close.sh
[ "$gpc_rc" -eq 0 ] || { echo "GL PERIOD CLOSE (rc=$gpc_rc)"; echo "$gpc_out" | tail -5; exit 1; }
gpc_pass=$(echo "$gpc_out" | count_matches '\\[0;32mPASS')
gpc_fail=$(echo "$gpc_out" | count_matches '\\[0;31mFAIL')
echo "gl-period-close: $gpc_pass passed, $gpc_fail failed"
echo "gl_period_close $gpc_pass" >> "$BASELINE_RUN"
[ "$gpc_fail" -eq 0 ] || { echo "GL PERIOD CLOSE SUITE FAILED"; exit 1; }

echo "=== [137/156] Fee waiver suite ==="
run_step fwv_out fwv_rc ./tests/test_fee_waiver.sh
[ "$fwv_rc" -eq 0 ] || { echo "FEE WAIVER (rc=$fwv_rc)"; echo "$fwv_out" | tail -5; exit 1; }
fwv_pass=$(echo "$fwv_out" | count_matches '\\[0;32mPASS')
fwv_fail=$(echo "$fwv_out" | count_matches '\\[0;31mFAIL')
echo "fee-waiver: $fwv_pass passed, $fwv_fail failed"
echo "fee_waiver $fwv_pass" >> "$BASELINE_RUN"
[ "$fwv_fail" -eq 0 ] || { echo "FEE WAIVER SUITE FAILED"; exit 1; }

echo "=== [138/156] Limit profile suite ==="
run_step lpr_out lpr_rc ./tests/test_limit_profile.sh
[ "$lpr_rc" -eq 0 ] || { echo "LIMIT PROFILE (rc=$lpr_rc)"; echo "$lpr_out" | tail -5; exit 1; }
lpr_pass=$(echo "$lpr_out" | count_matches '\\[0;32mPASS')
lpr_fail=$(echo "$lpr_out" | count_matches '\\[0;31mFAIL')
echo "limit-profile: $lpr_pass passed, $lpr_fail failed"
echo "limit_profile $lpr_pass" >> "$BASELINE_RUN"
[ "$lpr_fail" -eq 0 ] || { echo "LIMIT PROFILE SUITE FAILED"; exit 1; }

echo "=== [139/156] Legal hold suite ==="
run_step lho_out lho_rc ./tests/test_legal_hold.sh
[ "$lho_rc" -eq 0 ] || { echo "LEGAL HOLD (rc=$lho_rc)"; echo "$lho_out" | tail -5; exit 1; }
lho_pass=$(echo "$lho_out" | count_matches '\\[0;32mPASS')
lho_fail=$(echo "$lho_out" | count_matches '\\[0;31mFAIL')
echo "legal-hold: $lho_pass passed, $lho_fail failed"
echo "legal_hold $lho_pass" >> "$BASELINE_RUN"
[ "$lho_fail" -eq 0 ] || { echo "LEGAL HOLD SUITE FAILED"; exit 1; }

echo "=== [140/156] Key rotation suite ==="
run_step kro_out kro_rc ./tests/test_key_rotation.sh
[ "$kro_rc" -eq 0 ] || { echo "KEY ROTATION (rc=$kro_rc)"; echo "$kro_out" | tail -5; exit 1; }
kro_pass=$(echo "$kro_out" | count_matches '\\[0;32mPASS')
kro_fail=$(echo "$kro_out" | count_matches '\\[0;31mFAIL')
echo "key-rotation: $kro_pass passed, $kro_fail failed"
echo "key_rotation $kro_pass" >> "$BASELINE_RUN"
[ "$kro_fail" -eq 0 ] || { echo "KEY ROTATION SUITE FAILED"; exit 1; }

echo "=== [141/156] DSAR suite ==="
run_step dsr_out dsr_rc ./tests/test_dsar.sh
[ "$dsr_rc" -eq 0 ] || { echo "DSAR (rc=$dsr_rc)"; echo "$dsr_out" | tail -5; exit 1; }
dsr_pass=$(echo "$dsr_out" | count_matches '\\[0;32mPASS')
dsr_fail=$(echo "$dsr_out" | count_matches '\\[0;31mFAIL')
echo "dsar: $dsr_pass passed, $dsr_fail failed"
echo "dsar $dsr_pass" >> "$BASELINE_RUN"
[ "$dsr_fail" -eq 0 ] || { echo "DSAR SUITE FAILED"; exit 1; }

echo "=== [142/156] Retention job suite ==="
run_step rtj_out rtj_rc ./tests/test_retention_job.sh
[ "$rtj_rc" -eq 0 ] || { echo "RETENTION JOB (rc=$rtj_rc)"; echo "$rtj_out" | tail -5; exit 1; }
rtj_pass=$(echo "$rtj_out" | count_matches '\\[0;32mPASS')
rtj_fail=$(echo "$rtj_out" | count_matches '\\[0;31mFAIL')
echo "retention-job: $rtj_pass passed, $rtj_fail failed"
echo "retention_job $rtj_pass" >> "$BASELINE_RUN"
[ "$rtj_fail" -eq 0 ] || { echo "RETENTION JOB SUITE FAILED"; exit 1; }

echo "=== [143/156] SLO report suite ==="
run_step slo_out slo_rc ./tests/test_slo_report.sh
[ "$slo_rc" -eq 0 ] || { echo "SLO REPORT (rc=$slo_rc)"; echo "$slo_out" | tail -5; exit 1; }
slo_pass=$(echo "$slo_out" | count_matches '\\[0;32mPASS')
slo_fail=$(echo "$slo_out" | count_matches '\\[0;31mFAIL')
echo "slo-report: $slo_pass passed, $slo_fail failed"
echo "slo_report $slo_pass" >> "$BASELINE_RUN"
[ "$slo_fail" -eq 0 ] || { echo "SLO REPORT SUITE FAILED"; exit 1; }

echo "=== [144/156] Pipeline alert suite ==="
run_step pal_out pal_rc ./tests/test_pipeline_alert.sh
[ "$pal_rc" -eq 0 ] || { echo "PIPELINE ALERT (rc=$pal_rc)"; echo "$pal_out" | tail -5; exit 1; }
pal_pass=$(echo "$pal_out" | count_matches '\\[0;32mPASS')
pal_fail=$(echo "$pal_out" | count_matches '\\[0;31mFAIL')
echo "pipeline-alert: $pal_pass passed, $pal_fail failed"
echo "pipeline_alert $pal_pass" >> "$BASELINE_RUN"
[ "$pal_fail" -eq 0 ] || { echo "PIPELINE ALERT SUITE FAILED"; exit 1; }

echo "=== [145/156] Incident suite ==="
run_step inc_out inc_rc ./tests/test_incident.sh
[ "$inc_rc" -eq 0 ] || { echo "INCIDENT (rc=$inc_rc)"; echo "$inc_out" | tail -5; exit 1; }
inc_pass=$(echo "$inc_out" | count_matches '\\[0;32mPASS')
inc_fail=$(echo "$inc_out" | count_matches '\\[0;31mFAIL')
echo "incident: $inc_pass passed, $inc_fail failed"
echo "incident $inc_pass" >> "$BASELINE_RUN"
[ "$inc_fail" -eq 0 ] || { echo "INCIDENT SUITE FAILED"; exit 1; }

echo "=== [146/156] Change control suite ==="
run_step chg_out chg_rc ./tests/test_change_control.sh
[ "$chg_rc" -eq 0 ] || { echo "CHANGE CONTROL (rc=$chg_rc)"; echo "$chg_out" | tail -5; exit 1; }
chg_pass=$(echo "$chg_out" | count_matches '\\[0;32mPASS')
chg_fail=$(echo "$chg_out" | count_matches '\\[0;31mFAIL')
echo "change-control: $chg_pass passed, $chg_fail failed"
echo "change_control $chg_pass" >> "$BASELINE_RUN"
[ "$chg_fail" -eq 0 ] || { echo "CHANGE CONTROL SUITE FAILED"; exit 1; }

echo "=== [147/156] Backup restore core suite ==="
run_step bkp_out bkp_rc ./tests/test_backup_restore_core.sh
[ "$bkp_rc" -eq 0 ] || { echo "BACKUP RESTORE CORE (rc=$bkp_rc)"; echo "$bkp_out" | tail -5; exit 1; }
bkp_pass=$(echo "$bkp_out" | count_matches '\\[0;32mPASS')
bkp_fail=$(echo "$bkp_out" | count_matches '\\[0;31mFAIL')
echo "backup-restore-core: $bkp_pass passed, $bkp_fail failed"
echo "backup_restore_core $bkp_pass" >> "$BASELINE_RUN"
[ "$bkp_fail" -eq 0 ] || { echo "BACKUP RESTORE CORE SUITE FAILED"; exit 1; }

echo "=== [148/156] Secret rotation core suite ==="
run_step scr_out scr_rc ./tests/test_secret_rotation.sh
[ "$scr_rc" -eq 0 ] || { echo "SECRET ROTATION CORE (rc=$scr_rc)"; echo "$scr_out" | tail -5; exit 1; }
scr_pass=$(echo "$scr_out" | count_matches '\\[0;32mPASS')
scr_fail=$(echo "$scr_out" | count_matches '\\[0;31mFAIL')
echo "secret-rotation-core: $scr_pass passed, $scr_fail failed"
echo "secret_rotation_core $scr_pass" >> "$BASELINE_RUN"
[ "$scr_fail" -eq 0 ] || { echo "SECRET ROTATION CORE SUITE FAILED"; exit 1; }

echo "=== [149/156] Disaster recovery core suite ==="
run_step dr_out dr_rc ./tests/test_disaster_recovery.sh
[ "$dr_rc" -eq 0 ] || { echo "DISASTER RECOVERY CORE (rc=$dr_rc)"; echo "$dr_out" | tail -5; exit 1; }
dr_pass=$(echo "$dr_out" | count_matches '\\[0;32mPASS')
dr_fail=$(echo "$dr_out" | count_matches '\\[0;31mFAIL')
echo "disaster-recovery-core: $dr_pass passed, $dr_fail failed"
echo "disaster_recovery_core $dr_pass" >> "$BASELINE_RUN"
[ "$dr_fail" -eq 0 ] || { echo "DISASTER RECOVERY CORE SUITE FAILED"; exit 1; }

echo "=== [150/156] Capacity plan core suite ==="
run_step cap_out cap_rc ./tests/test_capacity_plan.sh
[ "$cap_rc" -eq 0 ] || { echo "CAPACITY PLAN CORE (rc=$cap_rc)"; echo "$cap_out" | tail -5; exit 1; }
cap_pass=$(echo "$cap_out" | count_matches '\\[0;32mPASS')
cap_fail=$(echo "$cap_out" | count_matches '\\[0;31mFAIL')
echo "capacity-plan-core: $cap_pass passed, $cap_fail failed"
echo "capacity_plan_core $cap_pass" >> "$BASELINE_RUN"
[ "$cap_fail" -eq 0 ] || { echo "CAPACITY PLAN CORE SUITE FAILED"; exit 1; }

echo "=== [151/156] Audit retention core suite ==="
run_step are_out are_rc ./tests/test_audit_retention.sh
[ "$are_rc" -eq 0 ] || { echo "AUDIT RETENTION CORE (rc=$are_rc)"; echo "$are_out" | tail -5; exit 1; }
are_pass=$(echo "$are_out" | count_matches '\\[0;32mPASS')
are_fail=$(echo "$are_out" | count_matches '\\[0;31mFAIL')
echo "audit-retention-core: $are_pass passed, $are_fail failed"
echo "audit_retention_core $are_pass" >> "$BASELINE_RUN"
[ "$are_fail" -eq 0 ] || { echo "AUDIT RETENTION CORE SUITE FAILED"; exit 1; }

echo "=== [152/156] Compliance audit core suite ==="
run_step ca_out ca_rc ./tests/test_compliance_audit.sh
[ "$ca_rc" -eq 0 ] || { echo "COMPLIANCE AUDIT CORE (rc=$ca_rc)"; echo "$ca_out" | tail -5; exit 1; }
ca_pass=$(echo "$ca_out" | count_matches '\\[0;32mPASS')
ca_fail=$(echo "$ca_out" | count_matches '\\[0;31mFAIL')
echo "compliance-audit-core: $ca_pass passed, $ca_fail failed"
echo "compliance_audit_core $ca_pass" >> "$BASELINE_RUN"
[ "$ca_fail" -eq 0 ] || { echo "COMPLIANCE AUDIT CORE SUITE FAILED"; exit 1; }

echo "=== [153/156] Vendor compliance core suite ==="
run_step vcc_out vcc_rc ./tests/test_vendor_compliance.sh
[ "$vcc_rc" -eq 0 ] || { echo "VENDOR COMPLIANCE CORE (rc=$vcc_rc)"; echo "$vcc_out" | tail -5; exit 1; }
vcc_pass=$(echo "$vcc_out" | count_matches '\\[0;32mPASS')
vcc_fail=$(echo "$vcc_out" | count_matches '\\[0;31mFAIL')
echo "vendor-compliance-core: $vcc_pass passed, $vcc_fail failed"
echo "vendor_compliance_core $vcc_pass" >> "$BASELINE_RUN"
[ "$vcc_fail" -eq 0 ] || { echo "VENDOR COMPLIANCE CORE SUITE FAILED"; exit 1; }

echo "=== [154/156] Data quality core suite ==="
run_step dqc_out dqc_rc ./tests/test_data_quality.sh
[ "$dqc_rc" -eq 0 ] || { echo "DATA QUALITY CORE (rc=$dqc_rc)"; echo "$dqc_out" | tail -5; exit 1; }
dqc_pass=$(echo "$dqc_out" | count_matches '\\[0;32mPASS')
dqc_fail=$(echo "$dqc_out" | count_matches '\\[0;31mFAIL')
echo "data-quality-core: $dqc_pass passed, $dqc_fail failed"
echo "data_quality_core $dqc_pass" >> "$BASELINE_RUN"
[ "$dqc_fail" -eq 0 ] || { echo "DATA QUALITY CORE SUITE FAILED"; exit 1; }

echo "=== [155/159] Database constraints suite ==="
run_step dbc_out dbc_rc ./tests/test_db_constraints.sh
[ "$dbc_rc" -eq 0 ] || { echo "DB CONSTRAINTS (rc=$dbc_rc)"; echo "$dbc_out" | tail -5; exit 1; }
dbc_pass=$(echo "$dbc_out" | count_matches '\\[0;32mPASS')
dbc_fail=$(echo "$dbc_out" | count_matches '\\[0;31mFAIL')
echo "db-constraints: $dbc_pass passed, $dbc_fail failed"
echo "db-constraints $dbc_pass" >> "$BASELINE_RUN"
[ "$dbc_fail" -eq 0 ] || { echo "DB CONSTRAINTS SUITE FAILED"; exit 1; }

echo "=== [156/159] Load smoke suite ==="
run_step load_out load_rc ./tests/test_load_smoke.sh
[ "$load_rc" -eq 0 ] || { echo "LOAD SMOKE (rc=$load_rc)"; echo "$load_out" | tail -5; exit 1; }
load_pass=$(echo "$load_out" | count_matches '\\[0;32mPASS')
load_fail=$(echo "$load_out" | count_matches '\\[0;31mFAIL')
echo "load-smoke: $load_pass passed, $load_fail failed"
echo "load-smoke $load_pass" >> "$BASELINE_RUN"
[ "$load_fail" -eq 0 ] || { echo "LOAD SMOKE SUITE FAILED"; exit 1; }

echo "=== [157/159] Unit helpers suite ==="
run_step uh_out uh_rc ./tests/test_unit_helpers.sh
[ "$uh_rc" -eq 0 ] || { echo "UNIT HELPERS (rc=$uh_rc)"; echo "$uh_out" | tail -5; exit 1; }
uh_pass=$(echo "$uh_out" | count_matches '\\[0;32mPASS')
uh_fail=$(echo "$uh_out" | count_matches '\\[0;31mFAIL')
echo "unit-helpers: $uh_pass passed, $uh_fail failed"
echo "unit-helpers $uh_pass" >> "$BASELINE_RUN"
[ "$uh_fail" -eq 0 ] || { echo "UNIT HELPERS SUITE FAILED"; exit 1; }

echo "=== [158/159] Progress check ==="
./tests/progress_check.sh

echo "=== [159/159] Assertion-count baseline ==="
./tests/baseline_check.sh "$BASELINE_RUN"

echo "=== ALL GREEN ==="
