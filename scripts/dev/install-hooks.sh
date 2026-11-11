#!/usr/bin/env bash
# Install git hooks for local enforcement (R0 00A, T-004/T-054A).
# The repository is private on GitHub Free, so server-side rulesets return
# HTTP 403. Until GitHub Pro/public or a merge bot is approved, these hooks
# are the compensating control. They do not replace required checks.
# Installs: pre-push (gate before push to main) and pre-commit (regen docs
# stats so the docs gate never goes red on COBOL/route changes).
# Usage: scripts/dev/install-hooks.sh [--force]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HOOK="$ROOT/.git/hooks/pre-push"
FORCE=0
if [ "${1:-}" = "--force" ]; then FORCE=1; fi

if [ -e "$HOOK" ] && [ "$FORCE" != "1" ]; then
  echo "pre-push hook already exists: $HOOK (use --force to overwrite)"
  exit 0
fi

cat > "$HOOK" <<'EOF'
#!/usr/bin/env bash
# Local pre-push enforcement. Blocks pushes to main that skip the gate.
# Bypass only with a recorded reason: SKIP_PREMERGE=1 git push
set -uo pipefail
remote="$1"
while read -r _local_sha _local_oid _remote_ref _remote_oid; do
  case "${_remote_ref:-}" in
    refs/heads/main)
      if [ "${SKIP_PREMERGE:-0}" = "1" ]; then
        echo "WARN: SKIP_PREMERGE=1, pushing to main without gate (record reason in PR)" >&2
        mkdir -p artifacts
        echo "$(date -u +%FT%TZ) SKIP_PREMERGE push to main" >> artifacts/premerge-skips.log
        continue
      fi
      echo "=== pre-push: running fast gate before push to main ===" >&2
      if ! bash scripts/ci/premerge.sh >&2; then
        echo "FAIL: pre-push gate red; push to main blocked" >&2
        echo "hint: fix the gate, or push a work branch and open a PR" >&2
        exit 1
      fi
      ;;
  esac
done
exit 0
EOF
chmod +x "$HOOK"
echo "installed $HOOK"
echo "note: server-side ruleset still required for 9/10; see docs/CI.md"

# Pre-commit: regenerate README/docs stats so the docs gate never goes red
# just because a commit touched COBOL/routes. Fast (~1s). The generator is
# deterministic; when it rewrites the stats files they are staged into the
# same commit. Bypass: SKIP_DOCS_STATS=1 git commit.
COMMIT_HOOK="$ROOT/.git/hooks/pre-commit"
cat > "$COMMIT_HOOK" <<'EOF'
#!/usr/bin/env bash
# Local pre-commit: keep generated docs stats in sync (docs gate parity).
# Bypass: SKIP_DOCS_STATS=1 git commit
set -uo pipefail
if [ "${SKIP_DOCS_STATS:-0}" = "1" ]; then
  echo "WARN: SKIP_DOCS_STATS=1, docs stats not regenerated" >&2
  exit 0
fi
if ! command -v node >/dev/null 2>&1; then
  echo "WARN: node not found, skipping docs stats regen (CI docs gate still applies)" >&2
  exit 0
fi
if ! node scripts/docs_stats.mjs --write >&2; then
  echo "FAIL: docs stats regen failed; fix the generator or bypass with SKIP_DOCS_STATS=1" >&2
  exit 1
fi
git add README.md docs/STATUS.md docs/MODULE_INDEX.md 2>/dev/null || true
exit 0
EOF
chmod +x "$COMMIT_HOOK"
echo "installed $COMMIT_HOOK"
