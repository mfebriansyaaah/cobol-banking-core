#!/usr/bin/env bash
# Reproducible dataset export (audit A-06).
# Exports tracked files via `git archive` (never the working tree, so local
# artifacts like backups/, node_modules/ or tests/.dbenv can never leak in).
# Refuses without docs/DATASET_LICENSE_APPROVAL.md (decision D-01).
# Usage: scripts/export_dataset.sh --profile source|verification|full --out DIR
set -euo pipefail

PROFILE=""
OUT=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --profile) PROFILE="${2:-}"; shift 2 ;;
    --out) OUT="${2:-}"; shift 2 ;;
    *) echo "usage: $0 --profile source|verification|full --out DIR" >&2; exit 2 ;;
  esac
done
case "$PROFILE" in source|verification|full) ;; *) echo "bad profile (want source|verification|full)" >&2; exit 2 ;; esac
[ -n "$OUT" ] || { echo "missing --out" >&2; exit 2; }

cd "$(dirname "$0")/.."
ROOT="$(pwd)"
[ -z "$(git status --porcelain)" ] || { echo "FAIL: uncommitted changes (commit or stash first)" >&2; exit 2; }
[ -f docs/DATASET_LICENSE_APPROVAL.md ] || { echo "FAIL: docs/DATASET_LICENSE_APPROVAL.md missing (license gate D-01)" >&2; exit 2; }
# A blank template is not an approval: Approver + Date must be filled.
grep -qE '^- Approver: [^[:space:]]' docs/DATASET_LICENSE_APPROVAL.md || { echo "FAIL: DATASET_LICENSE_APPROVAL.md has no approver (license gate D-01)" >&2; exit 2; }
grep -qE '^- Date.*[0-9]{4}-[0-9]{2}-[0-9]{2}' docs/DATASET_LICENSE_APPROVAL.md || { echo "FAIL: DATASET_LICENSE_APPROVAL.md has no date (license gate D-01)" >&2; exit 2; }

rm -rf "$OUT"
mkdir -p "$OUT"
git archive HEAD | tar -x -C "$OUT"

if [ "$PROFILE" = "source" ]; then
  rm -rf "$OUT/database/migrations/archive"
  rm -f \
    "$OUT/database/schema_full.sql" \
    "$OUT/database/schema_v2.sql" \
    "$OUT/docs/openapi.yaml" \
    "$OUT/contracts/actions.yaml" \
    "$OUT/manifest/actions.json" \
    "$OUT/tests/contracts/route_field_order.json" \
    "$OUT/docs/data_dictionary.md" \
    "$OUT/docs/STATUS.md" \
    "$OUT/docs/MODULE_INDEX.md" \
    "$OUT/docs/COMPLEXITY_BASELINE.md"
fi

COUNT="$(find "$OUT" -type f | wc -l | tr -d ' ')"
cat > "$OUT/DATASET_INFO.json" <<JSON
{
  "commit": "$(git rev-parse HEAD)",
  "generatedAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "profile": "$PROFILE",
  "licenseApproved": true,
  "fileCount": $COUNT
}
JSON

(
  cd "$OUT"
  find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS.tmp
  mv SHA256SUMS.tmp SHA256SUMS
)

gitleaks detect --source "$OUT" --no-git \
  --config "$ROOT/.gitleaks.toml" --redact --no-banner

echo "OK: $OUT ($PROFILE)"
