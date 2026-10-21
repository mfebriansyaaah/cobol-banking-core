#!/bin/bash
# Prepare the next slice from merged main.
#
#     ./scripts/sync_main.sh                    # sync main only
#     ./scripts/sync_main.sh phase-1/my-slice   # sync main, then create a branch
#
# The delivery rules require one open PR at a time: merge the previous slice
# before starting the next one. This script refuses a dirty tree, fast-forwards
# main, prunes local branches already merged into main, checks/applies database
# migrations, and creates the named branch. It never creates documentation
# commits and never pushes.
set -euo pipefail
cd "$(dirname "$0")/.."

BRANCH="${1:-}"

if [ -n "$(git status --porcelain)" ]; then
    echo "sync_main: working tree is dirty; commit or stash first." >&2
    git status --short >&2
    exit 1
fi

echo "sync_main: fetching origin"
git fetch origin --prune >/dev/null

git checkout main >/dev/null 2>&1 || { echo "sync_main: cannot switch to main" >&2; exit 1; }
if ! git merge --ff-only origin/main >/dev/null 2>&1; then
    echo "sync_main: local main has diverged from origin/main; resolve it first." >&2
    exit 1
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
        exit 1
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
