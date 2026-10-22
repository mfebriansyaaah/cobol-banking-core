#!/bin/bash
# COBOL line-coverage measurement.
#
# GnuCOBOL compiles COBOL to C, so coverage is collected on the generated C
# with gcc --coverage and then mapped back to the COBOL source lines: every
# generated statement carries a `/* Line: N : ... : <file>.cob */` marker.
#
# The suites invoke ./cobol/bin/main_logic directly, so the coverage build is
# swapped in for the duration of the run and the normal binary restored on
# exit. Coverage is a floor, not a correctness claim: a covered line can still
# be wrong, and a `-` C line is not an executable COBOL statement.
#
# Usage:
#   scripts/coverage_cobol.sh                 # default representative subset
#   scripts/coverage_cobol.sh --all           # every functional shell suite
#   scripts/coverage_cobol.sh --suite test_suite --suite test_auth_login
#   scripts/coverage_cobol.sh --min 30        # fail below 30% (default 30)
#   scripts/coverage_cobol.sh --json          # machine-readable totals
#   scripts/coverage_cobol.sh --keep          # keep the work directory
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$(pwd)"

BIN="./cobol/bin/main_logic"
WORK="$(mktemp -d)"
KEEP=0
MIN=30
JSON=0
SUITES=()
MODE=default

while [ $# -gt 0 ]; do
    case "$1" in
        --all) MODE=all ;;
        --suite) MODE=explicit; SUITES+=("$2"); shift ;;
        --min) MIN="$2"; shift ;;
        --json) JSON=1 ;;
        --keep) KEEP=1 ;;
        *) echo "usage: $0 [--all|--suite NAME]... [--min N] [--json] [--keep]" >&2; exit 2 ;;
    esac
    shift
done

# Functional suites that exercise the binary and do not rebuild the database.
DEFAULT_SUITES=(
    test_suite
    test_auth_login
    test_signup_verify
    test_user_profile
    test_transfer_validity
    test_transfer_reversal
    test_session
    test_session_security
    test_holds
    test_permissions
    test_password_policy
    test_step_up_policy
    test_dormancy
    test_ref_engine
    test_gl
    test_batch
    test_report
    test_import
    test_fee
    test_eod
    test_statement
    test_eod_jobs
    test_ref_ext
    test_notification
    test_payment
    test_recon
    test_import_post
    test_report_delivery
    test_dispute_ops
    test_export_archive
    test_recon_ops
    test_alert_center
    test_payment_enforcement
    test_dashboard
    test_statement_recon
    test_schedule_history
    test_payment_instruction
    test_oncall
    test_audit_analytics
    test_import_recon
    test_recon_exception
    test_dispute_notify
    test_export_stream
    test_alert_escalation
    test_audit_drilldown
    test_compliance_export
    test_payment_hold
    test_oncall_delivery
    test_compliance_retention
    test_report_scheduler
    test_settlement_recon
    test_statement_delivery
    test_audit_snapshot
    test_report_archive
    test_kyc_review
    test_regulatory_report
    test_loan
    test_deposit
    test_fx_deal
    test_treasury_position
    test_card
    test_tax_report
)
ALL_SUITES=(
    test_suite test_atomic_txn test_ledger_atomic test_reconciliation
    test_auth_login test_signup_verify test_roles test_user_profile
    test_account_lifecycle test_login_lockout test_idempotent_transfer
    test_transfer_validity test_wallet_observability test_transfer_limits
    test_transfer_reversal test_account_status test_session
    test_sessions_manage test_token_rotation test_admin_hierarchy
    test_last_admin test_audit_actor test_audit_read test_audit_integrity
    test_admin_recovery test_stepup test_mfa_state test_mfa_recovery
    test_outbox test_statements test_disputes test_ledger_integrity
    test_concurrent_transfer test_serve_mode test_password test_verify_cap
    test_journal test_holds test_reconciliation_runs test_dual_control
    test_mfa test_password_kdf test_permissions test_session_security
    test_access_reviews
    test_ref_engine
    test_gl
    test_batch
    test_report
    test_import
    test_fee
    test_eod
    test_statement
    test_eod_jobs
    test_ref_ext
    test_notification
    test_payment
    test_recon
    test_import_post
    test_report_delivery
    test_dispute_ops
    test_export_archive
    test_recon_ops
    test_alert_center
    test_payment_enforcement
    test_dashboard
    test_statement_recon
    test_schedule_history
    test_payment_instruction
    test_oncall
    test_audit_analytics
    test_import_recon
    test_recon_exception
    test_dispute_notify
    test_export_stream
    test_alert_escalation
    test_audit_drilldown
    test_compliance_export
    test_payment_hold
    test_oncall_delivery
    test_compliance_retention
    test_report_scheduler
    test_settlement_recon
    test_statement_delivery
    test_audit_snapshot
    test_report_archive
    test_kyc_review
    test_regulatory_report
    test_loan
    test_deposit
    test_fx_deal
    test_treasury_position
    test_card
    test_tax_report
)
case "$MODE" in
    default) SUITES=("${DEFAULT_SUITES[@]}") ;;
    all) SUITES=("${ALL_SUITES[@]}") ;;
