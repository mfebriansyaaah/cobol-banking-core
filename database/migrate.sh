#!/bin/bash
# Apply pending database migrations once each, recording them in
# schema_migrations. Idempotent: already-applied migrations are skipped.
# Tamper-evident (P1-4): every recorded version also stores the SHA-256 of
# its file in schema_migrations.checksum (added by 0666). --check fails when
# an applied file no longer matches its hash; --backfill-checksums fills
# hashes for rows that predate 0666 (explicit operator acknowledgement).
# Usage: database/migrate.sh [--check | --only <version> | --up-to <version> | --backfill-checksums | --baseline]

set -e
cd "$(dirname "$0")/.."

# Optional developer env file (tests/.dbenv.example copy); absent in CI.
# shellcheck disable=SC1091
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

# Stored objects record the session charset at CREATE time (notably
# information_schema.TRIGGERS.CHARACTER_SET_CLIENT), so the migrate client
# version must not leak into the built schema: without the pin, a 10.11
# client builds utf8mb3 triggers while an 11.8 client builds utf8mb4 ones,
# and check_schema_drift.sh fails on identical sources.
mysqlc() { mysql --default-character-set=utf8mb4 -h "$DB_HOST" -P "$DB_PORT" -u "$DB_MIGRATE_USER" -p"$DB_MIGRATE_PASS" "$DB_NAME" "$@"; }

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

