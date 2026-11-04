#!/usr/bin/env bash
# Install git hooks for local enforcement (R0 00A, T-004/T-054A).
# The repository is private on GitHub Free, so server-side rulesets return
# HTTP 403. Until GitHub Pro/public or a merge bot is approved, this pre-push
# hook is the compensating control. It does not replace required checks.
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
