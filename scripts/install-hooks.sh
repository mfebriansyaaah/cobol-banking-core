#!/bin/bash
# Install the repo's tracked hooks into .git/hooks. Run once per clone.
# With --check, verify instead: every tracked hook must match the installed
# copy byte for byte (a drifted or missing hook fails loudly).
set -e
cd "$(git rev-parse --show-toplevel)"

if [ "$1" = "--check" ]; then
    fail=0
    for f in hooks/*; do
        [ -f "$f" ] || continue
        name="$(basename "$f")"
        if ! cmp -s "$f" ".git/hooks/$name"; then
            echo "hook mismatch or missing: $name (run scripts/install-hooks.sh)"
            fail=1
        fi
    done
    [ "$fail" -eq 0 ] && echo "hooks OK"
    exit "$fail"
fi

mkdir -p .git/hooks
for f in hooks/*; do
    [ -f "$f" ] || continue
    name="$(basename "$f")"
    cp "$f" ".git/hooks/$name"
    chmod +x ".git/hooks/$name"
    echo "installed: $name"
done