# Active vs archived migrations (PR-011): pre-baseline files live in
# database/migrations/archive/ and are never applied or scanned for pending
# work; they are still checksum-verified for existing databases. New files
# must sort above every archived version ("tolak migrasi < baseline").
ACTIVE_GLOB="database/migrations/*.sql"
ARCHIVE_GLOB="database/migrations/archive/*.sql"

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
# Archived versions resolve under database/migrations/archive/.
backfill_versions() {
    [ "$HAS_CHECKSUM_COL" = "1" ] || return 0
    for v in $1; do
        f="database/migrations/$v.sql"
        [ -f "$f" ] || f="database/migrations/archive/$v.sql"
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
    if [ ! -f "$f" ]; then
        if [ -f "database/migrations/archive/$v.sql" ]; then
            echo "refusing archived migration $v (at or below baseline v2); restore from archive deliberately instead" >&2
            exit 2
        fi
        echo "unknown migration: $v" >&2
        exit 2
    fi
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
    for f in $ACTIVE_GLOB $ARCHIVE_GLOB; do
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
        for f in $ACTIVE_GLOB $ARCHIVE_GLOB; do
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
        # A recorded baseline pins its snapshot file: an edited (or deleted)
        # schema_v2.sql fails here instead of silently changing fresh installs.
        if is_applied "baseline_v2"; then
            want_baseline="$(file_sha "database/schema_v2.sql" 2>/dev/null || true)"
            have_baseline="$(mysqlc -N -B -e "SELECT checksum FROM schema_migrations WHERE version='baseline_v2';" 2>/dev/null)"
            if [ "$have_baseline" != "$want_baseline" ]; then
                echo "checksum MISMATCH: baseline snapshot database/schema_v2.sql was edited after this database was baselined (restore the file or re-baseline deliberately): baseline_v2"
                exit 1
            fi
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
    if [ -f "database/migrations/archive/$UPTO.sql" ]; then
        echo "refusing archived migration $UPTO (at or below baseline v2); restore from archive deliberately instead" >&2
        exit 2
    fi
    [ -f "database/migrations/$UPTO.sql" ] || { echo "unknown migration: $UPTO" >&2; exit 2; }
fi

# Baseline v2 (PR-010): fresh installs apply database/schema_v2.sql once and
# record every current migration as covered-by-baseline (with current
# hashes) plus a baseline_v2 marker; existing databases must verify clean
# (same membership + hash rules as --check) before the marker lands. Either
# way the run then falls through to the normal apply loop, so migrations
# added after the baseline apply normally on both kinds of database.
# schema_v2.sql is immutable once recorded (its hash rides the marker row);
# --check reports an edited baseline file as a baseline_v2 mismatch.
if [ "$1" = "--baseline" ]; then
    BASELINE_FILE="database/schema_v2.sql"
    [ -f "$BASELINE_FILE" ] || { echo "missing baseline snapshot: $BASELINE_FILE" >&2; exit 2; }
    # Pre-CREATE state (the unconditional CREATE TABLE below runs for every
    # mode): a missing/empty schema_migrations means nothing was ever applied.
    had_table="$(mysqlc -N -B -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = 'schema_migrations';" 2>/dev/null || echo 0)"
    had_rows="0"
    if [ "$had_table" = "1" ]; then
        had_rows="$(mysqlc -N -B -e "SELECT COUNT(*) FROM schema_migrations;" 2>/dev/null || echo 0)"
    fi
    if [ "$had_table" = "0" ] || [ "$had_rows" = "0" ]; then
        # Fresh install. Refuse a non-empty database without history: the
        # snapshot rebuilds schema objects and would silently discard
        # hand-built data.
        other_tables="$(mysqlc -N -B -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name <> 'schema_migrations';" 2>/dev/null || echo 0)"
        if [ "$other_tables" != "0" ]; then
            echo "cannot baseline a non-empty database without migration history (tables present, schema_migrations empty); restore or migrate normally" >&2
            exit 1
        fi
        echo "applying baseline: $BASELINE_FILE"
        if err=$(mysqlc < "$BASELINE_FILE" 2>&1); then
            detect_checksum_col
            versions=""
            for f in $ARCHIVE_GLOB; do
                [ -e "$f" ] || continue
                v="$(basename "$f" .sql)"
                versions="$versions('$v', '$(file_sha "$f")'),"
            done
            versions="${versions%,}"
            if [ -n "$versions" ]; then
                mysqlc -e "INSERT IGNORE INTO schema_migrations (version, checksum) VALUES $versions;" 2>/dev/null
            fi
            mysqlc -e "INSERT IGNORE INTO schema_migrations (version, checksum) VALUES ('baseline_v2', '$(file_sha "$BASELINE_FILE")');" 2>/dev/null
            echo "baseline applied (covered migrations recorded as skipped)"
        else
            echo "baseline FAILED"
            echo "$err" | head -5
            exit 1
        fi
    else
        # Existing database: must verify clean before the marker lands.
        load_applied
        pending=""
        for f in $ACTIVE_GLOB $ARCHIVE_GLOB; do
            [ -e "$f" ] || continue
            v="$(basename "$f" .sql)"
            is_applied "$v" || pending="$pending $v"
        done
        if [ -n "$pending" ]; then
            echo "cannot baseline a partially-migrated database; pending migrations:$pending"
            echo "finish migrations or restore from backup first" >&2
            exit 1
        fi
        if [ "$HAS_CHECKSUM_COL" = "1" ]; then
            stored="$(mysqlc -N -B -e "SELECT CONCAT(version, ' ', IFNULL(checksum, 'MISSING')) FROM schema_migrations;" 2>/dev/null)"
            bad=""
            for f in $ACTIVE_GLOB $ARCHIVE_GLOB; do
                [ -e "$f" ] || continue
                v="$(basename "$f" .sql)"
                is_applied "$v" || continue
                want="$(file_sha "$f")"
                case $'\n'"$stored"$'\n' in
                    *$'\n'"$v $want"$'\n'*) ;;
                    *) bad="$bad $v" ;;
                esac
            done
            if [ -n "$bad" ]; then
                echo "cannot baseline: checksum mismatch (applied file edited):$bad"
                echo "run database/migrate.sh --backfill-checksums first (explicit acknowledgement)" >&2
                exit 1
            fi
        fi
        if is_applied "baseline_v2"; then
            echo "already baselined"
        else
            detect_checksum_col
            mysqlc -e "INSERT INTO schema_migrations (version, checksum) VALUES ('baseline_v2', '$(file_sha "$BASELINE_FILE")');" 2>/dev/null
            echo "baseline recorded"
        fi
    fi
fi

load_applied
applied_any=0
applied_this_run=""
# New files must sort above the baseline cutoff, or glob order would apply
# them before their prerequisites.
cutoff=""
for f in $ARCHIVE_GLOB; do
    [ -e "$f" ] || continue
    v="$(basename "$f" .sql)"
    if [ -z "$cutoff" ] || [ "$v" \> "$cutoff" ]; then cutoff="$v"; fi
done
for f in $ACTIVE_GLOB; do
    [ -e "$f" ] || continue
    v="$(basename "$f" .sql)"
    if [ -n "$cutoff" ] && [ "$v" \< "$cutoff" ]; then
        echo "refusing migration $v below baseline cutoff $cutoff; rename it above the baseline" >&2
        exit 1
    fi
done
# Archived versions first (oldest), then active: the pending set replays in
# global order, exactly as before the split.
for f in $ARCHIVE_GLOB $ACTIVE_GLOB; do
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
