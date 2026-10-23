#!/bin/bash
# Static COBOL checks shared by the full CI and the fast PR gate.
# Fails on: a sentence period inside an inline IF, GOBACK outside the entry
# paragraph, a routing literal that is a prefix of another, a routed action
# with no owning handler, a users(email) FK without ON UPDATE CASCADE, a
# routed action unreachable through the gateway, and a syntax error in the
# shell tooling added for the tiered gate.
set -e
cd "$(dirname "$0")/.."
viol=0

# Violation 1: sentence period inside an inline IF/ELSE scope.
# Paragraph headers (line that is nothing but an identifier ending in '.')
# reset the IF depth. Covers every module actually compiled by build.sh.
BUILT_COB="cobol/src/main_logic.cob cobol/src/user_core.cob cobol/src/wallet_core.cob cobol/src/auth_core.cob cobol/src/ref_engine.cob cobol/src/gl_core.cob cobol/src/generated/ref_core.cob"
for f in $BUILT_COB; do
    awk '
        /^[[:space:]]*[A-Z0-9][A-Z0-9-]*\.[[:space:]]*$/ {ifdepth=0; next}
        /^[[:space:]]*\*>/ {next}
        /^[[:space:]]*IF[[:space:]]/ {ifdepth++}
        /^[[:space:]]*END-IF\./ {ifdepth--; if(ifdepth<0) ifdepth=0}
        {line=$0; sub(/[[:space:]]+$/, "", line)}
        ifdepth>0 && line ~ /[.][[:space:]]*$/ && line !~ /END-IF\.|END-STRING\.|END-EVALUATE\.|END-UNSTRING\.|END-PERFORM\.|END-READ\./ {
            print FILENAME ":" NR ": period inside inline IF scope: " line
            found=1
        }
    END {exit found ? 1 : 0}' "$f" || viol=1
done

# Violation 2: GOBACK outside the entry paragraph of any built module
# (GOBACK inside a performed paragraph kills the whole program silently).
for f in $BUILT_COB; do
    if awk '
        /^[[:space:]]*[A-Z0-9][A-Z0-9-]*\.[[:space:]]*$/ {gsub(/[[:space:].]/,""); para=$0; next}
        /GOBACK/ && para != "MAIN-LOGIC" {
            print FILENAME ":" NR ": GOBACK inside paragraph " para
            found=1
        }
        END {exit found ? 1 : 0}' "$f"; then
        :
    else
        viol=1
    fi
done

# Violation 3: one routing literal is a prefix of another. Prefix matching makes
# that a silent mis-route (the CHECK_BALANCE vs GET_BALANCE class of bug).
if awk '
    /IF CMD-ACTION\(1:[0-9]+\) = "-?[A-Z_]+"|ELSE IF CMD-ACTION\(1:[0-9]+\) = "[A-Z_]+"/ {
        line=$0
        while (match(line, /= "[A-Z_]+"/)) {
            lit=substr(line, RSTART+3, RLENGTH-4)
            names[++n]=lit
            line=substr(line, RSTART+RLENGTH)
        }
    }
    END {
        for (i=1; i<=n; i++)
            for (j=1; j<=n; j++)
                if (i != j && index(names[j], names[i]) == 1) {
                    print "router: `" names[i] "` is a prefix of `" names[j] "`"
                    found=1
                }
        exit found ? 1 : 0
    }' cobol/src/main_logic.cob; then
    :
else
    viol=1
fi

