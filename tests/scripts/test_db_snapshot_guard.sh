#!/usr/bin/env bash
# Safety tests for scripts/ci/build_db_snapshot.sh (CI-008A). No database needed.
# Fake `mysql`/`mysqldump` earlier in PATH record every invocation; the
# producer runs fully offline. MIGRATE_SH points at a fake migrate script so
# the --check gate can be forced green or red. Asserts:
#   1. DB_NAME=mysql (system database) is refused BEFORE any dump (exit 2).
#   2. An empty DB_NAME is refused (exit 2).
#   3. A missing DB_MIGRATE_PASS is refused (exit 2, no dump attempted).
#   4. A failing `migrate.sh --check` aborts BEFORE any dump (no snapshot).
#   5. Happy path: fake migrate green + fake dump -> gzip snapshot written,
#      size and table count printed, password absent from output.
#   6. The dump uses the D5 default flags (--single-transaction --routines
#      --triggers) and NOT --no-tablespaces (unverified without a live S1
#      smoke; see scripts/ci/build_db_snapshot.sh).
# Usage: tests/scripts/test_db_snapshot_guard.sh
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PRODUCER="$ROOT/scripts/ci/build_db_snapshot.sh"

PASS=0
FAIL=0
ok() { PASS=$((PASS + 1)); echo "ok - $1"; }
not_ok() { FAIL=$((FAIL + 1)); echo "not ok - $1"; }

make_fakes() {
    local dir="$1"
    mkdir -p "$dir"
    cat > "$dir/mysqldump" <<'EOF'
#!/usr/bin/env bash
# Fake mysqldump: log the flags, emit a canned dump on stdout.
echo "DUMPFLAGS: $*" >> "$FAKE_LOG"
printf -- '-- fake dump of %s\nCREATE TABLE `users` (`id` INT);\n' "$DB_NAME"
EOF
    cat > "$dir/mysql" <<'EOF'
#!/usr/bin/env bash
# Fake mysql: log every call, answer the table-count query like a migrated DB.
echo "CALL: $*" >> "$FAKE_LOG"
for a in "$@"; do
    case "$a" in
        *"COUNT(*) FROM information_schema.tables"*)
            echo "500"
            exit 0
            ;;
    esac
done
exit 0
EOF
    chmod +x "$dir/mysqldump" "$dir/mysql"
}

make_migrate() {
    # $1 = dir, $2 = exit code
    printf '#!/usr/bin/env bash\nexit %s\n' "$2" > "$1/migrate_fake.sh"
    chmod +x "$1/migrate_fake.sh"
}

# --- case 1: system database is refused before any dump ---
FAKE1="$(mktemp -d "${TMPDIR:-/tmp}/snap-guard.XXXXXX")"
make_fakes "$FAKE1"
export FAKE_LOG="$FAKE1/calls.log"
: > "$FAKE_LOG"
if DB_NAME="mysql" DB_HOST="192.0.2.1" DB_PORT="3306" \
    DB_MIGRATE_USER="u" DB_MIGRATE_PASS="p" \
    MIGRATE_SH="$FAKE1/migrate_fake.sh" PATH="$FAKE1:$PATH" \
    bash "$PRODUCER" "$FAKE1/out.sql.gz" >/dev/null 2>&1; then
    not_ok "system DB_NAME=mysql is refused"
else
    rc=$?
    if [ "$rc" = "2" ] && ! grep -q "DUMPFLAGS" "$FAKE_LOG" 2>/dev/null; then
        ok "system DB_NAME=mysql is refused before dump (exit 2, no dump)"
    else
        not_ok "system DB_NAME=mysql is refused before dump (rc=$rc)"
    fi
fi

# --- case 2: empty DB name is refused ---
FAKE2="$(mktemp -d "${TMPDIR:-/tmp}/snap-guard.XXXXXX")"
make_fakes "$FAKE2"
make_migrate "$FAKE2" 0
export FAKE_LOG="$FAKE2/calls.log"
: > "$FAKE2/calls.log"
if DB_NAME="" DB_HOST="127.0.0.1" DB_PORT="3306" \
    DB_MIGRATE_USER="u" DB_MIGRATE_PASS="p" \
    MIGRATE_SH="$FAKE2/migrate_fake.sh" PATH="$FAKE2:$PATH" \
    bash "$PRODUCER" "$FAKE2/out.sql.gz" >/dev/null 2>&1; then
    not_ok "empty DB_NAME is refused"
else
    rc=$?
    if [ "$rc" = "2" ]; then
        ok "empty DB_NAME is refused (exit 2)"
    else
        not_ok "empty DB_NAME is refused (rc=$rc, want 2)"
    fi
fi

