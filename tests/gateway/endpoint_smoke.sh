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
require_db
db_seed

echo "Running gateway endpoint suite (npm test)..."
npm --prefix middleware test >/tmp/gateway_endpoints.log 2>&1
rc=$?

# The old check only looked at the "fail" counter. When the suite crashed while
# loading a route module there was no summary line at all, so `fail` expanded
# to 0 and the run looked clean. Require a real summary with a non-zero pass
# count before trusting the numbers.
if ! grep -qE '^ℹ (pass|tests) ' /tmp/gateway_endpoints.log; then
    echo "FAIL: gateway suite produced no test summary (crash during load?)"
    tail -25 /tmp/gateway_endpoints.log
    exit 1
fi

pass=$(grep -E '^ℹ pass' /tmp/gateway_endpoints.log | awk '{print $3}')
fail=$(grep -E '^ℹ fail' /tmp/gateway_endpoints.log | awk '{print $3}')
tests=$(grep -E '^ℹ tests' /tmp/gateway_endpoints.log | awk '{print $3}')
echo "gateway: tests=${tests:-0} pass=${pass:-0} fail=${fail:-0}"
if [ "$rc" -ne 0 ] || [ "${fail:-0}" != "0" ] || [ "${pass:-0}" -lt 1 ]; then
    echo "FAIL: gateway endpoint check failed (rc=$rc, pass=${pass:-0}, fail=${fail:-0})"
    tail -25 /tmp/gateway_endpoints.log
    exit 1
fi
echo "OK: all gateway endpoints passed"
exit 0
