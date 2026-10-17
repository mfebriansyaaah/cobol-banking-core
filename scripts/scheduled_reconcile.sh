#!/bin/bash
# Scheduled reconciliation runner: records one SCHEDULED reconciliation run
# (immutable result plus OPEN findings for every mismatch).
#
# Install in the operator's cron; the operator provisions RECON_ACTOR (the
# email of a SUPER_ADMIN service identity) and the usual DB_* env knobs.
# The run itself, the exception workflow, and exports are covered by
# tests/test_reconciliation_runs.sh; scheduling policy lives with ops.
#
# Usage: RECON_ACTOR=reconciler@example.com scripts/scheduled_reconcile.sh
#   cron example: 0 2 * * * RECON_ACTOR=reconciler@example.com /opt/cobol-banking-core/scripts/scheduled_reconcile.sh >> /var/log/reconcile.log 2>&1

set -e
cd "$(dirname "$0")/.."

[ -n "$RECON_ACTOR" ] || { echo "RECON_ACTOR is required (a SUPER_ADMIN service identity)"; exit 1; }

BIN="$PWD/cobol/bin/main_logic"
[ -x "$BIN" ] || { echo "build the core first (./build.sh)"; exit 1; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

printf "RUN_RECONCILIATION|%s|SCHEDULED\n" "$RECON_ACTOR" > "$WORK/input.txt"
(cd "$WORK" && "$BIN" >/dev/null 2>&1)
out="$(cat "$WORK/output.txt")"
echo "$out"
case "$out" in
    SUCCESS\|RUN_RECORDED\|*)
        mism="$(echo "$out" | cut -d'|' -f4)"
        case "$mism" in
            ''|*[!0-9]*)
                echo "scheduled reconciliation returned an unreadable count" >&2
                exit 1
                ;;
        esac
        if [ "$mism" != "0" ]; then
            run_id="$(echo "$out" | cut -d'|' -f3)"
            echo "ALERT|DIVERGENCE|run=$run_id mismatches=$mism recorded by reconciliation; triage per docs/runbooks/alert-response.md" >&2
            exit 2
        fi
        exit 0
        ;;
    *) echo "scheduled reconciliation failed" >&2; exit 1 ;;
esac