# --- case 3: missing migrate password is refused before any dump ---
FAKE3="$(mktemp -d "${TMPDIR:-/tmp}/snap-guard.XXXXXX")"
make_fakes "$FAKE3"
make_migrate "$FAKE3" 0
export FAKE_LOG="$FAKE3/calls.log"
: > "$FAKE3/calls.log"
if env -u DB_MIGRATE_PASS DB_NAME="cobol_db" DB_HOST="127.0.0.1" DB_PORT="3306" \
    DB_MIGRATE_USER="u" \
    MIGRATE_SH="$FAKE3/migrate_fake.sh" PATH="$FAKE3:$PATH" \
    bash "$PRODUCER" "$FAKE3/out.sql.gz" >/dev/null 2>&1; then
    not_ok "missing DB_MIGRATE_PASS is refused"
else
    rc=$?
    if [ "$rc" = "2" ] && ! grep -q "DUMPFLAGS" "$FAKE_LOG" 2>/dev/null; then
        ok "missing DB_MIGRATE_PASS is refused before dump (exit 2, no dump)"
    else
        not_ok "missing DB_MIGRATE_PASS is refused before dump (rc=$rc)"
    fi
fi

# --- case 4: failing migrate --check aborts before any dump ---
FAKE4="$(mktemp -d "${TMPDIR:-/tmp}/snap-guard.XXXXXX")"
make_fakes "$FAKE4"
make_migrate "$FAKE4" 1
export FAKE_LOG="$FAKE4/calls.log"
: > "$FAKE4/calls.log"
if DB_NAME="cobol_db" DB_HOST="127.0.0.1" DB_PORT="3306" \
    DB_MIGRATE_USER="u" DB_MIGRATE_PASS="p" \
    MIGRATE_SH="$FAKE4/migrate_fake.sh" PATH="$FAKE4:$PATH" \
    bash "$PRODUCER" "$FAKE4/out.sql.gz" >/dev/null 2>&1; then
    not_ok "failing migrate --check aborts the producer"
else
    if ! grep -q "DUMPFLAGS" "$FAKE_LOG" 2>/dev/null && [ ! -s "$FAKE4/out.sql.gz" ]; then
        ok "failing migrate --check aborts before dump (no dump, no snapshot)"
    else
        not_ok "failing migrate --check aborts before dump"
    fi
fi

# --- cases 5+6: happy path pins output, size/count report, and D5 flags ---
FAKE5="$(mktemp -d "${TMPDIR:-/tmp}/snap-guard.XXXXXX")"
make_fakes "$FAKE5"
make_migrate "$FAKE5" 0
export FAKE_LOG="$FAKE5/calls.log"
: > "$FAKE5/calls.log"
OUT5="$FAKE5/snap.sql.gz"
if DB_NAME="cobol_db" DB_HOST="127.0.0.1" DB_PORT="3306" \
    DB_MIGRATE_USER="u" DB_MIGRATE_PASS="s3cr3t-pass" \
    MIGRATE_SH="$FAKE5/migrate_fake.sh" PATH="$FAKE5:$PATH" \
    bash "$PRODUCER" "$OUT5" > "$FAKE5/stdout.log" 2> "$FAKE5/stderr.log"; then
    if [ -s "$OUT5" ] && gzip -dc "$OUT5" 2>/dev/null | grep -q "fake dump"; then
        ok "producer writes a non-empty gzip snapshot"
    else
        not_ok "producer writes a non-empty gzip snapshot"
    fi
    if grep -q "bytes" "$FAKE5/stdout.log" && grep -q "tables" "$FAKE5/stdout.log"; then
        ok "producer prints size and table count"
    else
        not_ok "producer prints size and table count"
    fi
    if grep -q "s3cr3t-pass" "$FAKE5/stdout.log" "$FAKE5/stderr.log" 2>/dev/null; then
        not_ok "producer never prints the DB password"
    else
        ok "producer never prints the DB password"
    fi
    FLAGS="$(grep "DUMPFLAGS" "$FAKE_LOG" 2>/dev/null || true)"
    if echo "$FLAGS" | grep -q -- "--single-transaction" \
        && echo "$FLAGS" | grep -q -- "--routines" \
        && echo "$FLAGS" | grep -q -- "--triggers"; then
        ok "dump uses --single-transaction --routines --triggers"
    else
        not_ok "dump uses --single-transaction --routines --triggers (got: $FLAGS)"
    fi
    if echo "$FLAGS" | grep -q -- "--no-tablespaces"; then
        not_ok "dump omits --no-tablespaces per D5 default (got: $FLAGS)"
    else
        ok "dump omits --no-tablespaces per D5 default"
    fi
else
    not_ok "producer succeeds offline with fakes (happy path)"
fi

rm -rf "$FAKE1" "$FAKE2" "$FAKE3" "$FAKE4" "$FAKE5"

echo "# pass=$PASS fail=$FAIL total=$((PASS + FAIL))"
[ "$FAIL" -eq 0 ]