esac

MODULES=(main_logic user_core wallet_core auth_core ref_engine gl_core batch_core report_core report_delivery_core dispute_ops_core export_archive_core recon_ops_core alert_core dashboard_core statement_recon_core payment_instruction_core oncall_core audit_analytics_core import_recon_core recon_exception_core dispute_notify_core export_stream_core alert_escalation_core audit_drilldown_core compliance_export_core payment_hold_core oncall_delivery_core compliance_retention_core report_scheduler_core audit_snapshot_core report_archive_core kyc_review_core regulatory_report_core loan_core deposit_core fx_deal_core treasury_position_core settlement_recon_core statement_delivery_core card_core tax_report_core import_core import_post_core fee_core eod_core statement_core eod_jobs_core ref_ext_core notification_core payment_core recon_core)
COBOL_SRC="cobol/src"
C_SRC="cobol/src/sql_bridge.c cobol/c_lib/hash_lib.c cobol/c_lib/totp_lib.c cobol/c_lib/settings_lib.c cobol/c_lib/random_lib.c"

cleanup() {
    if [ -f "$WORK/main_logic.normal" ]; then
        mv -f "$WORK/main_logic.normal" "$BIN"
    fi
    if [ "$KEEP" -eq 0 ]; then
        rm -rf "$WORK"
    else
        echo "work directory kept: $WORK" >&2
    fi
}
trap cleanup EXIT

echo "== building the coverage binary ==" >&2
COB_SOURCES=()
for m in "${MODULES[@]}"; do COB_SOURCES+=("$ROOT/$COBOL_SRC/$m.cob"); done
C_SOURCES=()
for c in $C_SRC; do C_SOURCES+=("$ROOT/$c"); done
# Build inside WORK so the .gcno/.gcda files stay together there.
( cd "$WORK" && cobc -free -x --coverage -o main_cov "${COB_SOURCES[@]}" "${C_SOURCES[@]}" -lmysqlclient >build.log 2>&1 ) \
    || { echo "coverage build failed:" >&2; tail -5 "$WORK/build.log" >&2; exit 1; }

echo "== generating the C sources for the line map ==" >&2
for m in "${MODULES[@]}"; do
    ( cd "$WORK" && cobc -free -C "$ROOT/$COBOL_SRC/$m.cob" >/dev/null 2>&1 )
done

# Swap the instrumented binary in, run the suites, restore it on exit.
cp "$BIN" "$WORK/main_logic.normal"
cp "$WORK/main_cov" "$BIN"
chmod +x "$BIN"

