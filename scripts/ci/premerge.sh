#!/usr/bin/env bash
# Local pre-merge gate.
#
# GitHub branch protection is active on `main`, so this script is the local
# equivalent of the required checks. Run it on the exact commit you intend
# to merge:
#
#   bash scripts/ci/premerge.sh [--full] [--probes] [--docs] [--all]
#       [--ci-parity]
#
#   --full    also run the slow DB/gateway/full suite locally (CI always does)
#   --probes  also run the gate-detection probes (11 mutations x 14 gates;
#             CI runs them in its build job)
#   --docs    also run the docs gate (CI runs it in its build job)
#   --all     --full --probes --docs together
#   --ci-parity
#             exact CI parity: dedicated throwaway database
#             (cobol_db_premerge), full suite, probes, count/docs/schema/
#             warnings/coverage gates, benchmarks, both drills, full lint +
#             security, offline harnesses. Slow (~1h); this is the gate that
#             must pass before merging a money-path change.
#             Exclusions are documented below and printed by --print-plan:
#             in-job DB sharding instead of the CI matrix, no CodeQL upload,
#             no branch-protection remote state, curated COBOL coverage only
#             with --cobol-coverage (needs GnuCOBOL 3.2).
#   --cobol-coverage
#             also run the curated COBOL coverage measurement inside
#             --ci-parity (fails closed without cobc --coverage support)
#   --print-plan
#             print the --ci-parity steps and exclusions, then exit
#
# The same toggles exist as env vars for CI-style invocation:
# PREMERGE_FULL=1, PREMERGE_PROBES=1, PREMERGE_DOCS=1,
# PREMERGE_CI_PARITY=1, PREMERGE_COBOL_COVERAGE=1, PREMERGE_PRINT_PLAN=1.
# Flags and env vars are equivalent; either one enables the section.
#
# Default (no flags) runs only the fast suite: static gates, build, table
# tests, and smoke. DB/gateway/full, probes, and docs are skipped locally and
# reported as skipped; CI covers them.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

usage() {
    sed -n '2,32p' "$0" | sed 's/^# \?//'
}

FULL=0
PROBES=0
DOCS=0
CI_PARITY=0
COBOL_COVERAGE=0
PRINT_PLAN=0
for _arg in "$@"; do
    case "$_arg" in
        --full) FULL=1 ;;
        --probes) PROBES=1 ;;
        --docs) DOCS=1 ;;
        --all) FULL=1; PROBES=1; DOCS=1 ;;
        --ci-parity) CI_PARITY=1 ;;
        --cobol-coverage) COBOL_COVERAGE=1 ;;
        --print-plan) PRINT_PLAN=1 ;;
        --help|-h) usage; exit 0 ;;
        *) echo "unknown flag: $_arg (see --help)" >&2; exit 2 ;;
    esac
done
[ "${PREMERGE_FULL:-0}" = "1" ] && FULL=1
[ "${PREMERGE_PROBES:-0}" = "1" ] && PROBES=1
[ "${PREMERGE_DOCS:-0}" = "1" ] && DOCS=1
[ "${PREMERGE_CI_PARITY:-0}" = "1" ] && CI_PARITY=1
[ "${PREMERGE_COBOL_COVERAGE:-0}" = "1" ] && COBOL_COVERAGE=1
[ "${PREMERGE_PRINT_PLAN:-0}" = "1" ] && PRINT_PLAN=1

