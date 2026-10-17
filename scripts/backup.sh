#!/bin/bash
# Back up the application database to a timestamped dump plus a manifest.
# The manifest records the git revision, per-table row counts, and live
# CHECKSUM TABLE values so a restore can prove it reproduced the backup.
# Backups contain password hashes and MFA secrets: the file is chmod 600
# and must be moved to owner-approved encrypted storage (see the runbook).
# Usage: DB_NAME=cobol_db DB_USER=cobol_user DB_PASS=cobol_pass
#        ./scripts/backup.sh [output-dir]
set -euo pipefail

OUT_DIR="${1:-./backups}"
DB_NAME="${DB_NAME:-cobol_db}"
DB_USER="${DB_USER:-cobol_user}"
DB_PASS="${DB_PASS:-cobol_pass}"

mkdir -p "$OUT_DIR"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
STAMP="cobol-${DB_NAME}-${TS}"
SQL="$OUT_DIR/${STAMP}.sql"
MANIFEST="$OUT_DIR/${STAMP}.manifest"

TABLES="users accounts currencies exchange_rates journal_entries ledger ledger_archive verification_logs audit_trail audit_trail_archive pending_transactions pending_transactions_archive transfer_reversals account_holds fee_schedule reconciliation_runs reconciliation_findings dual_control_operations maker_requests notification_outbox mfa_backup_codes mfa_recovery_requests dispute_cases dispute_messages refresh_sessions refresh_families revoked_access_tokens schema_migrations"

mysqldump -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" \
    --single-transaction --routines --triggers --events \
    --result-file="$SQL"
chmod 600 "$SQL"

{
    echo "backup: $STAMP"
    echo "db: $DB_NAME"
    echo "created_utc: $TS"
    echo "git_rev: $(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
    for t in $TABLES; do
        row="$(mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -N -B -e "SELECT COUNT(*) FROM \`$t\`;" 2>/dev/null || echo MISSING)"
        sum="$(mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -N -B -e "CHECKSUM TABLE \`$t\`;" 2>/dev/null | awk '{print $2}' || echo MISSING)"
        echo "table $t rows=$row checksum=$sum"
    done
} > "$MANIFEST"
chmod 600 "$MANIFEST"

echo "wrote $SQL"
echo "wrote $MANIFEST"
