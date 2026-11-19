#!/usr/bin/env bash
# Classify changed files for the docs-only fast path (CI-011).
#
# Extracted from the `changes` job in .github/workflows/ci.yml so the logic
# is unit-testable and shared. Behavior is identical to the former inline
# shell: fails safe to full (docs_only=false) on any error.
#
# Input env:
#   EVENT_NAME          github.event_name (pull_request or other)
#   PR_BASE_SHA         github.event.pull_request.base.sha (may be empty)
#   PUSH_BEFORE_SHA     github.event.before (may be empty or all-zero)
#   HAS_CI_FULL_LABEL   true|false (whether the PR carries the ci:full label)
#   GITHUB_OUTPUT       file to append outputs to (required)
#
# Output:
#   appends docs_only=true|false and docker_relevant=true|false to $GITHUB_OUTPUT
# Exit:
#   0 always; any classifier error yields docs_only=false, docker_relevant=true.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT" || exit 0

: "${GITHUB_OUTPUT:?GITHUB_OUTPUT is required}"

fail_full() {
  echo "docs_only=false" >> "$GITHUB_OUTPUT"
  echo "docker_relevant=true" >> "$GITHUB_OUTPUT"
  exit 0
}

if [ "${HAS_CI_FULL_LABEL:-false}" = "true" ]; then
  echo "ci:full label present; forcing full run"
  echo "docs_only=false" >> "$GITHUB_OUTPUT"
  echo "docker_relevant=true" >> "$GITHUB_OUTPUT"
  exit 0
fi
BASE=""
if [ "${EVENT_NAME:-}" = "pull_request" ]; then
  BASE="${PR_BASE_SHA:-}"
else
  BASE="${PUSH_BEFORE_SHA:-}"
fi

if [ -z "$BASE" ] || [ "$BASE" = "0000000000000000000000000000000000000000" ]; then
  BASE="origin/main"
fi

if ! git rev-parse --verify --quiet "$BASE" >/dev/null 2>&1; then
  echo "docs_only=false" >> "$GITHUB_OUTPUT"
  echo "docker_relevant=true" >> "$GITHUB_OUTPUT"
  exit 0
fi

CHANGED="$(git diff --name-only "$BASE"...HEAD 2>/dev/null)" || fail_full
CHANGED="$CHANGED
$(git ls-files --others --exclude-standard 2>/dev/null || true)"

RESULT="$(printf '%s\n' "$CHANGED" \
  | node scripts/ci/classify_changes.mjs --stdin 2>/dev/null)" \
  || RESULT="docs_only=false"
echo "$RESULT" >> "$GITHUB_OUTPUT"
DOCKER="$(printf '%s\n' "$CHANGED" \
  | node scripts/ci/classify_docker.mjs --stdin 2>/dev/null)" \
  || DOCKER="docker_relevant=true"
echo "$DOCKER" >> "$GITHUB_OUTPUT"