# Violation 4: every action the router dispatches must have a handler in the
# owning module (router/owner agreement - the routing contract).
for name in $(grep -oE 'CMD-ACTION\(1:[0-9]+\) = "[A-Z_]+"' cobol/src/main_logic.cob | grep -oE '"[A-Z_]+"' | tr -d '"'); do
    [ "$name" = "REF_" ] && continue
    [ "$name" = "RFE_" ] && continue
    [ "$name" = "GL_" ] && continue
    [ "$name" = "BATCH_" ] && continue
    [ "$name" = "RPT_" ] && continue
    [ "$name" = "IMP_" ] && continue
    [ "$name" = "FEE_" ] && continue
    [ "$name" = "VEL_" ] && continue
    [ "$name" = "EOD_" ] && continue
    [ "$name" = "EODJOB_" ] && continue
    [ "$name" = "STMT_" ] && continue
    [ "$name" = "RX_" ] && continue
    [ "$name" = "NTF_" ] && continue
    [ "$name" = "PAY_" ] && continue
    [ "$name" = "RECON_" ] && continue
    [ "$name" = "IMPP_" ] && continue
    [ "$name" = "RDL_" ] && continue
    [ "$name" = "DSP_" ] && continue
    [ "$name" = "EXP_" ] && continue
    [ "$name" = "RCP_" ] && continue
    [ "$name" = "ALT_" ] && continue
    [ "$name" = "DSH_" ] && continue
    [ "$name" = "SRC_" ] && continue
    [ "$name" = "PIC_" ] && continue
    [ "$name" = "ONC_" ] && continue
    [ "$name" = "AAN_" ] && continue
    [ "$name" = "IRC_" ] && continue
    [ "$name" = "REX_" ] && continue
    [ "$name" = "DSN_" ] && continue
    [ "$name" = "XST_" ] && continue
    [ "$name" = "ALE_" ] && continue
    [ "$name" = "ADR_" ] && continue
    [ "$name" = "CEX_" ] && continue
    [ "$name" = "PHL_" ] && continue
    [ "$name" = "ODL_" ] && continue
    [ "$name" = "CRT_" ] && continue
    [ "$name" = "RSC_" ] && continue
    [ "$name" = "ASN_" ] && continue
    [ "$name" = "RPA_" ] && continue
    [ "$name" = "KYC_" ] && continue
    [ "$name" = "RSK_" ] && continue
    [ "$name" = "REG_" ] && continue
    [ "$name" = "LOAN_" ] && continue
    [ "$name" = "DEP_" ] && continue
    [ "$name" = "FXD_" ] && continue
    [ "$name" = "TRP_" ] && continue
    [ "$name" = "CARD_" ] && continue
    [ "$name" = "TAX_" ] && continue
    [ "$name" = "GRL_" ] && continue
    [ "$name" = "GPC_" ] && continue
    [ "$name" = "FOP_" ] && continue
    [ "$name" = "LBP_" ] && continue
    [ "$name" = "FWV_" ] && continue
    [ "$name" = "LPR_" ] && continue
    [ "$name" = "SHL_" ] && continue
    [ "$name" = "VND_" ] && continue
    [ "$name" = "VRK_" ] && continue
    [ "$name" = "AMT_" ] && continue
    [ "$name" = "AST_" ] && continue
    [ "$name" = "PAT_" ] && continue
    [ "$name" = "RCL_" ] && continue
    [ "$name" = "BUD_" ] && continue
    [ "$name" = "PRC_" ] && continue
    [ "$name" = "STR_" ] && continue
    [ "$name" = "STL_" ] && continue
    [ "$name" = "XST_" ] && continue
    [ "$name" = "ALE_" ] && continue
    if ! grep -q "\"$name\"" cobol/src/wallet_core.cob cobol/src/user_core.cob cobol/src/auth_core.cob cobol/src/ref_engine.cob cobol/src/gl_core.cob cobol/src/batch_core.cob cobol/src/report_core.cob cobol/src/report_delivery_core.cob cobol/src/dispute_ops_core.cob cobol/src/export_archive_core.cob cobol/src/recon_ops_core.cob cobol/src/alert_core.cob cobol/src/dashboard_core.cob cobol/src/statement_recon_core.cob cobol/src/payment_instruction_core.cob cobol/src/oncall_core.cob cobol/src/audit_analytics_core.cob cobol/src/import_recon_core.cob cobol/src/recon_exception_core.cob cobol/src/dispute_notify_core.cob cobol/src/export_stream_core.cob cobol/src/alert_escalation_core.cob cobol/src/audit_drilldown_core.cob cobol/src/compliance_export_core.cob cobol/src/payment_hold_core.cob cobol/src/oncall_delivery_core.cob cobol/src/compliance_retention_core.cob cobol/src/report_scheduler_core.cob cobol/src/settlement_recon_core.cob cobol/src/statement_delivery_core.cob cobol/src/audit_snapshot_core.cob cobol/src/report_archive_core.cob cobol/src/kyc_review_core.cob cobol/src/regulatory_report_core.cob cobol/src/loan_core.cob cobol/src/deposit_core.cob cobol/src/fx_deal_core.cob cobol/src/treasury_position_core.cob cobol/src/card_core.cob cobol/src/tax_report_core.cob cobol/src/policy_attestation_core.cob cobol/src/regulatory_calendar_core.cob cobol/src/budget_core.cob cobol/src/procurement_core.cob cobol/src/import_core.cob cobol/src/import_post_core.cob cobol/src/fee_core.cob cobol/src/eod_core.cob cobol/src/statement_core.cob cobol/src/eod_jobs_core.cob cobol/src/ref_ext_core.cob cobol/src/notification_core.cob cobol/src/payment_core.cob cobol/src/recon_core.cob cobol/src/generated/ref_core.cob; then
        echo "router: action '$name' has no handler in any core module"
        viol=1
    fi
done

