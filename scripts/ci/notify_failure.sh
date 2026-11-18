#!/usr/bin/env bash
# Open or close the automated CI failure issue (Phase 3).
#
# Usage: bash scripts/ci/notify_failure.sh <failure|success>
# Env (all required unless noted):
#   GH_TOKEN            token for gh (never printed)
#   GITHUB_REPOSITORY   owner/repo
#   GITHUB_RUN_ID       current run id
#   GITHUB_SERVER_URL   e.g. https://github.com
#   WORKFLOW_NAME       github.workflow
#   EVENT_NAME          github.event_name (optional, defaults to unknown)
#   HEAD_SHA            github.sha (optional, defaults to unknown)
#   FAILED_JOBS         JSON/string describing needs (optional)
#
# Behavior:
#   failure: ensure label ci-failure exists, find the open issue titled
#     "CI failure: <WORKFLOW_NAME>"; comment if exists, create if not.
#   success: close the open issue with a recovery comment, if any.
# Exit 0 on success or when there is nothing to do; exit 1 only when gh
# itself fails (the notify job may go red, but it never gates the main jobs).
set -euo pipefail

STATUS="${1:?usage: notify_failure.sh <failure|success>}"
: "${GH_TOKEN:?GH_TOKEN required}"
: "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY required}"
: "${GITHUB_RUN_ID:?GITHUB_RUN_ID required}"
: "${GITHUB_SERVER_URL:?GITHUB_SERVER_URL required}"
: "${WORKFLOW_NAME:?WORKFLOW_NAME required}"

if ! command -v gh >/dev/null 2>&1; then
  echo "warning: gh not found; skipping CI failure notification" >&2
  exit 0
fi

LABEL="ci-failure"
TITLE="CI failure: ${WORKFLOW_NAME}"
RUN_URL="${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}"

find_open_issue() {
  gh issue list \
    --repo "$GITHUB_REPOSITORY" \
    --state open \
    --label "$LABEL" \
    --json number,title \
    --jq ".[] | select(.title == \"$TITLE\") | .number" \
    | head -n 1
}

case "$STATUS" in
  failure)
    gh label create "$LABEL" \
      --repo "$GITHUB_REPOSITORY" \
      --color B60205 \
      --description "Automated CI failure" 2>/dev/null || true

    NUMBER="$(find_open_issue || true)"
    BODY="$(cat <<EOF
Workflow: **${WORKFLOW_NAME}**
Event: \`${EVENT_NAME:-unknown}\`
Commit: \`${HEAD_SHA:-unknown}\`
Run: ${RUN_URL}

Failed jobs:
~~~json
${FAILED_JOBS:-no data}
~~~

Triage: see docs/runbooks/ci-failure.md.
EOF
)"
    if [ -n "$NUMBER" ]; then
      gh issue comment "$NUMBER" --repo "$GITHUB_REPOSITORY" --body "$BODY"
    else
      gh issue create \
        --repo "$GITHUB_REPOSITORY" \
        --title "$TITLE" \
        --label "$LABEL" \
        --body "$BODY"
    fi
    ;;
  success)
    gh label create "$LABEL" \
      --repo "$GITHUB_REPOSITORY" \
      --color B60205 \
      --description "Automated CI failure" 2>/dev/null || true
    NUMBER="$(find_open_issue || true)"
    if [ -n "$NUMBER" ]; then
      gh issue close "$NUMBER" \
        --repo "$GITHUB_REPOSITORY" \
        --comment "Recovered by run: ${RUN_URL}"
    fi
    ;;
  *)
    echo "unknown status: $STATUS" >&2
    exit 2
    ;;
esac