# Exact CI parity gate (T-009). Never touches the developer database:
# everything runs against the dedicated cobol_db_premerge database
# (provisioned below; fails closed with setup instructions when Docker
# or DDL rights are unavailable). PREMERGE_DB_* overrides select the
# instance for non-Compose setups.
run_ci_parity() {
    echo "=== PREMERGE: tool bootstrap check ==="
    need_tool() {
        command -v "$1" >/dev/null 2>&1 || {
            echo "FAIL: $1 not found ($2)" >&2
            exit 2
        }
    }
    need_tool shellcheck "apt install shellcheck (CI pins 0.10.0, see ci.yml)"
    need_tool shfmt "https://github.com/mvdan/sh/releases (CI pins 3.11.0)"
    need_tool actionlint "https://github.com/rhysd/actionlint/releases (CI pins 1.7.7)"
    need_tool yamllint "pip install yamllint==1.38.0"
    need_tool semgrep "pip install semgrep==1.136.0"
    need_tool gitleaks "https://github.com/gitleaks/gitleaks/releases (CI pins 8.28.0)"
    need_tool promtool "prometheus promtool (CI pins 3.3.1)"
    need_tool node "https://nodejs.org (need >= 20)"
    need_tool python3 "system package manager"
    need_tool mysql "mariadb-client package (or mysql-client)"
    need_tool cobc "gnucobol package"
    need_tool cppcheck "apt install cppcheck (strict C gate needs it)"
    if ! node -e 'process.exit(Number(process.versions.node.split(".")[0]) >= 20 ? 0 : 1)' >/dev/null 2>&1; then
        echo "FAIL: node >= 20 required (CI uses node 24)" >&2
        exit 2
    fi
    need_tool flock "util-linux package (Linux-only; without it the run lock warns)"
    echo "tools OK"

    echo "=== PREMERGE: provision dedicated database ==="
    # setup-test-db.sh is idempotent; re-running is safe. It fails closed
    # when Docker/the database is unreachable or DDL rights are missing.
    export DB_HOST="${DB_HOST:-127.0.0.1}"
    export DB_PORT="${DB_PORT:-3307}"
    export DB_NAME="cobol_db_premerge"
    export DB_USER="${DB_USER:-cobol_app}"
    export DB_PASS="${DB_PASS:-cobol_pass}"
    export DB_MIGRATE_USER="${DB_MIGRATE_USER:-cobol_migrate}"
    export DB_MIGRATE_PASS="${DB_MIGRATE_PASS:-cobol_migrate_pass}"
    DB_NAME="$DB_NAME" scripts/dev/setup-test-db.sh

    echo "=== PREMERGE: full suite ==="
    DB_SHARDS=4 tests/run_all.sh full

    echo "=== PREMERGE: gate-detection probes ==="
    tests/probes/run_probes.sh

    echo "=== PREMERGE: assertion counts (strict) ==="
    node scripts/check_test_counts.mjs --report-dir artifacts/latest --strict

    echo "=== PREMERGE: docs gate ==="
    node scripts/check_docs.mjs .

    echo "=== PREMERGE: CI contract ==="
    node scripts/check_ci_contract.mjs .

    echo "=== PREMERGE: schema drift ==="
    bash scripts/check_schema_drift.sh

    echo "=== PREMERGE: build log + warning ratchet ==="
    ./build.sh 2>&1 | tee artifacts/latest/build.log
    scripts/check_warnings.sh artifacts/latest/build.log

    echo "=== PREMERGE: gateway coverage ==="
    bash scripts/ci/coverage.sh --gateway-only

    if [ "$COBOL_COVERAGE" = "1" ]; then
        echo "=== PREMERGE: curated COBOL coverage (opt-in) ==="
        if [ "$(cobc --help 2>&1 | grep -c -- '--coverage')" -eq 0 ]; then
            echo "FAIL: installed cobc has no --coverage support (needs GnuCOBOL 3.2)" >&2
            exit 1
        fi
        bash scripts/ci/coverage.sh --cobol-only --changed origin/main --json
    else
        echo "=== PREMERGE: curated COBOL coverage skipped (opt-in via --cobol-coverage; needs GnuCOBOL 3.2) ==="
    fi

    echo "=== PREMERGE: benchmarks ==="
    bash tests/perf/bench.sh

    echo "=== PREMERGE: migration rollback drill ==="
    ROLLBACK_DRILL_DB=cobol_db_rollback_premerge bash scripts/ci/migration_rollback_drill.sh

    echo "=== PREMERGE: backup and restore drill ==="
    RESTORE_DRILL_DB=cobol_db_restore_premerge bash scripts/ci/backup_restore_drill.sh

    echo "=== PREMERGE: shell lint ==="
    bash scripts/ci/lint.sh

    echo "=== PREMERGE: JS lint + format ==="
    npm run lint
    npm run format:check

    echo "=== PREMERGE: markdown lint ==="
    npm run lint:md

    echo "=== PREMERGE: workflow lint ==="
    actionlint

    echo "=== PREMERGE: YAML lint ==="
    bash scripts/ci/yaml_lint.sh

    echo "=== PREMERGE: strict C ==="
    bash scripts/ci/c_strict.sh

    echo "=== PREMERGE: semgrep ==="
    semgrep --config .semgrep/rules.yml --exclude node_modules \
        --exclude package-lock.json --error middleware scripts

    echo "=== PREMERGE: secret scan ==="
    gitleaks detect --source . --no-git --redact --config .gitleaks.toml

    echo "=== PREMERGE: SAST scan ==="
    bash scripts/ci/sast.sh

    echo "=== PREMERGE: SAST extra scan ==="
    bash scripts/ci/sast_extra.sh

    echo "=== PREMERGE: gate unit tests ==="
    npm run test:scripts

    echo "=== PREMERGE: dependency audit ==="
    npm audit --omit=dev
    npm --prefix middleware audit --omit=dev

    echo "=== PREMERGE: alert rules ==="
    promtool check rules monitoring/prometheus-alerts.yml

    echo "=== PREMERGE: offline safety harness ==="
    bash tests/scripts/run.sh

    echo "=== PREMERGE: coverage mapper unit tests ==="
    python3 scripts/coverage/test_map_cobol.py

    echo "=== PREMERGE: CI PARITY GREEN ==="
}

