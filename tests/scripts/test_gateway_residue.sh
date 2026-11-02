#!/usr/bin/env bash
# Unit tests for scripts/check_test_residue.sh. Cases 1-6 need no database:
# a fake `mysql` earlier in PATH answers the COUNT/email queries. Case 7 uses
# the live database when reachable and skips otherwise (so run.sh stays green
# offline).
# Usage: tests/scripts/test_gateway_residue.sh (or via tests/scripts/run.sh)
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$ROOT/scripts/check_test_residue.sh"

PASS=0
FAIL=0
ok() { PASS=$((PASS + 1)); echo "ok - $1"; }
not_ok() { FAIL=$((FAIL + 1)); echo "not ok - $1"; }

make_fake_mysql() {
    local dir="$1"
    mkdir -p "$dir"
    cat > "$dir/mysql" <<'EOF'
#!/usr/bin/env bash
# Fake mysql for residue tests: log every call, answer COUNT/email queries
# from the environment, fail nothing.
echo "CALL: $*" >> "$FAKE_LOG"
case "$*" in
    *"SELECT COUNT("*) echo "${FAKE_COUNT:-0}"; exit 0 ;;
    *"SELECT email"*) printf '%b' "${FAKE_EMAILS:-}"; exit 0 ;;
esac
exit 0
EOF
    chmod +x "$dir/mysql"
}

# --- case 1: no TEST_RUN_ID and no namespaces is a usage error ---
rc=0
env -u TEST_RUN_ID bash "$SCRIPT" >/dev/null 2>&1 || rc=$?
if [ "$rc" = "2" ]; then
    ok "missing TEST_RUN_ID is a usage error (exit 2)"
else
    not_ok "missing TEST_RUN_ID exits 2 (got $rc)"
fi

# --- case 2: TEST_RUN_ID with no alphanumeric characters is rejected ---
rc=0
TEST_RUN_ID="!!!" bash "$SCRIPT" >/dev/null 2>&1 || rc=$?
if [ "$rc" = "2" ]; then
    ok "non-alphanumeric TEST_RUN_ID is rejected (exit 2)"
else
    not_ok "non-alphanumeric TEST_RUN_ID exits 2 (got $rc)"
fi

# --- case 3: explicit namespaces with LIKE metacharacters are rejected ---
FAKE3="$(mktemp -d "${TMPDIR:-/tmp}/residue-guard.XXXXXX")"
make_fake_mysql "$FAKE3"
export FAKE_LOG="$FAKE3/calls.log"
: > "$FAKE_LOG"
rc=0
PATH="$FAKE3:$PATH" bash "$SCRIPT" 'foo%bar' >/dev/null 2>&1 || rc=$?
if [ "$rc" = "2" ]; then
    ok "namespace with LIKE metacharacters is rejected (exit 2)"
else
    not_ok "LIKE-metachar namespace exits 2 (got $rc)"
fi
rm -rf "$FAKE3"

# --- case 4: zero leftovers is OK (TEST_RUN_ID form) ---
FAKE4="$(mktemp -d "${TMPDIR:-/tmp}/residue-guard.XXXXXX")"
make_fake_mysql "$FAKE4"
export FAKE_LOG="$FAKE4/calls.log"
: > "$FAKE_LOG"
out="$(FAKE_COUNT=0 FAKE_LOG="$FAKE_LOG" TEST_RUN_ID="tFake123" PATH="$FAKE4:$PATH" bash "$SCRIPT" 2>&1)"
rc=$?
if [ "$rc" = "0" ] && echo "$out" | grep -q "OK: no leftover test users"; then
    if grep -q "%-tFake123-%" "$FAKE_LOG"; then
        ok "clean run reports OK and queries the run-id pattern"
    else
        not_ok "clean run queries the run-id pattern (log below)"; cat "$FAKE_LOG"
    fi
else
    not_ok "clean run exits 0 with OK (rc=$rc, out: $out)"
fi
rm -rf "$FAKE4"

# --- case 5: leftovers fail and are listed (TEST_RUN_ID form) ---
FAKE5="$(mktemp -d "${TMPDIR:-/tmp}/residue-guard.XXXXXX")"
make_fake_mysql "$FAKE5"
export FAKE_LOG="$FAKE5/calls.log"
: > "$FAKE_LOG"
out="$(FAKE_COUNT=2 FAKE_EMAILS='xx-tFake123-a@test.com\nxx-tFake123-b@test.com\n' FAKE_LOG="$FAKE_LOG" TEST_RUN_ID="tFake123" PATH="$FAKE5:$PATH" bash "$SCRIPT" 2>&1)"
rc=$?
if [ "$rc" = "1" ] && echo "$out" | grep -q "2 leftover" \
    && echo "$out" | grep -q "xx-tFake123-a@test.com" \
    && echo "$out" | grep -q "cleanupNamespace"; then
    ok "dirty run exits 1, lists emails, and points at cleanupNamespace"
else
    not_ok "dirty run exits 1 with email list and hint (rc=$rc, out: $out)"
fi
rm -rf "$FAKE5"

# --- case 6: explicit-namespace form checks the namespace prefix ---
FAKE6="$(mktemp -d "${TMPDIR:-/tmp}/residue-guard.XXXXXX")"
make_fake_mysql "$FAKE6"
export FAKE_LOG="$FAKE6/calls.log"
: > "$FAKE_LOG"
out="$(FAKE_COUNT=0 FAKE_LOG="$FAKE_LOG" PATH="$FAKE6:$PATH" bash "$SCRIPT" 'gw-abc-123' 2>&1)"
rc=$?
if [ "$rc" = "0" ] && grep -q "gw-abc-123-%" "$FAKE_LOG"; then
    ok "explicit namespace checks the namespace prefix"
else
    not_ok "explicit namespace checks the prefix (rc=$rc, out: $out)"; cat "$FAKE_LOG"
fi
rm -rf "$FAKE6"

# --- case 7: live round-trip when the database is reachable ---
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-3306}"
DB_USER="${DB_USER:-cobol_user}"
DB_PASS="${DB_PASS:-cobol_pass}"
DB_NAME="${DB_NAME:-cobol_db}"
if mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "SELECT 1;" >/dev/null 2>&1; then
    rid="liveres$(date +%s%N)"
    mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" \
        -e "INSERT INTO users (email,password_hash,full_name,dob,status,role) VALUES ('zz-${rid}-leak@test.com','h','L','1990-01-01','VERIFIED','USER');" >/dev/null 2>&1
    rc=0
    TEST_RUN_ID="$rid" bash "$SCRIPT" >/dev/null 2>&1 || rc=$?
    if [ "$rc" = "1" ]; then
        ok "live sentinel row is detected (exit 1)"
    else
        not_ok "live sentinel exits 1 (got $rc)"
    fi
    mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" \
        -e "DELETE FROM users WHERE email LIKE '%-${rid}-%';" >/dev/null 2>&1
    if TEST_RUN_ID="$rid" bash "$SCRIPT" >/dev/null 2>&1; then
        ok "live database is clean after deleting the sentinel"
    else
        not_ok "live database is clean after deleting the sentinel (rc=$?)"
    fi
else
    ok "SKIP live round-trip (no database reachable at $DB_HOST:$DB_PORT)"
fi

echo "=== GATEWAY RESIDUE: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
