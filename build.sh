#!/bin/bash
# Build Script for COBOL MySQL Backend (Simulated DB Executable)
# Usage: ./build.sh [make-target]
#
# Default: incremental parallel build via cobol/Makefile (see that file for
# details). JOBS controls parallelism (default: nproc).
# Fallback: BUILD_LEGACY=1 runs the original single-shot `cobc` compile.
#
# NOTE: check_manifest.mjs and scripts/ci/coverage.sh grep the explicit
# source list in the legacy branch below; keep it in sync when
# adding/removing modules (or run `make -f cobol/Makefile print-sources`).

set -e

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

COBOL_BIN="cobol/bin/main_logic"
JOBS="${JOBS:-$(nproc 2>/dev/null || echo 4)}"
echo "=========================================="
echo "  Building COBOL MySQL Backend (SIM)"
echo "=========================================="

mkdir -p cobol/bin

if [ "${BUILD_LEGACY:-0}" = "1" ]; then
    echo "--- legacy single-shot build (BUILD_LEGACY=1) ---"
    # Compile and link the curated modules and the C bridge.
    cobc -free -x -I cobol/copy -O2 -o "$COBOL_BIN" \
    cobol/src/main_logic.cob \
    cobol/src/user_core.cob \
    cobol/src/wallet_core.cob \
    cobol/src/auth_core.cob \
    cobol/src/hashlen_core.cob \
    cobol/src/loan_schedule_core.cob \
    cobol/src/collection_core.cob \
    cobol/src/payment_clearing_core.cob \
    cobol/src/treasury_liquidity_core.cob \
    cobol/src/gl_allocation_core.cob \
    cobol/src/fixed_asset_core.cob \
    cobol/src/cost_center_core.cob \
    cobol/src/account_core.cob \
    cobol/src/collateral_core.cob \
    cobol/src/backup_drill_core.cob \
    cobol/src/report_builder_core.cob \
    cobol/src/auth_password_core.cob \
    cobol/src/ref_engine.cob \
    cobol/src/gl_core.cob \
    cobol/src/report_core.cob \
    cobol/src/dashboard_core.cob \
    cobol/src/statement_recon_core.cob \
    cobol/src/payment_instruction_core.cob \
    cobol/src/import_recon_core.cob \
    cobol/src/payment_hold_core.cob \
    cobol/src/loan_core.cob \
    cobol/src/merchant_core.cob \
    cobol/src/trade_finance_core.cob \
    cobol/src/collateral_mgmt_core.cob \
    cobol/src/compliance_calendar_core.cob \
    cobol/src/collateral_repossession_core.cob \
    cobol/src/loyalty_program_core.cob \
    cobol/src/loyalty_core.cob \
    cobol/src/rewards_management_core.cob \
    cobol/src/cashback_core.cob \
    cobol/src/points_redemption_core.cob \
    cobol/src/tax_withholding_core.cob \
    cobol/src/factoring_core.cob \
    cobol/src/export_finance_core.cob \
    cobol/src/import_finance_core.cob \
    cobol/src/documentary_credit_core.cob \
    cobol/src/bankers_acceptance_core.cob \
    cobol/src/tax_item_core.cob \
    cobol/src/collateralized_core.cob \
    cobol/src/chargeback_core.cob \
    cobol/src/dispute_management_core.cob \
    cobol/src/tax_management_core.cob \
    cobol/src/merchant_settlement_core.cob \
    cobol/src/payroll_processing_core.cob \
    cobol/src/bank_guarantee_core.cob \
    cobol/src/letter_of_credit_core.cob \
    cobol/src/asset_management_core.cob \
    cobol/src/sla_tracker_core.cob \
    cobol/src/report_schedule_core.cob \
    cobol/src/notification_template_core.cob \
    cobol/src/deposit_core.cob \
    cobol/src/card_core.cob \
    cobol/src/import_core.cob \
    cobol/src/import_post_core.cob \
    cobol/src/fee_core.cob \
    cobol/src/eod_core.cob \
    cobol/src/statement_core.cob \
    cobol/src/eod_jobs_core.cob \
    cobol/src/ref_ext_core.cob \
    cobol/src/payment_core.cob \
    cobol/src/sql_bridge.c \
    cobol/c_lib/hash_lib.c \
    cobol/c_lib/totp_lib.c \
    cobol/c_lib/settings_lib.c \
    cobol/c_lib/random_lib.c \
    -L/usr/lib/x86_64-linux-gnu -lmysqlclient -lpthread -Wall -Wextra
else
    make -f cobol/Makefile -j"$JOBS" "$@"
fi

if [ -f "$COBOL_BIN" ]; then
    echo "SUCCESS: Binary created at $COBOL_BIN"
    chmod +x "$COBOL_BIN"
else
    echo "ERROR: Compilation failed"
    exit 1
fi

echo "=========================================="
echo "Build completed successfully!"
echo "=========================================="
