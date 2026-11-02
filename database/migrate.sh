#!/bin/bash
# Apply pending database migrations once each, recording them in
# schema_migrations. Idempotent: already-applied migrations are skipped.
# Tamper-evident (P1-4): every recorded version also stores the SHA-256 of
# its file in schema_migrations.checksum (added by 0666). --check fails when
# an applied file no longer matches its hash; --backfill-checksums fills
# hashes for rows that predate 0666 (explicit operator acknowledgement).
# Usage: database/migrate.sh [--check | --only <version> | --up-to <version> | --backfill-checksums]

set -e
cd "$(dirname "$0")/.."

if [ -f ./tests/.dbenv ]; then . ./tests/.dbenv; fi
DB_USER="${DB_USER:-cobol_user}"
DB_PASS="${DB_PASS:-cobol_pass}"
DB_NAME="${DB_NAME:-cobol_db}"
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-3306}"

# Migrations create/alter/drop schema objects, so they need DDL rights. Run
# them under a dedicated privileged account (see database/grants.sh) instead of
# the DML-only application account; defaults to the app credentials for
# backward compatibility.
DB_MIGRATE_USER="${DB_MIGRATE_USER:-$DB_USER}"
DB_MIGRATE_PASS="${DB_MIGRATE_PASS:-$DB_PASS}"

mysqlc() { mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_MIGRATE_USER" -p"$DB_MIGRATE_PASS" "$DB_NAME" "$@"; }

# Load every recorded version once, then answer membership questions in shell.
# The old loop spawned one mysql client per migration file (101 clients per
# --check); this keeps it at one query per invocation.
APPLIED=""
load_applied() {
    APPLIED="$(mysqlc -N -B -e "SELECT version FROM schema_migrations;" 2>/dev/null || true)"
}
is_applied() {
    case $'\n'"$APPLIED"$'\n' in
        *$'\n'"$1"$'\n'*) return 0 ;;
    esac
    return 1
}

mysqlc -e "CREATE TABLE IF NOT EXISTS schema_migrations (
    version VARCHAR(64) PRIMARY KEY,
    applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;" 2>/dev/null

# SHA-256 of a migration file, recorded at apply time and verified by --check.
file_sha() { sha256sum "$1" | awk '{print $1}'; }

# schema_migrations.checksum exists once 0666 has applied. Versions applied
# before that recorded no hash; detect once per invocation so INSERTs stay
# valid on old and new databases alike.
HAS_CHECKSUM_COL=""
detect_checksum_col() {
    HAS_CHECKSUM_COL="$(mysqlc -N -B -e "SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = 'schema_migrations' AND column_name = 'checksum';" 2>/dev/null || echo 0)"
}
detect_checksum_col

# Record one applied version with its file hash when the column exists.
record_version() {
    if [ "$HAS_CHECKSUM_COL" = "1" ]; then
        mysqlc -e "INSERT INTO schema_migrations (version, checksum) VALUES ('$1', '$(file_sha "$2")');" 2>/dev/null
    else
        mysqlc -e "INSERT INTO schema_migrations (version) VALUES ('$1');" 2>/dev/null
    fi
}

# Fill missing hashes for versions applied by this run (or named explicitly).
# The AND checksum IS NULL guard never overwrites a recorded hash, so a
# tampered file is reported by --check instead of silently re-baselined.
backfill_versions() {
    [ "$HAS_CHECKSUM_COL" = "1" ] || return 0
    for v in $1; do
        f="database/migrations/$v.sql"
        [ -f "$f" ] || continue
        mysqlc -e "UPDATE schema_migrations SET checksum = '$(file_sha "$f")' WHERE version = '$v' AND checksum IS NULL;" 2>/dev/null
    done
}

# Apply exactly one version (used by the replay test so it does not scan every
# file for each iteration). Idempotent: an already-recorded version is a no-op.
if [ "$1" = "--only" ]; then
    v="${2:-}"
    [ -n "$v" ] || { echo "usage: migrate.sh --only <version>" >&2; exit 2; }
    f="database/migrations/$v.sql"
    [ -f "$f" ] || { echo "unknown migration: $v" >&2; exit 2; }
    already="$(mysqlc -N -B -e "SELECT COUNT(*) FROM schema_migrations WHERE version='$v';" 2>/dev/null)"
    if [ "$already" = "1" ]; then
        echo "already applied: $v"
        exit 0
    fi
    echo "applying: $v"
    if err=$(mysqlc < "$f" 2>&1); then
        record_version "$v" "$f"
        detect_checksum_col
        backfill_versions "$v"
        echo "migrations applied"
        exit 0
    else
        echo "migration FAILED: $v"
        echo "$err" | head -5
        exit 1
    fi
