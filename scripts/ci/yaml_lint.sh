#!/usr/bin/env bash
# Shared YAML lint entrypoint (CI-005): one definition for CI and premerge.
# Lints the hand-written YAML that GitHub Actions / Compose idioms touch.
# Usage: bash scripts/ci/yaml_lint.sh (needs yamllint).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT" || exit 1

command -v yamllint >/dev/null 2>&1 || {
    echo "FAIL: yamllint not found (pip install yamllint==1.38.0)" >&2
    exit 2
}

yamllint --strict -c .yamllint .github/workflows/ \
    docker-compose.test.yml monitoring/prometheus-alerts.yml \
    .github/ISSUE_TEMPLATE/config.yml .github/dependabot.yml
