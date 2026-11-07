## Summary

<!-- What changed and why? -->

## Scope

- [ ] One concern per PR (no mixed domain wave + refactor + docs)
- [ ] Money path (wallet, auth, payments, treasury, GL, settlement)? If yes: code-owner approval + author second pass below + money-path suites green.

## Second pass (money-path PRs only, solo-maintainer rule per docs/GOVERNANCE.md)

<!-- Re-read the full diff after CI is green and record the outcome. Delete if not a money-path PR. -->

- [ ] Second read of the complete diff done after the last push
- [ ] Every money-path invariant touched is covered by an equivalence/mutation suite (name it)
- [ ] No unrelated change smuggled in (scope check)

## Verification

- [ ] `bash scripts/ci/premerge.sh` green
- [ ] `tests/run_all.sh full` green (or explain why CI covers it)
- [ ] Manifest regenerated if modules/routes/dispatch changed
- [ ] No new route conflicts
- [ ] No secrets or real PII added
- [ ] Docs updated if behavior or setup changed
- [ ] `node scripts/check_docs.mjs` green after `node scripts/docs_stats.mjs --write`
- [ ] Required checks green, including `coverage-pr` (COBOL coverage gate)
- [ ] Docs-only PR? Heavy jobs (`db-shards`, `coverage-pr`, `db-aggregate`) are skipped automatically; add the `ci:full` label to force a full run

## Risk and rollback

<!-- What can break, and how do we roll back? -->

## Governance exception

<!-- Required only if a rule in docs/GOVERNANCE.md is not met. State reason, risk, compensating control, and approver. -->