echo "== running ${#SUITES[@]} suites under coverage ==" >&2
FAILED=0
for s in "${SUITES[@]}"; do
    if [ ! -x "./tests/$s.sh" ]; then
        echo "suite not present on this branch, skipped: $s" >&2
        continue
    fi
    if ! "./tests/$s.sh" >"$WORK/$s.out" 2>&1; then
        echo "suite failed: $s (see $WORK/$s.out)" >&2
        FAILED=1
    fi
done

# Compute the COBOL line map from the generated C and the gcov counts.
python3 - "$WORK" "${MODULES[@]}" "$JSON" "$MIN" "$FAILED" <<'PY'
import os, re, sys, json, subprocess

work = sys.argv[1]
modules = sys.argv[2:-3]
as_json = sys.argv[-3] == '1'
minimum = float(sys.argv[-2])
failed = sys.argv[-1] == '1'

MARKER = re.compile(r'/\* Line:\s*(\d+)\s*:')
COUNT = re.compile(r'^\s*([0-9]+|#####|=====|-):\s*(\d+):')

def recorded_source(gcno):
    out = subprocess.run(['strings', gcno], capture_output=True, text=True).stdout
    for line in out.splitlines():
        if line.startswith('/tmp/') and line.endswith('.c'):
            return line
    return None

def load_counts(path):
    counts = {}
    with open(path, errors='replace') as f:
        for line in f:
            m = COUNT.match(line)
            if not m:
                continue
            tag, lineno = m.group(1), int(m.group(2))
            if tag == '-':
                continue
            counts[lineno] = 0 if tag in ('#####', '=====') else int(tag)
    return counts

total_exec = total_hit = 0
rows = []
for module in modules:
    csrc = os.path.join(work, module + '.c')
    gcno = os.path.join(work, module + '.gcno')
    if not (os.path.exists(csrc) and os.path.exists(gcno)):
        continue
    src_path = recorded_source(gcno)
    if not src_path:
        continue
    # The compiler's temporary C is gone; put our equivalent translation there
    # so gcov can show the source and map the counts.
    subprocess.run(['cp', csrc, src_path], check=False)
    # gcov names its report after the source basename and writes it in the
    # directory it runs from.
    gcov_file = os.path.join(work, os.path.basename(src_path) + '.gcov')
    if os.path.exists(gcov_file):
        os.remove(gcov_file)
    subprocess.run(['gcov', module + '.gcno'], cwd=work,
                   capture_output=True, text=True)
    if not os.path.exists(gcov_file):
        continue
    counts = load_counts(gcov_file)

    # Every C line between a marker and the next marker belongs to that COBOL
    # statement; a statement is covered when any of its C lines ran.
    with open(csrc, errors='replace') as f:
        lines = f.readlines()
    current = None
    exec_lines = set()
    hit_lines = set()
    for i, line in enumerate(lines, start=1):
        m = MARKER.search(line)
        if m:
            current = int(m.group(1))
            continue
        if current is None or i not in counts:
            continue
        exec_lines.add(current)
        if counts[i] > 0:
            hit_lines.add(current)
    exec_n = len(exec_lines)
    hit_n = len(hit_lines)
    pct = (100.0 * hit_n / exec_n) if exec_n else 0.0
    total_exec += exec_n
    total_hit += hit_n
    rows.append({'module': module, 'executable': exec_n, 'covered': hit_n, 'percent': round(pct, 2)})

overall = (100.0 * total_hit / total_exec) if total_exec else 0.0
result = {
    'modules': rows,
    'executable': total_exec,
    'covered': total_hit,
    'percent': round(overall, 2),
    'minimum': minimum,
    'ok': (not failed) and overall >= minimum,
}
if as_json:
    print(json.dumps(result))
else:
    print('COBOL line coverage (mapped from the generated C):')
    for r in rows:
        print(f"  {r['module']:<12} {r['covered']:>6}/{r['executable']:<6} {r['percent']:>6.2f}%")
    print(f"  {'total':<12} {total_hit:>6}/{total_exec:<6} {overall:>6.2f}%  (minimum {minimum:.0f}%)")
sys.exit(0 if result['ok'] else 1)
PY
