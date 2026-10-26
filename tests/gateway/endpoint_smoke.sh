#!/bin/bash
# Gateway endpoint smoke: run the full middleware test suite (all endpoints).
# Returns 0 if every test passes, 1 otherwise.
# Usage: tests/gateway/endpoint_smoke.sh
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

if [ ! -d middleware ]; then
    echo "SKIP: middleware/ absent"
    exit 0
fi

# shellcheck disable=SC1091
. "$ROOT/tests/lib/db.sh"
if ! db_available; then
    echo "SKIP: DB unavailable"
    exit 0
fi
db_seed

echo "Running gateway endpoint suite (npm test)..."
npm --prefix middleware test >/tmp/gateway_endpoints.log 2>&1
rc=$?
pass=$(grep -E '^ℹ pass' /tmp/gateway_endpoints.log | awk '{print $3}')
fail=$(grep -E '^ℹ fail' /tmp/gateway_endpoints.log | awk '{print $3}')
echo "gateway: pass=${pass:-0} fail=${fail:-0}"
if [ "$rc" -ne 0 ] || [ "${fail:-0}" != "0" ]; then
    echo "FAIL: gateway endpoint check failed (rc=$rc)"
    tail -15 /tmp/gateway_endpoints.log
    exit 1
fi
echo "OK: all gateway endpoints passed"
exit 0
