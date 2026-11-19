// Unit tests for scripts/ci/ci_weekly_report.mjs (Phase 4).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { evaluateSLO, fmtPct, renderMarkdown, scheduledStats } from '../ci/ci_weekly_report.mjs';

const REPO_ROOT = path.resolve(path.dirname(new URL(import.meta.url).pathname), '..', '..');

const goodPr = {
  runs: 20,
  wall_clock_p50_sec: 500,
  wall_clock_p50_human: '8m 20s',
  job_minutes_p50: 26,
  failure_rate_pct: 10,
  primary_failure_rate_pct: 10,
  cascaded_failures: 0,
  primary_failed_jobs: {},
};
const goodPush = {
  runs: 17,
  failure_rate_pct: 0,
  primary_failure_rate_pct: 0,
  cascaded_failures: 0,
};
const goodSched = { total: 20, success: 19, pct: 95 };

test('scheduledStats ignores in-progress runs and handles empty', () => {
  assert.deepEqual(scheduledStats([]), { total: 0, success: 0, pct: null });
  const stats = scheduledStats([{ conclusion: 'success' }, { conclusion: 'failure' }, { conclusion: null }, {}]);
  assert.equal(stats.total, 2);
  assert.equal(stats.success, 1);
  assert.equal(stats.pct, 50);
});

test('fmtPct handles n/a', () => {
  assert.equal(fmtPct(null), 'n/a');
  assert.equal(fmtPct(95), '95.0%');
});

test('all-green evaluates PASS', () => {
  const evaluated = evaluateSLO({
    pr: goodPr,
    push: goodPush,
    nightly: goodSched,
    coverage: goodSched,
    mutation: { total: 10, success: 9, pct: 90 },
  });
  assert.equal(evaluated.overall, 'PASS');
  assert.deepEqual(evaluated.reasons, []);
});

test('PR failure rate breach evaluates FAIL', () => {
  const evaluated = evaluateSLO({
    pr: { ...goodPr, failure_rate_pct: 40 },
    push: goodPush,
    nightly: goodSched,
    coverage: goodSched,
    mutation: goodSched,
  });
  assert.equal(evaluated.overall, 'FAIL');
  assert.match(evaluated.reasons.join('; '), /PR failure rate/);
});

test('small samples warn instead of failing', () => {
  const evaluated = evaluateSLO({
    pr: { ...goodPr, runs: 3 },
    push: { ...goodPush, runs: 2 },
    nightly: { total: 2, success: 2, pct: 100 },
    coverage: { total: 0, success: 0, pct: null },
    mutation: { total: 1, success: 1, pct: 100 },
  });
  assert.equal(evaluated.overall, 'WARN');
  assert.match(evaluated.reasons.join('; '), /LOW SAMPLE/);
});

test('cascaded failures evaluate FAIL', () => {
  const evaluated = evaluateSLO({
    pr: { ...goodPr, cascaded_failures: 2, primary_failure_rate_pct: 30, failure_rate_pct: 35 },
    push: goodPush,
    nightly: goodSched,
    coverage: goodSched,
    mutation: goodSched,
  });
  assert.equal(evaluated.overall, 'FAIL');
  assert.match(evaluated.reasons.join('; '), /cascaded/);
});

test('rendered markdown puts Status before tables', () => {
  const evaluated = evaluateSLO({
    pr: goodPr,
    push: goodPush,
    nightly: goodSched,
    coverage: goodSched,
    mutation: goodSched,
  });
  const text = renderMarkdown({
    pr: goodPr,
    push: goodPush,
    nightly: goodSched,
    coverage: goodSched,
    mutation: goodSched,
    evaluated,
    generatedAt: '2026-11-19T00:00:00.000Z',
  });
  const statusIdx = text.indexOf('## Status');
  assert.ok(statusIdx >= 0, 'missing ## Status');
  assert.ok(text.includes('- Overall: PASS'), 'missing Overall');
  assert.ok(statusIdx < text.indexOf('## SLO checks'), 'Status must come first');
});

test('CLI renders report from JSON files', () => {
  const dir = mkdtempSync(path.join(tmpdir(), 'ci-weekly-'));
  const prFile = path.join(dir, 'pr.json');
  const pushFile = path.join(dir, 'push.json');
  const nightlyFile = path.join(dir, 'nightly.json');
  const coverageFile = path.join(dir, 'coverage.json');
  const mutationFile = path.join(dir, 'mutation.json');
  const outFile = path.join(dir, 'summary.md');
  writeFileSync(prFile, JSON.stringify(goodPr));
  writeFileSync(pushFile, JSON.stringify(goodPush));
  const runs = (n, ok) =>
    JSON.stringify(Array.from({ length: n }, (_, i) => ({ conclusion: i < ok ? 'success' : 'failure' })));
  writeFileSync(nightlyFile, runs(20, 19));
  writeFileSync(coverageFile, runs(20, 19));
  writeFileSync(mutationFile, runs(10, 9));
  const stdout = execFileSync(
    process.execPath,
    [
      path.join(REPO_ROOT, 'scripts', 'ci', 'ci_weekly_report.mjs'),
      '--pr',
      prFile,
      '--push',
      pushFile,
      '--nightly',
      nightlyFile,
      '--coverage',
      coverageFile,
      '--mutation',
      mutationFile,
      '--out',
      outFile,
    ],
    { encoding: 'utf8', timeout: 60000 },
  );
  assert.match(stdout, /## Status/);
  assert.match(stdout, /- Overall: PASS/);
});
