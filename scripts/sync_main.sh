#!/bin/bash
# Bring main up to date before starting the next pull request.
#
# Run this every time you are about to create a branch, or after merging one
# or more PRs:
#
#     ./scripts/sync_main.sh                    # sync main only
#     ./scripts/sync_main.sh feat/my-change     # sync main, then create a branch
#
# It refuses to run on a dirty tree (so local work is never clobbered) and
# while any pull request is still open (the previous PR must be merged or
# closed first; with no GitHub access it falls back to refusing while a local
# branch has commits outside origin/main), switches to main, fetches and
# merges origin/main, regenerates
# docs/HISTORY.md and commits the result locally (never pushes it), prunes
# local branches already merged into main, checks the local database
# migrations, and finally creates the named branch when one is given.
#
# The HISTORY commit is deliberately local: it rides along in the next PR, so
# the documented history is updated by the same change that prompted it.
set -euo pipefail
cd "$(dirname "$0")/.."

BRANCH="${1:-}"

if [ -n "$(git status --porcelain)" ]; then
    echo "sync_main: working tree is dirty; commit or stash first." >&2
    git status --short >&2
    exit 1
fi

git checkout main >/dev/null 2>&1 || { echo "sync_main: cannot switch to main" >&2; exit 1; }

echo "sync_main: fetching origin"
git fetch origin --prune >/dev/null

# Rule: never sync while a pull request is still open. A sync would create a
# local HISTORY commit while the previous PR is unresolved, and the next
# branch would start from a state that PR does not contain. Merge (or close)
# the previous PR first. When `gh` cannot answer (offline, no auth), fall back
# to refusing while any local branch has commits outside origin/main.
gh_ok=1
if command -v gh >/dev/null 2>&1; then
    if ! open_prs="$(gh pr list --state open --limit 100 --json number,headRefName --jq '.[] | "#\(.number) \(.headRefName)"' 2>/dev/null)"; then
        gh_ok=0
    fi
else
    gh_ok=0
fi
if [ "$gh_ok" -eq 1 ] && [ -n "${open_prs:-}" ]; then
    echo "sync_main: refusing to sync while a pull request is open:" >&2
    echo "${open_prs}" | sed 's/^/  /' >&2
    echo "sync_main: merge (or close) the previous PR first." >&2
    exit 1
fi
if [ "$gh_ok" -eq 0 ]; then
    unmerged="$(git branch --no-merged origin/main --format='%(refname:short)' 2>/dev/null | grep -v '^main$' || true)"
    if [ -n "$unmerged" ]; then
        echo "sync_main: cannot confirm open PRs (gh unavailable); local branches not merged into origin/main:" >&2
        echo "$unmerged" | sed 's/^/  /' >&2
        echo "sync_main: merge the previous PR first." >&2
        exit 1
    fi
fi

# Fast-forward when possible (the usual case); fall back to a merge when the
# local main carries a HISTORY commit that has not ridden a PR yet.
if ! git merge --ff-only origin/main >/dev/null 2>&1; then
    echo "sync_main: local main has commits not on origin; merging"
    git merge --no-edit origin/main >/dev/null
fi

echo "sync_main: regenerating docs/HISTORY.md"
./docs/gen_history.sh > docs/HISTORY.md
if ! git diff --quiet -- docs/HISTORY.md; then
    pr="$(git log origin/main -1 --merges --format=%s 2>/dev/null | grep -oE '#[0-9]+' | head -1)"
    git add docs/HISTORY.md
    git commit -S -m "docs: sync HISTORY.md to post-merge state (${pr:-main})" >/dev/null
    echo "sync_main: committed HISTORY sync (${pr:-main}); not pushed"
fi

# Delete local branches already contained in main (the merged PR branches).
while IFS= read -r b; do
    [ "$b" = "main" ] && continue
    [ "$b" = "$BRANCH" ] && continue
    if git merge-base --is-ancestor "$b" main 2>/dev/null; then
        git branch -d "$b" >/dev/null 2>&1 || true
        echo "sync_main: pruned merged branch $b"
    fi
done < <(git for-each-ref --format='%(refname:short)' refs/heads)

if ./database/migrate.sh --check >/dev/null 2>&1; then
    echo "sync_main: database migrations are applied"
else
    echo "sync_main: applying pending migrations"
    if ! ./database/migrate.sh; then
        echo "sync_main: could not apply migrations (is the database running?)" >&2
    fi
fi

if [ -n "$BRANCH" ]; then
    if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
        echo "sync_main: branch '$BRANCH' already exists" >&2
        exit 1
    fi
    git checkout -b "$BRANCH" >/dev/null
    echo "sync_main: main at $(git rev-parse --short main); created and checked out $BRANCH"
else
    echo "sync_main: main at $(git rev-parse --short HEAD); ready to branch"
fi