# What --ci-parity runs, and what it deliberately does not. Reviewers read
# this instead of diffing the function against ci.yml by hand.
print_ci_plan() {
    cat <<'EOF'
--ci-parity runs (in order): tool bootstrap, dedicated database, full suite
(run_all.sh full, in-job DB_SHARDS), gate-detection probes, assertion counts
(--strict), docs gate, CI contract, schema drift, build log + warning
ratchet, gateway coverage, curated COBOL coverage (only with
--cobol-coverage), benchmarks, migration rollback drill, backup and restore
drill, shell lint, JS lint + format, markdown lint, workflow lint
(actionlint), YAML lint, strict C, semgrep, secret scan, SAST + SAST extra,
gate unit tests, dependency audit, alert rules, offline safety harness,
coverage mapper unit tests.
Exclusions vs CI: in-job DB sharding instead of the db-shards matrix (same
planner, one runner); no CodeQL upload (needs GitHub security events —
semgrep/SAST run instead); no branch-protection remote state; curated COBOL
coverage is opt-in (needs GnuCOBOL 3.2 with cobc --coverage).
EOF
}

if [ "$PRINT_PLAN" = "1" ]; then
    print_ci_plan
    exit 0
fi

if [ "$CI_PARITY" = "1" ]; then
    run_ci_parity
    exit 0
fi

# tests/run_all.sh fast runs every static gate except check_docs and the
# runtime count gate (syntax, manifest, route dispatch/conflicts/auth, action
# coverage, bind slots, suite inventory, field order, test helpers, case
# actions) plus build, table tests and smoke, so they are not repeated here.
echo "=== PREMERGE: fast suite (includes static gates) ==="
tests/run_all.sh fast

if [ "$DOCS" = "1" ]; then
    echo "=== PREMERGE: docs gate ==="
    node scripts/check_docs.mjs .
    echo "=== PREMERGE: PR-size policy ==="
    node scripts/check_pr_size_policy.mjs .
else
    echo "=== PREMERGE: docs skipped (CI runs it; pass --docs to run locally) ==="
fi

if [ "$PROBES" = "1" ]; then
    echo "=== PREMERGE: gate-detection probes ==="
    tests/probes/run_probes.sh
else
    echo "=== PREMERGE: probes skipped (CI runs them; pass --probes to run locally) ==="
fi

if [ "$FULL" = "1" ]; then
    echo "=== PREMERGE: full suite ==="
    tests/run_all.sh full
else
    echo "=== PREMERGE: full suite skipped (CI runs it; pass --full to run locally) ==="
fi

echo "=== PREMERGE GREEN ==="

# Machine-readable evidence artifact (PR-074): attach premerge-report.json
# to the PR as merge evidence (branch protection records the approval; this
# records what was verified, on which commit, with which suite depth).
COMMIT="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
cat > premerge-report.json <<EOF
{
  "commit": "$COMMIT",
  "at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "modes": { "docs": "$DOCS", "probes": "$PROBES", "full": "$FULL" },
  "result": "GREEN"
}
EOF
echo "wrote premerge-report.json ($COMMIT)"
