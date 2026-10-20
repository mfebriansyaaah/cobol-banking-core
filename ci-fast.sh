#!/bin/bash
# Fast pull-request gate.
#
# The full ./ci.sh (71 steps, ~5 minutes) remains the release gate. This gate
# runs the checks that can catch a mistake in the surface the change actually
# touches, in well under two minutes:
#
#   always            docs integrity, static checks, build, warning ratchet,
#                     migration check, assertion counts for what it runs
#   docs-only         stops after the docs/status/traceability/env checks
#   cobol/db/tests    the money-path and identity smoke suites
#   middleware        the full gateway suite (its own 126 assertions)
#
# Selection uses the merge base against origin/main; with no base (fresh or
# shallow clone) it runs every fast tier, which is still much cheaper than the
# full run. See docs/adr/0076-tiered-ci.md.
#
# Usage: ./ci-fast.sh [--dry-run]
set -e
cd "$(dirname "$0")"

MODE=run
case "${1:-}" in
    ''|--run) MODE=run ;;
    --dry-run) MODE=dry ;;
    *) echo "usage: $0 [--dry-run]" >&2; exit 2 ;;
esac

BASELINE_RUN="$(mktemp)"
trap 'rm -f "$BASELINE_RUN"' EXIT
count_matches() { awk -v re="$1" '$0 ~ re {n++} END {print n+0}'; }

BASE="$(git merge-base HEAD origin/main 2>/dev/null || true)"
CHANGED=""
if [ -n "$BASE" ]; then
    CHANGED="$(git diff --name-only "$BASE"...HEAD)"
fi

docs_only=1
touch_cobol=0
touch_mw=0
if [ -z "$CHANGED" ]; then
    docs_only=0
    touch_cobol=1
    touch_mw=1
else
    while IFS= read -r f; do
        [ -n "$f" ] || continue
        case "$f" in
            *.md|docs/*) ;;
            *) docs_only=0 ;;
        esac
        case "$f" in
            cobol/*|database/*|tests/*|scripts/*|ci.sh|ci-fast.sh) touch_cobol=1 ;;
            middleware/*) touch_mw=1 ;;
        esac
    done <<< "$CHANGED"
fi

plan() { echo "  $*"; }
if [ "$MODE" = dry ]; then
    echo "fast gate plan (changed: ${CHANGED:-unknown})"
    plan "docs_check"
    if [ "$docs_only" -eq 1 ]; then
        plan "status_check, traceability_check, env_check  (docs-only change)"
    else
        plan "static_checks, build, warning_check, migrate --check"
        [ "$touch_cobol" -eq 1 ] && plan "core smoke suites"
        [ "$touch_mw" -eq 1 ] && plan "gateway suite"
        plan "baseline subset check"
    fi
    exit 0
fi

./tests/docs_check.sh

if [ "$docs_only" -eq 1 ]; then
    ./tests/status_check.sh
    ./tests/traceability_check.sh
    ./tests/env_check.sh
    echo "=== FAST GATE OK (docs-only) ==="
    exit 0
fi

./tests/static_checks.sh
build_log="$(./build.sh 2>&1)" || { echo "FAST GATE: build failed"; echo "$build_log" | tail -20; exit 1; }
bw_log="$(mktemp)"
printf '%s\n' "$build_log" > "$bw_log"
./tests/warning_check.sh "$bw_log"
rm -f "$bw_log"
./database/migrate.sh --check

if [ "$touch_cobol" -eq 1 ]; then
    # manifest-key:suite-file pairs (baseline_check uses the manifest keys)
    CORE_SUITES="functional:test_suite auth-login:test_auth_login roles:test_roles
        transfer-validity:test_transfer_validity reversal:test_transfer_reversal
        holds:test_holds permissions:test_permissions access-reviews:test_access_reviews
        session-security:test_session_security disputes:test_disputes
        journal:test_journal recon-runs:test_reconciliation_runs"
    for pair in $CORE_SUITES; do
        key="${pair%%:*}"
        suite="${pair##*:}"
        out="$("./tests/$suite.sh" 2>&1)" || { echo "FAST GATE: $suite failed"; echo "$out" | tail -20; exit 1; }
        # Suites differ in how they emit colour: strip both an ESC and a
        # literal \033 sequence, then take the final "N passed" summary.
        summary="$(echo "$out" | sed -E 's/\\033\[[0-9;]*m//g; s/\x1b\[[0-9;]*m//g' | grep -oE '[0-9]+ passed' | tail -1 | grep -oE '[0-9]+')"
        [ -n "$summary" ] || { echo "FAST GATE: $suite reported no count"; echo "$out" | tail -10; exit 1; }
        echo "$key $summary" >> "$BASELINE_RUN"
    done
fi

if [ "$touch_mw" -eq 1 ]; then
    npm --prefix middleware ci --silent >/dev/null 2>&1 || npm --prefix middleware install --silent >/dev/null 2>&1
    gw="$(npm --prefix middleware test --silent 2>&1)" || { echo "FAST GATE: gateway suite failed"; echo "$gw" | tail -20; exit 1; }
    skip=$(echo "$gw" | grep -E '^ℹ skipped' | grep -oE '[0-9]+' | head -1)
    [ "${skip:-0}" -eq 0 ] || { echo "FAST GATE: gateway suite has skipped tests"; exit 1; }
    total=$(echo "$gw" | grep -E '^ℹ pass' | grep -oE '[0-9]+' | awk '{s+=$1} END {print s+0}')
    echo "gateway $total" >> "$BASELINE_RUN"
fi

[ -s "$BASELINE_RUN" ] && ./tests/baseline_check.sh --subset "$BASELINE_RUN"
echo "=== FAST GATE OK ==="
