#!/bin/bash
# Nightly coverage gate: the measurement and ratchet that no longer run on
# every merge (ADR 0078). Schedule it with cron/systemd; a non-zero exit is
# the alert.
#
#   cron: 30 2 * * * cd /opt/cobol-banking-core && ./scripts/nightly.sh >> /var/log/cobol-coverage.log 2>&1
#
# It runs:
#   1. the COBOL statement-coverage measurement over the fixed subset
#      (scripts/coverage_cobol.sh, ~50s, instrumented build included),
#   2. the gateway suite with coverage over src/** (~70s),
#   3. tests/coverage_check.sh, which compares both to the 30% floor and the
#      ratchet in tests/coverage_baseline.txt.
#
# Usage: scripts/nightly.sh [output-dir]
set -euo pipefail
cd "$(dirname "$0")/.."

OUT_DIR="${1:-/tmp/opencode}"
mkdir -p "$OUT_DIR"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
LOG="$OUT_DIR/coverage-${STAMP}.log"

# The coverage check reuses a fresh gateway report when one is present. Run
# the gateway suite here so the report belongs to this invocation.
echo "nightly: running the coverage gate (log: $LOG)"
if ! ./tests/coverage_check.sh --gateway-report "$OUT_DIR/gateway-${STAMP}.out" >"$LOG" 2>&1; then
    echo "nightly: COVERAGE GATE FAILED (see $LOG)" >&2
    tail -20 "$LOG" >&2
    exit 1
fi
echo "nightly: coverage gate OK"
tail -8 "$LOG"

# The merge gate restores a representative table slice (~10 tables) so it stays
# fast; this is the full 454-table round-trip that proves completeness.
BR_LOG="$OUT_DIR/backup-restore-${STAMP}.log"
echo "nightly: running the full backup/restore round-trip (log: $BR_LOG)"
if env -u BACKUP_TABLES ./tests/test_backup_restore.sh >"$BR_LOG" 2>&1; then
    echo "nightly: full backup/restore OK"
else
    echo "nightly: FULL BACKUP/RESTORE FAILED (see $BR_LOG)" >&2
    tail -20 "$BR_LOG" >&2
    exit 1
fi
