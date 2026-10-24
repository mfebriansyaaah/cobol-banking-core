#!/bin/bash
# Build Script for COBOL MySQL Backend (Simulated DB Executable)
# Usage: ./build.sh

set -e

COBOL_BIN="cobol/bin/main_logic"
# Optimisation level is overridable so the CI gate can build with -O0
# (~13s) instead of -O2 (~78s). The resulting binary is behaviourally
# identical; only compile time and generated code differ.
COBOL_OPT="${COBOL_OPT:--O2}"

echo "=========================================="
echo "  Building COBOL MySQL Backend (SIM)"
echo "=========================================="

mkdir -p cobol/bin

# Compile and link the curated modules and the C bridge.
cobc -free -x "$COBOL_OPT" -o "$COBOL_BIN" \
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
    cobol/src/export_stream_core.cob \
    cobol/src/alert_escalation_core.cob \
    cobol/src/audit_drilldown_core.cob \
    cobol/src/compliance_export_core.cob \
    cobol/src/payment_hold_core.cob \
    cobol/src/oncall_delivery_core.cob \
    cobol/src/compliance_retention_core.cob \
    cobol/src/report_scheduler_core.cob \
    cobol/src/audit_snapshot_core.cob \
    cobol/src/report_archive_core.cob \
    cobol/src/kyc_review_core.cob \
    cobol/src/regulatory_report_core.cob \
    cobol/src/loan_core.cob \
    cobol/src/deposit_core.cob \
    cobol/src/fx_deal_core.cob \
    cobol/src/treasury_position_core.cob \
    cobol/src/card_core.cob \
    cobol/src/tax_report_core.cob \
    cobol/src/gl_reval_core.cob \
    cobol/src/gl_period_close_core.cob \
    cobol/src/fraud_ops_core.cob \
    cobol/src/lbpue_core.cob \
    cobol/src/fee_waiver_core.cob \
    cobol/src/limit_profile_core.cob \
    cobol/src/sanctions_hold_core.cob \
    cobol/src/risk_screening_core.cob \
    cobol/src/vendor_core.cob \
    cobol/src/vendor_risk_core.cob \
    cobol/src/asset_maintenance_core.cob \
    cobol/src/asset_core.cob \
    cobol/src/policy_attestation_core.cob \
    cobol/src/regulatory_calendar_core.cob \
    cobol/src/budget_core.cob \
    cobol/src/procurement_core.cob \
    cobol/src/settlement_recon_core.cob \
    cobol/src/statement_delivery_core.cob \
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
    cobol/src/legal_hold_core.cob \
    cobol/src/key_rotation_core.cob \
    cobol/src/dsar_core.cob \
    cobol/src/retention_job_core.cob \
    cobol/src/slo_report_core.cob \
    cobol/src/pipeline_alert_core.cob \
    cobol/src/incident_core.cob \
    cobol/src/change_control_core.cob \
    cobol/src/backup_restore_core.cob \
    cobol/src/secret_rotation_core.cob \
    cobol/src/disaster_recovery_core.cob \
    cobol/src/capacity_plan_core.cob \
    cobol/src/audit_retention_core.cob \
    cobol/src/compliance_audit_core.cob \
    cobol/src/vendor_compliance_core.cob \
    cobol/src/sql_bridge.c \
    cobol/c_lib/hash_lib.c \
    cobol/c_lib/totp_lib.c \
    cobol/c_lib/settings_lib.c \
    cobol/c_lib/random_lib.c \
    -L/usr/lib/x86_64-linux-gnu -lmysqlclient -Wall -Wextra

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
