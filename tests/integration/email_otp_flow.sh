#!/usr/bin/env bash
# Integration: signup -> outbox worker -> Mailpit -> verify email.
# Proves verification codes travel only via email, never in HTTP responses.
# Needs Mailpit (docker-compose.test.yml or CI service). Without it the flow
# SKIPs, unless REQUIRE_MAILPIT=1 (CI) which fails instead.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/tests/lib/db.sh"
require_db

T_PASS=0; T_FAIL=0; T_TOTAL=0
# shellcheck disable=SC1091
. "$ROOT/tests/lib/assert.sh"

MAILPIT="${MAILPIT_URL:-http://127.0.0.1:8025}"
if ! node -e "fetch('$MAILPIT/api/v1/messages').then((r)=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))" 2>/dev/null; then
    if [ "${REQUIRE_MAILPIT:-0}" = "1" ]; then
        echo "FAIL: Mailpit unreachable at $MAILPIT (REQUIRE_MAILPIT=1)" >&2
        exit 1
    fi
    echo "SKIP: Mailpit absent at $MAILPIT (set REQUIRE_MAILPIT=1 to enforce)"
    exit 0
fi

db_seed
U="mailflow@test.com"
# shellcheck disable=SC1091
. "$ROOT/tests/lib/cobol.sh"

db_exec "DELETE FROM notification_outbox WHERE recipient='${U}';"
db_exec "DELETE FROM users WHERE email='${U}';"

signup_out="$(run_cobol "REQUEST_SIGNUP|${U}|Passw0rd!|Mail Flow|1990-01-01")"
assert_match "signup ok" "$signup_out" "SUCCESS\|USER_CREATED"
# No-leak is an HTTP-layer property (the mapper strips the code the COBOL
# core returns for tests): prove the mapped body carries no code.
mapped="$(node --input-type=module -e "
import('./middleware/src/responseMappers.js').then(async ({ RESPONSE_MAPPERS }) => {
  const m = await RESPONSE_MAPPERS.REQUEST_SIGNUP();
  console.log(JSON.stringify(m));
});")"
assert_match "no code leaks in response" "$mapped" '"USER_CREATED"'
assert_match "mapped body exact (no room for a code)" "$mapped" '^\{"data":\["USER_CREATED"\]\}$'

echo "=== Email OTP flow ($U via $MAILPIT) ==="
export SMTP_HOST="${SMTP_HOST:-127.0.0.1}" SMTP_PORT="${SMTP_PORT:-1025}"
export EMAIL_PROVIDER=mailpit OUTBOX_TRANSPORT=mailpit
node "$ROOT/middleware/src/outbox_worker.js" --once --limit 10 >/tmp/mailflow_worker.log 2>&1
assert_match "worker delivered" "$(grep -c outbox_sent /tmp/mailflow_worker.log)" "^[1-9][0-9]*$"

code="$(node -e '
const base = process.argv[1], to = process.argv[2];
fetch(base + "/api/v1/messages").then((r) => r.json()).then(async (j) => {
  const msgs = (j.messages || []).filter((m) => (m.To || []).some((t) => t.Address === to));
  if (!msgs.length) { console.log(""); return; }
  const id = msgs[msgs.length - 1].ID;
  const m = await (await fetch(base + "/api/v1/message/" + id)).json();
  const body = (m.Text || "") + "\n" + (m.HTML || "");
  const found = body.match(/\b(\d{6})\b/);
  console.log(found ? found[1] : "");
}).catch(() => console.log(""));
' "$MAILPIT" "$U")"
assert_match "code recovered from email" "$code" "^[0-9]{6}$"
assert_match "verify ok" "$(run_cobol "VERIFY_EMAIL|${U}|${code}")" "SUCCESS\|EMAIL_VERIFIED"
assert_match "outbox marked sent" "$(db_query "SELECT state FROM notification_outbox WHERE recipient='${U}' ORDER BY id DESC LIMIT 1;")" "^SENT$"

db_exec "DELETE FROM notification_outbox WHERE recipient='${U}';"
db_exec "DELETE FROM users WHERE email='${U}';"
rm -f /tmp/mailflow_worker.log

print_summary
if [ "$T_FAIL" -ne 0 ]; then exit 1; fi
exit 0
