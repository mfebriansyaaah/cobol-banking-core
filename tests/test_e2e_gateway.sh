#!/bin/bash
# End-to-end HTTP smoke: start the real gateway and drive a full flow through
# the HTTP surface (signup -> verify -> login -> transfer -> refresh -> ...).
# Uses curl against a live server, complementing the per-suite tests.
# Usage: ./tests/test_e2e_gateway.sh
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"; cd "$ROOT"

if [ -f ./tests/.dbenv ]; then . ./tests/.dbenv; fi
DB_USER="${DB_USER:-cobol_user}"
DB_PASS="${DB_PASS:-cobol_pass}"
DB_NAME="${DB_NAME:-cobol_db}"

GREEN=$'\033[0;32m'; RED=$'\033[0;31m'; NC=$'\033[0m'
passed=0; failed=0

q() { mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -N -B -e "$1" 2>/dev/null; }
check() {
    local name="$1" expected="$2" actual="$3"
    if [ "$actual" = "$expected" ]; then
        echo "${GREEN}PASS${NC} $name"; passed=$((passed+1))
    else
        echo "${RED}FAIL${NC} $name (expected [$expected] got [$actual])"; failed=$((failed+1))
    fi
}

PORT=$(( 20000 + ($$ % 20000) ))
WORK=$(mktemp -d)
BODY="$WORK/body"
SERVER_LOG="$WORK/server.log"
SERVER_PID=""
cleanup() { [ -n "$SERVER_PID" ] && kill "$SERVER_PID" 2>/dev/null; rm -rf "$WORK"; }
trap cleanup EXIT

echo "======================================================================"
echo "  END-TO-END HTTP SMOKE"
echo "======================================================================"

PORT="$PORT" node middleware/src/server.js >"$SERVER_LOG" 2>&1 &
SERVER_PID=$!

up=0
for _ in $(seq 1 40); do
    code=$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORT/health" 2>/dev/null || true)
    if [ "$code" = "200" ]; then up=1; break; fi
    sleep 0.25
done
if [ "$up" != 1 ]; then
    echo "${RED}FAIL${NC} gateway did not start on port $PORT"
    tail -10 "$SERVER_LOG"
    exit 1
fi

# http METHOD PATH TOKEN JSON -> sets CODE and BODY
http() {
    local method="$1" path="$2" token="${3:-}" data="${4:-}"
    local args=(-s -o "$BODY" -w '%{http_code}' -X "$method" "http://127.0.0.1:$PORT$path")
    [ -n "$token" ] && args+=(-H "Authorization: Bearer $token")
    [ -n "$data" ] && args+=(-H 'Content-Type: application/json' -d "$data")
    CODE=$(curl "${args[@]}")
}
jget() { python3 -c "import sys,json;print(json.load(sys.stdin)$1)" < "$BODY" 2>/dev/null; }

EMAIL="e2e_$(date +%s)_$$@test.com"

http GET /health
check "health is up" "200" "$CODE"

http POST /auth/signup "" "{\"email\":\"$EMAIL\",\"password\":\"secret123\",\"name\":\"E2E User\",\"dob\":\"1990-01-01\"}"
check "signup" "200" "$CODE"
CODEV=$(jget "['data'][1]")
case "$CODEV" in [0-9][0-9][0-9][0-9][0-9][0-9]) check "signup returns a 6-digit code" "ok" "ok" ;; *) check "signup returns a 6-digit code" "6 digits" "$CODEV" ;; esac

http POST /auth/verify "" "{\"email\":\"$EMAIL\",\"code\":\"$CODEV\"}"
check "verify" "200" "$CODE"

http POST /auth/login "" "{\"email\":\"$EMAIL\",\"password\":\"secret123\"}"
check "login" "200" "$CODE"
TOKEN=$(jget "['token']")
REFRESH=$(jget "['refreshToken']")
[ -n "$TOKEN" ] && check "login returns an access token" "ok" "ok" || check "login returns an access token" "a token" "empty"

# Give the new user an account so the transfer path is exercised end to end.
USER_ID=$(q "SELECT id FROM users WHERE email='$EMAIL';")
q "INSERT INTO accounts (user_id, currency_id, account_type, balance, status) VALUES ($USER_ID, 1, 'SAVINGS', 500.00, 'ACTIVE');"

http GET "/wallet/balance?email=$EMAIL" "$TOKEN"
check "balance (owner)" "200" "$CODE"
check "balance is numeric" "500.00" "$(jget "['data'][0]")"

CODE=$(curl -s -o "$BODY" -w '%{http_code}' -X POST "http://127.0.0.1:$PORT/wallet/transfer" \
    -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -H 'Idempotency-Key: e2e-1' \
    -d '{"to":"receiver@test.com","amount":"1.00"}')
check "transfer" "200" "$CODE"
CODE=$(curl -s -o "$BODY" -w '%{http_code}' -X POST "http://127.0.0.1:$PORT/wallet/transfer" \
    -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -H 'Idempotency-Key: e2e-1' \
    -d '{"to":"receiver@test.com","amount":"1.00"}')
check "transfer replay is idempotent" "200" "$CODE"

http GET "/profile?email=$EMAIL" "$TOKEN"
check "dashboard (owner)" "200" "$CODE"

http GET "/users/$EMAIL" "$TOKEN"
check "get own user" "200" "$CODE"

http GET /users "$TOKEN"
check "list users is admin-only" "403" "$CODE"

http GET "/wallet/balance?email=sender@test.com" "$TOKEN"
check "reading another balance is forbidden" "403" "$CODE"

http POST /auth/refresh "" "{\"refreshToken\":\"$REFRESH\"}"
check "refresh" "200" "$CODE"
TOKEN2=$(jget "['token']")
[ -n "$TOKEN2" ] && check "refresh returns an access token" "ok" "ok" || check "refresh returns an access token" "a token" "empty"

http GET /metrics "$TOKEN2"
check "metrics (authenticated)" "200" "$CODE"

http POST /auth/logout "" "{\"refreshToken\":\"$REFRESH\"}"
check "logout" "200" "$CODE"

http GET /nope
check "unknown route is 404" "404" "$CODE"

q "DELETE FROM accounts WHERE user_id=$USER_ID; DELETE FROM users WHERE email='$EMAIL';"

echo "======================================================================"
echo -e "Tests Completed: ${GREEN}${passed} passed${NC}, ${RED}${failed} failed${NC}"
echo "======================================================================"
[ "$failed" -eq 0 ]
