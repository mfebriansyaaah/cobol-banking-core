#!/usr/bin/env bash
# Release verification (PR-073): pre-deploy gates and post-deploy probes.
# Usage: scripts/release_check.sh [--post-deploy] [BASE_URL]
# Pre-deploy runs repo gates (needs DB + build); post-deploy hits a live
# gateway read-only (default http://127.0.0.1:3000).
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MODE="${1:-pre-deploy}"
BASE="${2:-http://127.0.0.1:3000}"

if [ "$MODE" = "--post-deploy" ] || [ "$MODE" = "post-deploy" ]; then
    fail=0
    probe() {
        local name="$1" url="$2" want="$3"
        code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$url" || echo 000)"
        if [ "$code" = "$want" ]; then echo "ok - $name ($code)";
        else echo "not ok - $name (want $want, got $code)"; fail=1; fi
    }
    probe "readiness" "$BASE/ready" "200"
    probe "liveness" "$BASE/live" "200"
    probe "health" "$BASE/health" "200"
    probe "metrics-guarded" "$BASE/metrics" "401"
    [ "$fail" -eq 0 ]
    exit "$fail"
fi

# Pre-deploy: static gates + docs + lint (DB suites run in CI separately).
node "$ROOT/scripts/check_docs.mjs" "$ROOT" | tail -1
for g in check_manifest check_route_dispatch check_route_conflicts check_route_auth check_action_registry check_dispatch_table check_route_barrel check_openapi check_tier1_links; do
    node "$ROOT/scripts/$g.mjs" "$ROOT" | tail -1 || exit 1
done
echo "release pre-deploy checks passed"
