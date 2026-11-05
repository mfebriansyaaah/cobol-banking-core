# Action Test Coverage — Triage and Burndown

> R0 note: this document is the T-016A discovery spike record and the T-017
> triage sheet. Owner sign-off on the order below is required before T-018
> starts spending it.

## Current picture (2026-11-05, measured)

`node scripts/check_action_test_coverage.mjs --json .`:

| Metric | Value |
| --- | ---: |
| Route actions (denominator) | 527 |
| Shell-covered | 527 (100.0%) |
| Baseline (uncovered, owned) | 0 |

The 2026-11-04 burndown below is closed (historical): retire waves and the
template/cluster work covered every baseline entry, so the four categories
hold zero actions today. Targets below are percentages so they survive
further retirements: **Phase 1 ≥90% (≤52 untested), Phase 2 ≥95%
(≤26 untested).**

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

- Batch 6, branch `test/testing-p1-03-update-batch6`: 30 general domains
  (S–T) — shell-covered 2,348 → 2,378 (85.5%), baseline 432 → 402
  (≤409 target branch 08 TERCAPAI). Category-1 remaining: 46
  (termasuk manual: loan_schedule, tax_management).
- Catatan 90%: sisa cat-1 (±44 generatable) hanya membawa ke ~2.422
  (87,2%). Sisa ~80 aksi ke 2.502 harus dari kategori lain (cat-3/cat-2:
  T-020) — keputusan owner: perpanjang T-019 atau tutup di baseline
  dan lanjut branch 09.

## T-020 progress (branch `test/testing-p1-04-route-clusters`)

- Category-4 done (15/15): loan lifecycle, CARD_CLOSE/LIST,
  DEP_LIST/MATURE/AUDIT, LSC_LIST/DETAIL/SEARCH/HISTORY/DELETE —
  shell-covered 2,378 → 2,393 (86.1%), baseline 402 → 387.
  (Keputusan owner: T-020 dimulai; T-019 ditutup di capaian baseline.)

## T-019 final (branch `test/testing-p1-03-update-final`)

- 30 generated UPDATE blocks (T–V) + 2 manual (loan_schedule,
  tax_management, next branch) — shell-covered 2,407 → 2,437 (87.7%),
  baseline 373 → 343. Category-1: 14 generatable + 2 manual remain.

- Batch 3 (`test/testing-p1-04-route-batch3`): second from-scratch cat-3
  suite — payment_hold lifecycle (reserve/capture/release/expire, 19
  asserts) — shell-covered 2,396 → 2,402 (86.4%), baseline 384 → 378.
  (PHL_GET already covered elsewhere.)

- Batch 4 (`test/testing-p1-04-route-batch4`): third from-scratch cat-3
  suite — velocity cluster (profile/check/record/usage/block, 15
  asserts) — shell-covered 2,402 → 2,407 (86.6%), baseline 378 → 373.
- Prod fix required: `loan_schedule_core.cob` read actions returned
  unprefixed rows (dispatch epilogue clobbered `LS-OUTPUT-BUFFER`);
  1-line copy-back at each of the 4 success exits. LSC_GET/SUMMARY/
  EXPORT/AUDIT share the pattern, still broken — follow-up.

- Batch 2 (`test/testing-p1-04-route-batch2`): first cat-3 suite from
  scratch — treasury_position (OPEN/LIST/SUMMARY/CLOSE, 12 asserts) —
  shell-covered 2,393 → 2,396 (86.2%), baseline 387 → 384.
  (TRP_CLOSE already covered elsewhere.)

## Domain groups

- **Critical money path** (two approvals): wallet, auth, payments, treasury,
  GL, settlement. UPDATE tests here first (T-018).
- **Financial domains** (depth: invariants + UPDATE): loan, deposit, card,
  collection.
- **Other/synthetic**: remaining template domains, batched (T-019).

## Sign-off

- [ ] Triage order approved by: ____________________ Date: __________
- [ ] Generator approach approved (or risk-based fallback invoked): __________ Date: __________
