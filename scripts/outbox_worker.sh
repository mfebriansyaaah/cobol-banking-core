#!/bin/bash
# Notification outbox worker: claim due rows, deliver, mark outcomes.
# Run on a schedule (cron/systemd); every invocation is a bounded batch.
# See middleware/outbox_worker.js for transports and redaction rules.
# Usage: OUTBOX_TRANSPORT=smtp ./scripts/outbox_worker.sh [--once] [--limit N]
#   cron: * * * * * OUTBOX_TRANSPORT=smtp /opt/cobol-banking-core/scripts/outbox_worker.sh --once --limit 100

set -e
cd "$(dirname "$0")/.."

if [ -f ./tests/.dbenv ]; then . ./tests/.dbenv; fi

: "${OUTBOX_TRANSPORT:=smtp}"
export OUTBOX_TRANSPORT

exec node middleware/outbox_worker.js "$@"
