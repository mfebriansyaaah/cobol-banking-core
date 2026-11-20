#!/usr/bin/env bash
# Docs-only lint scope (PR-02): markdown, docs stats, CI docs sync, secrets.
# Runs inside the `lint` job when eff_lint == 'docs'. The full gate fleet
# (shellcheck, ESLint, semgrep, static gates, probes) stays in the full
# steps; this script must stay dependency-light (Node + Python + gitleaks).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
npm run lint:md
node scripts/check_docs.mjs .
node scripts/ci/check_ci_docs.mjs .
gitleaks detect --source . --no-git --redact --config .gitleaks.toml
