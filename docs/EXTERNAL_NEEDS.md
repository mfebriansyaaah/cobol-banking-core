# External Needs — Closing the 5 PARTIAL Gaps

All seven audit gaps have been processed in-repo (PRs #589–#597): 2 fully
closed, 5 honestly PARTIAL. Each PARTIAL remainder needs something outside
this repository — staging infrastructure, production services, or external
people. This document lists exactly what to request, from whom, and what
flips each rubric when it arrives.

## 1. Staging environment (unblocks gaps 2, 4, 6)

Request: one staging host (or namespace) with the production topology in
miniature — gateway + COBOL pool + MariaDB + MinIO + Mailpit-equivalent —
seeded with production-shaped (never production) data, reachable by CI or by
a documented manual procedure.

Unblocks:

- Gap 2 (Reliability): reference-hardware `bench.sh` numbers
  (`PERF_UPDATE=1` on staging, reviewed diff into
  `tests/perf/baseline.json`) + first live canary exercise. Then the login
  ~1.3 s finding becomes a budget decision with real numbers.
- Gap 4 (Data safety): `VAULT_KMS_KEY_ID` pointed at a staging KMS key,
  probe upload asserting SSE-KMS headers, one rotation execution following
  `docs/runbooks/vault-kms.md`.
- Gap 6 (Tier-1 linkage): 063/064 preconditions (backup + restore drill on
  staging, DBA review) can actually be met; until then the deferral stands.

Owner to name: whoever provisions infrastructure. No code change needed —
the harnesses (`bench.sh`, `vault-kms.md`, `restore_drill.sh`) already exist.

## 2. Production KMS key (unblocks gap 4)

Request: one KMS key per environment (staging first, production at launch)
with a least-privilege grant for the vault role, following
`docs/runbooks/vault-kms.md` (provision → deploy key id → verify →
schedule old-key disablement). No re-encryption step exists by design
(per-object key ids, locked by test).

## 3. External penetration test (unblocks gap 5)

Request: one scoped black/grey-box test of the gateway API. Hand the tester
`docs/SECURITY_MODEL.md` (threat model + adversarial-pass log + explicit
residuals: business-logic abuse within valid limits, client-side vectors,
infra layer). A clean report (or remediated findings) flips Security 1→2.

## 4. DBA review slot (unblocks gap 6)

Request: a DBA to review PR-063 (migration squash) and PR-064 (template
table drops) against a staging backup/restore drill. The plan forbids both
without this review; the retirement re-audit (0 dead modules found, all 39
L0/L1 evidenced) is the input pack.

## 5. Second human reviewer (unblocks gap 7)

Request: one more person with merge-review rights. Until then the standing
exception in `docs/GOVERNANCE.md` (expiry 2026-12-04) governs: enforced
code-owner approval + recorded author second pass + green money-path gates.
Note the expiry — if nobody joins by 2026-12-04, the exception must be
renewed or the rubric stays capped deliberately.

## What flips the verdict

Each item above maps to exactly one rubric row. When all five land with
evidence attached, re-run the audit: that is the certification gate, not
another code PR.
