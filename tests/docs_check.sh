#!/bin/bash
# Docs integrity check: every repo path referenced from CODING_STANDARDS.md /
# CODING_STANDARDS.md / SPEC-*.md / docs/adr/*.md must actually exist.
# Guards against docs drifting from code and ADRs.
# Paths described as future/missing must be written WITHOUT backticks.
# Usage: ./tests/docs_check.sh

DOCS="README.md CODING_STANDARDS.md SPEC-auth-identity.md SPEC-user-profile.md SPEC-wallet-core.md SPEC-api-gateway.md docs/adr/0001-invocation-model.md docs/adr/0002-auth-db-stack.md docs/adr/0003-idempotent-transfers.md docs/adr/0004-schema-migrations.md docs/adr/0005-cross-currency-transfers.md docs/adr/0006-token-revocation.md docs/adr/0007-distributed-rate-limiting.md docs/adr/0008-metrics-export.md docs/adr/0009-audit-retention.md docs/adr/0010-worker-pool-invocation.md docs/adr/0011-jwt-hardening.md docs/adr/0012-refresh-family-limits.md docs/adr/0013-admin-role-hierarchy.md docs/adr/0014-last-admin-protection.md docs/adr/0015-audit-actor-attribution.md docs/adr/0016-audit-read-and-retention.md docs/adr/0017-audit-integrity.md docs/adr/0018-privileged-account-hardening.md docs/adr/0019-admin-step-up.md docs/adr/0020-admin-mfa-required.md docs/adr/0021-admin-mfa-enrolment-prompt.md docs/adr/0022-reversal-sender.md docs/adr/0023-ledger-integrity.md docs/adr/0024-ambiguous-account.md docs/adr/0025-observability-errors.md docs/adr/0026-latency-metrics.md docs/adr/0027-readiness-probes.md docs/adr/0028-operational-hardening.md docs/adr/0029-mailer-best-effort.md docs/adr/0030-mailer-subjects.md docs/adr/0031-mailer-readiness.md docs/adr/0032-mailer-sender-config.md docs/adr/0033-rate-limited-probes.md docs/adr/0034-fail-closed-rng.md docs/adr/0035-db-least-privilege.md docs/adr/0036-audit-immutability-and-request-id.md docs/adr/0037-test-coverage-contract.md docs/adr/0038-no-silent-test-skips.md docs/adr/0039-assertion-count-baseline.md docs/adr/0040-test-hygiene.md docs/adr/0041-body-cap-and-trust-proxy.md docs/adr/0042-per-account-abuse-throttles.md docs/adr/0043-failopen-observability.md docs/adr/0044-lockout-model-and-loopback-trust.md docs/adr/0045-c-memory-safety.md docs/adr/0046-bridge-log-redaction.md docs/STATUS.md docs/HISTORY.md"

fail=0
for doc in $DOCS; do
    [ -f "$doc" ] || { echo "MISSING DOC: $doc"; fail=1; continue; }

    paths=$(grep -oE '`[A-Za-z0-9_./-]+\.(cob|c|sh|sql|bat|js|json|md)`' "$doc" | tr -d '`' | sort -u)
    for p in $paths; do
        case "$p" in
            */*) [ -e "$p" ] || { echo "DANGLING PATH in $doc: $p"; fail=1; } ;;
        esac
    done
done

[ "$fail" -eq 0 ] || { echo "docs check FAILED"; exit 1; }
echo "docs check OK"
