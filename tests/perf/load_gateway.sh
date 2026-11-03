#!/usr/bin/env bash
# Gateway load test (P1-8): serve the real gateway on a random localhost port
# and hammer the deep-health endpoint (a COBOL/DB round-trip per request)
# with autocannon. Fails on any non-2xx or when p99 exceeds LOAD_P99_MS.
# Rate limits are lifted for the run (the limiter itself is covered by
# ratelimit.test.js); thresholds are generous defaults, override per hardware:
#   LOAD_DURATION=10 LOAD_CONNECTIONS=50 LOAD_P99_MS=500 bash tests/perf/load_gateway.sh
# Requires a migrated + seeded database (see tests/.dbenv.example) and a
# built binary (./build.sh). Cleans up the server; /health writes nothing.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT" || exit 1

DURATION="${LOAD_DURATION:-10}"
CONNECTIONS="${LOAD_CONNECTIONS:-50}"
# Budget itself lives in the node check below (default 2000ms); override per
# hardware with LOAD_P99_MS.

command -v node >/dev/null 2>&1 || { echo "FAIL: node not found" >&2; exit 2; }
[ -x "$ROOT/node_modules/.bin/autocannon" ] || { echo "FAIL: run npm ci first (autocannon is a root devDependency)" >&2; exit 2; }
[ -x "$ROOT/cobol/bin/main_logic" ] || { echo "FAIL: no built binary (run ./build.sh first)" >&2; exit 2; }

# Random free port: bind probe via node (portable, no extra tools).
PORT="$(node -e 'const s=require("node:net").createServer();s.listen(0,"127.0.0.1",()=>{console.log(s.address().port);s.close()})')"
if [ -z "$PORT" ]; then echo "FAIL: cannot pick a free port" >&2; exit 2; fi

SERVER_LOG="$(mktemp "${TMPDIR:-/tmp}/gateway-load.XXXXXX.log")"
cleanup() {
    if [ -n "${SERVER_PID:-}" ] && kill -0 "$SERVER_PID" 2>/dev/null; then
        kill "$SERVER_PID" 2>/dev/null || true
        wait "$SERVER_PID" 2>/dev/null || true
    fi
    rm -f "$SERVER_LOG"
}
trap cleanup EXIT

echo "=== GATEWAY LOAD: :$PORT for ${DURATION}s x ${CONNECTIONS} conns ==="
DB_HOST="${DB_HOST:-localhost}" DB_PORT="${DB_PORT:-3306}" \
    DB_USER="${DB_USER:-cobol_user}" DB_PASS="${DB_PASS:-cobol_pass}" \
    DB_NAME="${DB_NAME:-cobol_db}" \
    PORT="$PORT" PBKDF2_ITERATIONS=1000 \
    RATE_LIMIT_MAX=1000000 RATE_LIMIT_WINDOW_MS=60000 \
    API_RATE_LIMIT_MAX=1000000 API_RATE_LIMIT_WINDOW_MS=60000 \
    COBOL_POOL_SIZE=2 COBOL_POOL_PIPELINE=4 \
    node middleware/src/server.js >"$SERVER_LOG" 2>&1 &
SERVER_PID=$!

ready=0
for _ in $(seq 1 60); do
    if node -e "fetch('http://127.0.0.1:$PORT/live').then((r)=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))" 2>/dev/null; then
        ready=1
        break
    fi
    sleep 0.5
done
if [ "$ready" != "1" ]; then
    echo "FAIL: gateway did not become ready on :$PORT" >&2
    tail -20 "$SERVER_LOG" >&2 || true
    exit 1
fi

RESULT="$(mktemp "${TMPDIR:-/tmp}/gateway-load-res.XXXXXX.json")"
trap 'cleanup; rm -f "$RESULT"' EXIT
"$ROOT/node_modules/.bin/autocannon" -c "$CONNECTIONS" -d "$DURATION" --json "http://127.0.0.1:$PORT/health" > "$RESULT" 2>/dev/null || {
    echo "FAIL: autocannon did not complete" >&2
    exit 1
}

# Single quotes are intentional: the $ interpolations below belong to node,
# evaluated from autocannon's JSON, not the shell (SC2016 does not apply).
# shellcheck disable=SC2016
node -e '
const r = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
const non2xx = r.non2xx || 0;
const p99 = r.latency ? r.latency.p99 : NaN;
console.log(`requests=${r.requests.total} errors=${r.errors} timeouts=${r.timeouts} non2xx=${non2xx} p99=${p99}ms`);
if (r.errors || r.timeouts || non2xx) { console.error("FAIL load test: transport errors or non-2xx responses"); process.exit(1); }
const budget = Number(process.env.LOAD_P99_MS || 500);
if (!(p99 <= budget)) { console.error(`FAIL load test: p99 ${p99}ms exceeds budget ${budget}ms`); process.exit(1); }
console.log(`OK: p99 ${p99}ms within ${budget}ms, zero errors`);
' "$RESULT"
