#!/usr/bin/env bash
# Provider fallback harness (PR-088): real adapters against a local fake with
# chaos modes (500, 400, timeout, malformed, down). No real network: every
# endpoint must be 127.0.0.1 (asserted first). No DB needed.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

T_PASS=0; T_FAIL=0; T_TOTAL=0
# shellcheck disable=SC1091
. "$ROOT/tests/lib/assert.sh"

node --check "$ROOT/tests/lib/fake_provider.mjs" 2>/dev/null || {
    echo "not ok 1 - fake provider parses"; echo "1..1"; echo "# pass=0 fail=1 total=1"; exit 1;
}

node "$ROOT/tests/lib/fake_provider.mjs" --port 0 > /tmp/fake088.url &
FAKE_PID=$!
trap 'kill $FAKE_PID 2>/dev/null; rm -f /tmp/fake088.url' EXIT
for _ in $(seq 1 50); do
    [ -s /tmp/fake088.url ] && break
    sleep 0.1
done
FAKE="$(cat /tmp/fake088.url 2>/dev/null)"
assert_match "fake serves localhost" "$FAKE" "^http://127\.0\.0\.1:[0-9]+$"

export TELEGRAM_API_BASE="${FAKE}/telegram" TELEGRAM_BOT_TOKEN="fake-token" TELEGRAM_TIMEOUT_MS="1000"
export FREE_SMS_ENDPOINT="${FAKE}/sms/send" FREE_SMS_API_KEY="fake-key" FREE_SMS_TIMEOUT_MS="1000"
export NUSAKIT_ENDPOINT="${FAKE}/nik/verify" NUSAKIT_ALLOWLIST="127.0.0.1"
assert_match "no real provider host in env" "${TELEGRAM_API_BASE} ${FREE_SMS_ENDPOINT} ${NUSAKIT_ENDPOINT}" "127\.0\.0\.1"

echo "=== Provider fallback harness ($FAKE) ==="
run_scenario() {
    node "$ROOT/tests/lib/provider_chaos_driver.mjs" "$1" "$FAKE" 2>&1 | tail -1
}

assert_match "telegram ok (1 call, idempotent)" "$(run_scenario tg-ok)" "SCENARIO=tg-ok ok=true calls=1 idem=1"
assert_match "telegram 500 falls back to sms (budgeted, not spam)" "$(run_scenario tg-fallback)" "SCENARIO=tg-fallback ok=true tg_calls=3 sms_calls=1"
assert_match "sms 400 terminal (single call)" "$(run_scenario sms-400)" "SCENARIO=sms-400 err=1 calls=1"
assert_match "nusakit timeout falls back to local" "$(run_scenario nik-timeout)" "SCENARIO=nik-timeout valid=1 fallback=1"
assert_match "nusakit malformed falls back to local" "$(run_scenario nik-malformed)" "SCENARIO=nik-malformed valid=1 fallback=1"

kill "$FAKE_PID" 2>/dev/null
wait "$FAKE_PID" 2>/dev/null
trap - EXIT
assert_match "nusakit down falls back to local (user never hangs)" "$(run_scenario nik-down)" "SCENARIO=nik-down valid=1 fallback=1"

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
