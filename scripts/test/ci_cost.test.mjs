// Unit tests for scripts/ci/ci_cost.mjs (no network: pure helpers only).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { parseCostArgs, renderCostHuman } from '../ci/ci_cost.mjs';

test('parseCostArgs reads days, repo, json, out', () => {
  const a = parseCostArgs(['--days', '7', '--repo', 'o/r', '--json', '--out', 'c.json']);
  assert.equal(a.days, 7);
  assert.equal(a.repo, 'o/r');
  assert.equal(a.json, true);
  assert.equal(a.out, 'c.json');
});

test('parseCostArgs defaults to 30 days', () => {
  const a = parseCostArgs([]);
  assert.equal(a.days, 30);
  assert.equal(a.repo, null);
  assert.equal(a.json, false);
});

test('renderCostHuman lists workflows by cost then total', () => {
  const text = renderCostHuman({
    days: 30,
    since: '2026-10-20',
    runs: 10,
    total_job_minutes: 100,
    by_workflow: { CI: 70, Nightly: 30 },
  });
  assert.match(text, /total: 100 job-min/);
  assert.ok(text.indexOf('CI: 70') < text.indexOf('Nightly: 30'), 'sorted by cost desc');
});