fi

if [ "$1" = "--check" ]; then
    load_applied
    pending=""
    for f in database/migrations/*.sql; do
        [ -e "$f" ] || continue
        v="$(basename "$f" .sql)"
        is_applied "$v" || pending="$pending $v"
    done
    if [ -n "$pending" ]; then
        echo "pending migrations:$pending"
        exit 1
    fi
    if [ "$HAS_CHECKSUM_COL" = "1" ]; then
        stored="$(mysqlc -N -B -e "SELECT CONCAT(version, ' ', IFNULL(checksum, 'MISSING')) FROM schema_migrations;" 2>/dev/null)"
        mismatch=""
        unfilled=""
        for f in database/migrations/*.sql; do
            [ -e "$f" ] || continue
            v="$(basename "$f" .sql)"
            is_applied "$v" || continue
            want="$(file_sha "$f")"
            case $'\n'"$stored"$'\n' in
                *$'\n'"$v $want"$'\n'*) ;;
                *$'\n'"$v MISSING"$'\n'*) unfilled="$unfilled $v" ;;
                *) mismatch="$mismatch $v" ;;
            esac
        done
        if [ -n "$mismatch" ]; then
            echo "checksum MISMATCH (applied file edited, restore or re-apply deliberately):$mismatch"
            exit 1
        fi
        if [ -n "$unfilled" ]; then
            echo "checksum missing for$unfilled"
            echo "run database/migrate.sh --backfill-checksums to record current file hashes"
            exit 1
        fi
    fi
    echo "all migrations applied"
    exit 0
fi

if [ "$1" = "--backfill-checksums" ]; then
    if [ "$HAS_CHECKSUM_COL" != "1" ]; then
        echo "no checksum column; apply migrations first (0666 adds it)" >&2
        exit 2
    fi
    nulls="$(mysqlc -N -B -e "SELECT version FROM schema_migrations WHERE checksum IS NULL;" 2>/dev/null)"
    if [ -z "$nulls" ]; then
        echo "no missing checksums"
        exit 0
    fi
    backfill_versions "$nulls"
    filled="$(mysqlc -N -B -e "SELECT COUNT(*) FROM schema_migrations WHERE checksum IS NULL;" 2>/dev/null)"
    echo "backfilled checksums ($filled still missing: file gone or apply failed)"
    exit 0
fi

# Apply pending migrations only up to and including the named version; later
# files stay pending. Used by the snapshot-based rollback drill.
UPTO=""
if [ "$1" = "--up-to" ]; then
    UPTO="${2:-}"
    [ -n "$UPTO" ] || { echo "usage: migrate.sh --up-to <version>" >&2; exit 2; }
    [ -f "database/migrations/$UPTO.sql" ] || { echo "unknown migration: $UPTO" >&2; exit 2; }
fi

load_applied
applied_any=0
applied_this_run=""
for f in database/migrations/*.sql; do
    [ -e "$f" ] || continue
    v="$(basename "$f" .sql)"
    if is_applied "$v"; then
        echo "already applied: $v"
    else
        echo "applying: $v"
        # Fail loudly naming the file: a swallowed error once hid which
        # migration broke a fresh install. The version is only recorded on
        # success, so a retry resumes here instead of skipping silently.
        if err=$(mysqlc < "$f" 2>&1); then
            record_version "$v" "$f"
            APPLIED="$APPLIED"$'\n'"$v"
            applied_this_run="$applied_this_run $v"
            applied_any=1
        else
            echo "migration FAILED: $v"
            echo "$err" | head -5
            exit 1
        fi
    fi
    # --up-to stops after the named version (applied or already present):
    # later files stay pending. Used by the snapshot-based rollback drill.
    if [ -n "${UPTO:-}" ] && [ "$v" = "$UPTO" ]; then
        echo "stopping at: $UPTO"
        break
    fi
done

if [ "$applied_any" = "1" ]; then
    # The checksum column itself may have arrived mid-run (0666): re-detect
    # before filling hashes for the versions this run applied. Historical
    # NULLs from older runs are left alone for --backfill-checksums.
    detect_checksum_col
    backfill_versions "$applied_this_run"
    echo "migrations applied"
else
    echo "no pending migrations"
fi