# Violation 5: any FK to the mutable users(email) must cascade on UPDATE,
# otherwise changing a user's email fails with errno 1451 (migration 0003).
if grep -n "REFERENCES users(email)" database/schema.sql | grep -v "ON UPDATE CASCADE" | grep -q .; then
    echo "schema: FK to users(email) missing ON UPDATE CASCADE:"
    grep -n "REFERENCES users(email)" database/schema.sql | grep -v "ON UPDATE CASCADE"
    viol=1
fi

# Violation 6: every action the router can dispatch must be reachable through the
# gateway, either as a route (action: 'X') or via an internal invoke('X')
# (PING, session store). Otherwise the feature is unreachable over HTTP.
for name in $(grep -oE 'CMD-ACTION\(1:[0-9]+\) = "[A-Z_]+"' cobol/src/main_logic.cob | grep -oE '"[A-Z_]+"' | tr -d '"'); do
    [ "$name" = "REF_" ] && continue
    [ "$name" = "RFE_" ] && continue
    [ "$name" = "GL_" ] && continue
    [ "$name" = "BATCH_" ] && continue
    [ "$name" = "RPT_" ] && continue
    [ "$name" = "IMP_" ] && continue
    [ "$name" = "FEE_" ] && continue
    [ "$name" = "VEL_" ] && continue
    [ "$name" = "EOD_" ] && continue
    [ "$name" = "EODJOB_" ] && continue
    [ "$name" = "STMT_" ] && continue
    [ "$name" = "RX_" ] && continue
    [ "$name" = "NTF_" ] && continue
    [ "$name" = "PAY_" ] && continue
    [ "$name" = "RECON_" ] && continue
    [ "$name" = "IMPP_" ] && continue
    [ "$name" = "RDL_" ] && continue
    [ "$name" = "DSP_" ] && continue
    [ "$name" = "EXP_" ] && continue
    [ "$name" = "RCP_" ] && continue
    [ "$name" = "ALT_" ] && continue
    [ "$name" = "DSH_" ] && continue
    [ "$name" = "SRC_" ] && continue
    [ "$name" = "PIC_" ] && continue
    [ "$name" = "ONC_" ] && continue
    [ "$name" = "AAN_" ] && continue
    [ "$name" = "IRC_" ] && continue
    [ "$name" = "REX_" ] && continue
    [ "$name" = "DSN_" ] && continue
    [ "$name" = "XST_" ] && continue
    [ "$name" = "ALE_" ] && continue
    [ "$name" = "XST_" ] && continue
    [ "$name" = "ALE_" ] && continue
    [ "$name" = "ADR_" ] && continue
    [ "$name" = "CEX_" ] && continue
    [ "$name" = "PHL_" ] && continue
    [ "$name" = "ODL_" ] && continue
    [ "$name" = "CRT_" ] && continue
    [ "$name" = "RSC_" ] && continue
    [ "$name" = "STR_" ] && continue
    [ "$name" = "STL_" ] && continue
    [ "$name" = "ASN_" ] && continue
    [ "$name" = "RPA_" ] && continue
    [ "$name" = "REG_" ] && continue
    [ "$name" = "LOAN_" ] && continue
    [ "$name" = "DEP_" ] && continue
    [ "$name" = "FXD_" ] && continue
    [ "$name" = "TRP_" ] && continue
    [ "$name" = "CARD_" ] && continue
    [ "$name" = "TAX_" ] && continue
    [ "$name" = "FOP_" ] && continue
    [ "$name" = "LBP_" ] && continue
    [ "$name" = "VND_" ] && continue
    [ "$name" = "AST_" ] && continue
    [ "$name" = "VRK_" ] && continue
    [ "$name" = "AMT_" ] && continue
    [ "$name" = "PAT_" ] && continue
    [ "$name" = "GRL_" ] && continue
    [ "$name" = "GPC_" ] && continue
    [ "$name" = "SHL_" ] && continue
    [ "$name" = "RCL_" ] && continue
    [ "$name" = "KYC_" ] && continue
    [ "$name" = "RSK_" ] && continue
    [ "$name" = "BUD_" ] && continue
    [ "$name" = "PRC_" ] && continue
    [ "$name" = "FWV_" ] && continue
    [ "$name" = "LPR_" ] && continue
    if ! grep -rqE "(action: '$name'|invoke\('$name')" middleware/src; then
        echo "gateway: action '$name' is routed but has no endpoint or internal invoke"
        viol=1
    fi
done

if [ "$viol" = 1 ]; then
    echo "=== Static checks FAILED ==="
    exit 1
fi
echo "OK"

# The tiered-gate scripts are shell; a syntax error there must fail here.
for f in ci-fast.sh tests/static_checks.sh tests/serve_harness.sh tests/coverage_check.sh scripts/coverage_cobol.sh scripts/sync_main.sh scripts/finalize_slice.sh scripts/nightly.sh; do
    bash -n "$f" || { echo "static: shell syntax error in $f"; exit 1; }
done
