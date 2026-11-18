#!/usr/bin/env bash
# Build a sanitized mirror of this repository for dataset distribution.
#
# The worktree export (`scripts/export_dataset.sh`) uses `git archive` and
# therefore has no history. This script covers the other case: a consumer asks
# for `.git` or a mirror. It clones the repository, rewrites every author and
# committer email through a generic `Contributor` mailmap, and verifies that
# no non-noreply address remains. The source repository is never modified.
#
# Usage: scripts/sanitize_dataset_history.sh [--out DIR]
#   default out: /tmp/opencode/cobol-export.git
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${TMPDIR:-/tmp}/opencode/cobol-export.git"
while [ "$#" -gt 0 ]; do
    case "$1" in
        --out) OUT="${2:-}"; shift 2 ;;
        -h|--help) sed -n '2,12p' "$0" | sed 's/^# \?//'; exit 0 ;;
        *) echo "usage: $0 [--out DIR]" >&2; exit 2 ;;
    esac
done
[ -n "$OUT" ] || { echo "missing --out value" >&2; exit 2; }
command -v git-filter-repo >/dev/null 2>&1 || {
    echo "FAIL: git-filter-repo not found (pip install git-filter-repo)" >&2
    exit 2
}
case "$OUT" in
    "$ROOT"|"$ROOT"/*) echo "FAIL: --out must be outside the source repository" >&2; exit 2 ;;
esac
[ ! -e "$OUT" ] || { echo "FAIL: $OUT already exists; remove it deliberately first" >&2; exit 2; }

MAILMAP="$(mktemp "${TMPDIR:-/tmp}/cobol-mailmap.XXXXXX")"
trap 'rm -f "$MAILMAP"' EXIT

echo "=== clone mirror: $OUT ==="
git clone --mirror "$ROOT" "$OUT" >/dev/null

echo "=== build generic mailmap ==="
git -C "$OUT" log --all --format='%ae' \
    | sort -u \
    | grep -v 'users.noreply.github.com' \
    | grep -v '^$' \
    | while IFS= read -r email; do
        printf 'Contributor <contributor@users.noreply.github.com> <%s>\n' "$email"
    done > "$MAILMAP"

if [ -s "$MAILMAP" ]; then
    echo "=== rewrite history (author/committer emails and names) ==="
    git -C "$OUT" filter-repo --mailmap "$MAILMAP" --force >/dev/null
else
    echo "no non-noreply addresses found; nothing to rewrite"
fi

echo "=== verify ==="
bad="$(git -C "$OUT" log --all --format='%ae' | grep -v 'users.noreply.github.com' | grep -v '^$' || true)"
if [ -n "$bad" ]; then
    echo "FAIL: sanitized mirror still contains personal emails:" >&2
    printf '%s\n' "$bad" >&2
    exit 1
fi
git -C "$OUT" fsck --no-dangling >/dev/null
echo "OK: sanitized mirror $OUT (only @users.noreply.github.com addresses)"
echo "verify: git -C \"$OUT\" log --all --format='%ae' | sort -u"
