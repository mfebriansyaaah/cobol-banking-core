#!/bin/bash
# Bring main up to date before starting the next pull request.
#
# Run this every time you are about to create a branch, or after merging one
# or more PRs:
#
#     ./scripts/sync_main.sh                    # sync main only
#     ./scripts/sync_main.sh feat/my-change     # sync main, then create a branch
#
# It refuses to run on a dirty tree (so local work is never clobbered),
# switches to main, fetches and merges origin/main, regenerates
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
