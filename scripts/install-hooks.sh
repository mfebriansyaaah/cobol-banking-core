#!/bin/bash
# Install the repo's tracked hooks into .git/hooks. Run once per clone.
set -e
cd "$(git rev-parse --show-toplevel)"
mkdir -p .git/hooks
for f in hooks/*; do
    [ -f "$f" ] || continue
    name="$(basename "$f")"
    cp "$f" ".git/hooks/$name"
    chmod +x ".git/hooks/$name"
    echo "installed: $name"
done
