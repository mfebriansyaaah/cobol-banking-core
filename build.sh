#!/bin/bash
# Build Script for COBOL MySQL Backend (Simulated DB Executable)
# Usage: ./build.sh

set -e

COBOL_BIN="cobol/bin/main_logic"
REF_OBJ="cobol/bin/ref_core.o"

echo "=========================================="
echo "  Building COBOL MySQL Backend (SIM)"
echo "=========================================="

mkdir -p cobol/bin

# The generated reference module is a ~54k-line lab artifact. Compiling it at
# -O2 exhausts the code generator's memory, so it is compiled separately at
# -O0 and linked into the optimized binary. Phase 0/1 splits the module into
# smaller curated modules; see docs/PRODUCTION_GRADE_PLAN.md.
cobc -free -c -O0 -Wall -Wextra -o "$REF_OBJ" \
    cobol/src/generated/ref_core.cob

# Compile and link the curated modules and the C bridge.
cobc -free -x -O2 -o "$COBOL_BIN" \
    cobol/src/main_logic.cob \
    cobol/src/user_core.cob \
    cobol/src/wallet_core.cob \
    cobol/src/auth_core.cob \
    cobol/src/ref_engine.cob \
    cobol/src/gl_core.cob \
    cobol/src/batch_core.cob \
    cobol/src/report_core.cob \
    cobol/src/report_delivery_core.cob \
    cobol/src/dispute_ops_core.cob \
    cobol/src/export_archive_core.cob \
    cobol/src/recon_ops_core.cob \
    cobol/src/alert_core.cob \
    cobol/src/dashboard_core.cob \
    cobol/src/statement_recon_core.cob \
    cobol/src/payment_instruction_core.cob \
    cobol/src/oncall_core.cob \
    cobol/src/audit_analytics_core.cob \
    cobol/src/import_recon_core.cob \
    cobol/src/recon_exception_core.cob \
    cobol/src/dispute_notify_core.cob \
    cobol/src/import_core.cob \
    cobol/src/import_post_core.cob \
    cobol/src/fee_core.cob \
    cobol/src/eod_core.cob \
    cobol/src/statement_core.cob \
    cobol/src/eod_jobs_core.cob \
    cobol/src/ref_ext_core.cob \
    cobol/src/notification_core.cob \
    cobol/src/payment_core.cob \
    cobol/src/recon_core.cob \
    "$REF_OBJ" \
    cobol/src/sql_bridge.c \
    cobol/c_lib/hash_lib.c \
    cobol/c_lib/totp_lib.c \
    cobol/c_lib/settings_lib.c \
    cobol/c_lib/random_lib.c \
    -L/usr/lib/x86_64-linux-gnu -lmysqlclient -Wall -Wextra

rm -f "$REF_OBJ"

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
