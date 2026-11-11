// Unit tests for scripts/ci/ci_metrics.mjs (CI-006).
// Deterministic: synthetic run/job data, no network, no gh.
import { test } from 'node:test';
import assert from 'assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { median, jobMinutes, runWallClockSec, summarize, parseNeeds, classifyFailedJobs } from '../ci/ci_metrics.mjs';

const TOOL = new URL('../ci/ci_metrics.mjs', import.meta.url).pathname;
const T0 = Date.parse('2026-11-05T00:00:00Z');
const at = (s) => new Date(T0 + s * 1000).toISOString();
const job = (name, dur, conclusion = 'success') => ({
  name,
  started_at: at(0),
  completed_at: at(dur),
  conclusion,
});

test('median handles odd, even, and empty input', () => {
  assert.equal(median([70, 200, 100]), 100);
  assert.equal(median([70, 200]), 135);
  assert.equal(median([]), null);
});

test('jobMinutes rounds each job up to whole minutes (billing convention)', () => {
  assert.equal(jobMinutes([job('lint', 70), job('build', 61)]), 4);
  assert.equal(jobMinutes([job('lint', 60)]), 1);
  assert.equal(jobMinutes([job('x', 0)]), 0);
  assert.equal(jobMinutes([]), 0);
});

test('runWallClockSec spans first start to last completion', () => {
  const jobs = [
    { ...job('a', 50), started_at: at(10) },
    { ...job('b', 200), started_at: at(0) },
  ];
  assert.equal(runWallClockSec(jobs), 200);
  assert.equal(runWallClockSec([]), null);
});

function sample() {
  return {
    event: 'pull_request',
    runs: [
      { conclusion: 'success', jobs: [job('lint', 70), job('build', 61)] },
      { conclusion: 'success', jobs: [job('lint', 130), job('build', 200)] },
      { conclusion: 'success', jobs: [job('lint', 100)] },
      { conclusion: 'failure', jobs: [job('lint', 40, 'failure')] },
      { conclusion: null, jobs: [] },
    ],
  };
}

test('summarize computes p50 wall, p50 job-min, failure rate, failed jobs', () => {
  const s = summarize(sample());
  assert.equal(s.event, 'pull_request');
  assert.equal(s.successful_runs, 3);
  assert.equal(s.wall_clock_p50_sec, 100);
  assert.equal(s.job_minutes_p50, 4);
  assert.equal(s.failure_rate_pct, 25);
  assert.deepEqual(s.failed_jobs, { lint: 1 });
});

test('summarize on empty data does not crash', () => {
  const s = summarize({ event: 'push', runs: [] });
  assert.equal(s.successful_runs, 0);
  assert.equal(s.wall_clock_p50_sec, null);
  assert.equal(s.job_minutes_p50, null);
  assert.equal(s.failure_rate_pct, 0);
});

test('CLI --runs-json emits the same summary as JSON', () => {
  const dir = mkdtempSync(path.join(tmpdir(), 'ci-metrics-'));
  const file = path.join(dir, 'runs.json');
  writeFileSync(file, JSON.stringify(sample()));
  const out = execFileSync(process.execPath, [TOOL, '--event', 'pull_request', '--runs-json', file, '--json'], {
    encoding: 'utf8',
    timeout: 30000,
  });
  const s = JSON.parse(out);
  assert.equal(s.wall_clock_p50_sec, 100);
  assert.equal(s.job_minutes_p50, 4);
  assert.equal(s.failure_rate_pct, 25);
});

test('parseNeeds reads job ids, display names, and needs without YAML libs', () => {
  const graph = parseNeeds(`
jobs:
  test:
    name: test
    needs: [build, db-snapshot, changes]
    runs-on: ubuntu-latest
  db-aggregate:
    name: db aggregate
    needs: [test, db-shards]
`);
  assert.deepEqual(graph.test, { id: 'test', name: 'test', needs: ['build', 'db-snapshot', 'changes'] });
  assert.equal(graph['db-aggregate'].name, 'db aggregate');
  assert.deepEqual(graph['db-aggregate'].needs, ['test', 'db-shards']);
});

test('classifyFailedJobs separates cascaded failures (direct and transitive)', () => {
  const graph = parseNeeds(`
jobs:
  db-snapshot:
    name: db-snapshot
  test:
    name: test
    needs: [db-snapshot]
  db-shards:
    name: db shard 0
    needs: [db-snapshot]
  db-aggregate:
    name: db aggregate
    needs: [test, db-shards]
  lint:
    name: lint
`);
  const jobs = [
    job('db-snapshot', 40, 'failure'),
    job('test', 40, 'failure'),
    job('db aggregate', 10, 'failure'),
    job('lint', 40, 'failure'),
  ];
  const { primary, cascaded } = classifyFailedJobs(jobs, graph);
  assert.deepEqual(primary.sort(), ['db-snapshot', 'lint']);
  // test and db aggregate both sit downstream of the failed db-snapshot.
  assert.deepEqual(cascaded.sort(), ['db aggregate', 'test']);
});

test('classifyFailedJobs: no graph means every failure is primary (fail-safe)', () => {
  const jobs = [job('test', 40, 'failure'), job('db aggregate', 10, 'failure')];
  const { primary, cascaded } = classifyFailedJobs(jobs, {});
  assert.deepEqual(primary.sort(), ['db aggregate', 'test']);
  assert.deepEqual(cascaded, []);
});

test('summarize reports primary failure rate separately from raw failures', () => {
  const needs = parseNeeds(`
jobs:
  test:
    name: test
  db-aggregate:
    name: db aggregate
    needs: [test]
`);
  const data = {
    event: 'pull_request',
    needs,
    runs: [
      { conclusion: 'success', jobs: [job('test', 100)] },
      // Primary: test itself failed; aggregate is cascade-only.
      { conclusion: 'failure', jobs: [job('test', 40, 'failure'), job('db aggregate', 10, 'failure')] },
      // A lone aggregate failure is PRIMARY: no dependency actually failed,
      // so it cannot be proven a cascade (fail-safe direction).
      { conclusion: 'failure', jobs: [job('db aggregate', 10, 'failure')] },
    ],
  };
  const s = summarize(data);
  assert.equal(s.failure_rate_pct, 66.7);
  assert.equal(s.primary_failure_rate_pct, 66.7);
  assert.deepEqual(s.primary_failed_jobs, { test: 1, 'db aggregate': 1 });
  assert.deepEqual(s.failed_jobs, { test: 1, 'db aggregate': 2 });
  assert.equal(s.cascaded_failures, 1);
});
