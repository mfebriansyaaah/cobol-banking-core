# Dataset history sanitization

`scripts/export_dataset.sh` exports tracked source through `git archive`; the
result has no `.git` and therefore no author metadata. If a consumer explicitly
needs a mirror (or `.git`), do **not** hand over the primary repository: build a
sanitized mirror with `scripts/sanitize_dataset_history.sh`.

```sh
# Requires git-filter-repo (pip install git-filter-repo)
scripts/sanitize_dataset_history.sh --out /tmp/opencode/cobol-export.git

# Verify
git -C /tmp/opencode/cobol-export.git log --all --format='%ae' | sort -u
```

The script:

1. clones the repository as a mirror (the source repo is untouched);
2. builds a mailmap that replaces every non-`users.noreply.github.com` author
   and committer with `Contributor <contributor@users.noreply.github.com>`;
3. rewrites history with `git filter-repo`;
4. fails if any personal email remains and runs `git fsck`.

Do not force-push a sanitized mirror over the upstream repository. Keep the
mirror with the dataset release, record its commit in
`DATASET_INFO.json`, and include the `SHA256SUMS` produced by the normal export
workflow. The worktree export remains the default profile.
