#!/usr/bin/env bash
# Open or close the CI health report issue (Phase 4).
#
# Usage: bash scripts/ci/ci_health_issue.sh <summary.md>
# Env: GH_TOKEN, GITHUB_REPOSITORY
# The summary must contain a `## Status` block written by
# scripts/ci/ci_weekly_report.mjs:
#   ## Status
#   - Overall: PASS|WARN|FAIL
#   - Reasons: ...
# Behavior:
#   missing file or unknown Overall -> warning, exit 0;
#   FAIL/WARN -> ensure label exists, comment or create "CI health report";
#   PASS -> close the open issue with "All SLO checks passing".
# Never prints GH_TOKEN. Exit 0 unless gh itself fails.
set -euo pipefail

SUMMARY="${1:?usage: ci_health_issue.sh <summary.md>}"
: "${GH_TOKEN:?GH_TOKEN required}"
: "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY required}"
LABEL="ci-health"
TITLE="CI health report"

if [ ! -f "$SUMMARY" ]; then
  echo "warning: $SUMMARY missing; skipping health issue" >&2
  exit 0
fi

# The label must exist even on the PASS path; otherwise `gh issue list
# --label` fails before we can discover that there is no open issue.
gh label create "$LABEL" --repo "$GITHUB_REPOSITORY" \
  --color FBCA04 --description "Automated CI health report" 2>/dev/null || true

STATUS="$(awk '/^## Status/{f=1;next}/^## /{f=0}f' "$SUMMARY" \
  | sed -n 's/^- Overall: *\([A-Z]*\).*/\1/p' | head -n1)"

case "$STATUS" in
  FAIL|WARN)
    NUMBER="$(gh issue list --repo "$GITHUB_REPOSITORY" --state open \
      --label "$LABEL" --json number,title \
      --jq ".[] | select(.title == \"$TITLE\") | .number" | head -n1)"
    if [ -n "$NUMBER" ]; then
      gh issue comment "$NUMBER" --repo "$GITHUB_REPOSITORY" --body-file "$SUMMARY"
    else
      gh issue create --repo "$GITHUB_REPOSITORY" --title "$TITLE" \
        --label "$LABEL" --body-file "$SUMMARY"
    fi
    ;;
  PASS)
    NUMBER="$(gh issue list --repo "$GITHUB_REPOSITORY" --state open \
      --label "$LABEL" --json number,title \
      --jq ".[] | select(.title == \"$TITLE\") | .number" | head -n1)"
    if [ -n "$NUMBER" ]; then
      gh issue close "$NUMBER" --repo "$GITHUB_REPOSITORY" \
        --comment "All SLO checks passing"
    fi
    ;;
  *)
    echo "warning: no recognized Overall status in $SUMMARY; skipping" >&2
    ;;
esac
