## Summary

<!-- What changed and why? -->

## Scope

- [ ] One concern per PR (no mixed domain wave + refactor + docs)
- [ ] Money path (wallet, auth, payments, treasury, GL, settlement)? If yes, request two approvals.

## Verification

- [ ] `bash scripts/ci/premerge.sh` green
- [ ] `tests/run_all.sh full` green (or explain why CI covers it)
- [ ] Manifest regenerated if modules/routes/dispatch changed
- [ ] No new route conflicts
- [ ] No secrets or real PII added
- [ ] Docs updated if behavior or setup changed

## Risk and rollback

<!-- What can break, and how do we roll back? -->

## Governance exception

<!-- Required only if a rule in docs/GOVERNANCE.md is not met. State reason, risk, compensating control, and approver. -->
