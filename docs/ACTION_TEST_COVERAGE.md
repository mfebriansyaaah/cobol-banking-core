# Action Test Coverage — Triage and Burndown

> R0 note: this document is the T-016A discovery spike record and the T-017
> triage sheet. Owner sign-off on the order below is required before T-018
> starts spending it.

## Current picture (2026-11-04, measured)

`node scripts/check_action_test_coverage.mjs --json .`:

| Metric | Value |
| --- | ---: |
| Route actions (denominator) | 2,780 |
| Shell-covered | 2,180 (78.4%) |
| Baseline (uncovered, owned) | 600 |

The denominator was 4,096 before retire waves A/B deleted ~1,300 generated
actions and their tests. Targets below are percentages so they survive
further retirements: **Phase 1 ≥90% (≤278 untested), Phase 2 ≥95%
(≤139 untested).**

| # | Category | Count | Owner | Ticket | Expires |
| --- | ---: | --- | --- | --- | --- |
| 1 | Template `*_UPDATE` gap | 244 | @mfebriansyaaah | T-019 | 2027-03-31 |
| 2 | Inline `app.js` routes | 63 | @mfebriansyaaah | T-022 | 2027-03-31 |
| 3 | Route files with no DB suite | 278 | @mfebriansyaaah | T-020 | 2027-03-31 |
| 4 | Suite exists, does not invoke | 15 | @mfebriansyaaah | T-022 | 2027-03-31 |

Every baseline entry carries `owner/reason/expires/ticket`; the gate fails
on placeholders and on expiry. `reason` mirrors the category; see
`tests/action_test_coverage_baseline.txt`.

## T-016A spike: is a generator viable?

**Decision: GO** for a template-driven transform
(`scripts/generate_domain_tests.mjs`), with a manual queue for exceptions.
Revisit if the first 20 domains show <80% uniformity.

Evidence (all verified, not assumed):

1. **Template suites are mechanically uniform.** Diffing any two
   `tests/db/*_db_tests.sh` shows only names/refs/tables differ
   (e.g. `account_db_tests.sh` vs `cost_center_db_tests.sh`); the 13-assertion
   shape (CREATE → duplicate → GET → LIST → CALC → DELETE/CLOSE → SUMMARY →
   AUDIT → VALIDATE → non-admin) is identical.
2. **COBOL UPDATE paragraphs are uniform where they exist.**
   246 of 304 `*_core.cob` modules implement `ACTION-UPDATE` with the same
   shape (`ALLOW-ADMIN` → `INVALID_INPUT` on empty id → `LOAD-CLEARING` →
   `UPDATE ... SET ... version = version + 1 WHERE id = ? AND version = ?`).
3. **No client-visible conflict path exists.** UPDATE routes carry no version
   field; `LOAD-CLEARING` reads the current version from the DB inside the
   action. A stale-version `ERROR|CONFLICT` cannot be produced through the
   action — concurrent updates are last-writer-wins. Template UPDATE tests
   therefore pin happy-path + validation + audit, not conflicts.
4. **Worked example (ACC, verified live):** `ACC_CREATE` → version 1 →
   `ACC_UPDATE|id|...` → `SUCCESS|ACC_UPDATE`, version 1 → 2, exactly 1
   `UPDATE` audit row; missing id → `ERROR|NOT_FOUND`; non-admin →
   `ERROR|FORBIDDEN`. Fixture cleaned up afterwards.
5. **Exceptions (manual queue, not generated):** 58 modules without
   `ACTION-UPDATE` (auth, backup_drill, dashboard, eod, card, collection,
   deposit, ...); tables without a `version` column (sampled: `deposit`,
   `card`, `collection`, `payment_clearing` lack it, while `account`,
   `cost_center`, `loan`, `treasury_liquidity` have it); richer hand-written
   domains whose suites need extending by hand (card/deposit/loan/
   loan_schedule — the 15 category-4 entries).

Generator input is parsed from the existing suite (prefix, table, ref/name/
type samples, LIST filter, CALC expectation, VALIDATE sample); output is the
UPDATE block (valid update + version bump + audit count + invalid input +
missing id + non-admin). Generated suites must pass unmodified; any domain
needing hand edits goes to the manual queue and counts against the 80% bar.

## Burndown plan (owner sign-off required)

| Milestone | Covered | Untested (max) | How |
| --- | ---: | ---: | --- |
| Baseline (now) | 2,180 (78.4%) | 600 | — |
| End sprint 1 | ≥2,367 (≥85.4%) | ≤413 | Template UPDATE, top money-path domains first |
| G1 (Phase 1) | ≥2,502 (≥90.0%) | ≤278 | Remaining template UPDATE + first route clusters |
| Mid Phase 2 | ≥2,571 (≥92.7%) | ≤209 | Route clusters continue |
| G2 (Phase 2) | ≥2,641 (≥95.0%) | ≤139 | Invariant-adjacent remainder; residue = documented exceptions |

Weekly review: run `--json`, record covered/baseline, review the diff.

## T-018 progress (branch 07, `test/testing-p1-02-update-critical`)

- Batch 1 (20 money-path domains): UPDATE blocks generated + green 18/18
  each; shell-covered 2,180 → 2,200 (79.1%), baseline 600 → 580.
  Category-1 remaining: 224 (244 − 20 done; includes manual-queue
  LSC_UPDATE).
- Assertions are relative (+1 from captured before-values): template suites
  bump version via CALC/CLOSE before the UPDATE block, so absolute values
  coupled the block to suite order (first green run showed uniform 17/18
  with `expected ^2$, got 4`).

- Batch 1, branch 08 (T-019, `test/testing-p1-03-update-remaining`): 28
  domains (financial queue + general spillover) — shell-covered 2,200 →
  2,228 (80.1%), baseline 580 → 552. Category-1 remaining: 196.
  Generator fix in the same batch: audit FK is parsed from the COBOL
  `INSERT INTO <table>_audit (...)` (cost_center uses `cc_id`), never
  guessed; `--verify-db` pins the column. loan_schedule confirmed manual
  queue (non-uniform LSC slots, no id capture).

- Batch 2, branch `test/testing-p1-03-update-batch2`: 30 general domains —
  shell-covered 2,228 → 2,258 (81.2%), baseline 552 → 522. Category-1
  remaining: 166.

- Batch 3, branch `test/testing-p1-03-update-batch3`: 30 general domains
  (O–P) — shell-covered 2,258 → 2,288 (82.3%), baseline 522 → 492.
  Category-1 remaining: 136.

- Batch 4, branch `test/testing-p1-03-update-batch4`: 30 general domains
  (P–R) — shell-covered 2,288 → 2,318 (83.4%), baseline 492 → 462.
  Category-1 remaining: 106.

- Batch 5, branch `test/testing-p1-03-update-batch5`: 30 general domains
  (R–S) — shell-covered 2,318 → 2,348 (84.5%), baseline 462 → 432.
  Category-1 remaining: 76.

## Domain groups

- **Critical money path** (two approvals): wallet, auth, payments, treasury,
  GL, settlement. UPDATE tests here first (T-018).
- **Financial domains** (depth: invariants + UPDATE): loan, deposit, card,
  collection.
- **Other/synthetic**: remaining template domains, batched (T-019).

## Sign-off

- [ ] Triage order approved by: ____________________ Date: __________
- [ ] Generator approach approved (or risk-based fallback invoked): __________ Date: __________
