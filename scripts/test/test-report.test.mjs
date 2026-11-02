// Unit tests for scripts/test-report.mjs. No database, no build.
import { test, after } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, rmSync, writeFileSync, readFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const REP = path.join(ROOT, 'scripts', 'test-report.mjs');

const dirs = [];
after(() => {
  for (const d of dirs) rmSync(d, { recursive: true, force: true });
});

function dirWithTsv(rows) {
  const d = mkdtempSync(path.join(tmpdir(), 'test-report-'));
  dirs.push(d);
  const tsv = ['suite\tstatus\tpass\tfail\ttotal\tduration_ms\tshard', ...rows].join('\n') + '\n';
  writeFileSync(path.join(d, 'report.tsv'), tsv);
  return d;
}

function run(args, reportDir) {
  return execFileSync(process.execPath, [REP, '--report-dir', reportDir, ...args], {
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'pipe'],
  });
}

function runFail(args, reportDir) {
  try {
    execFileSync(process.execPath, [REP, '--report-dir', reportDir, ...args], {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'pipe'],
    });
  } catch (e) {
    return String((e && e.stderr) || e);
  }
  assert.fail(`expected failure for ${args.join(' ')}`);
  return '';
}

test('valid TSV aggregates totals and slowest suites', () => {
  const d = dirWithTsv(['a.sh\tpass\t10\t0\t10\t100\tserial', 'b.sh\tfail\t3\t2\t5\t900\tshard-0']);
  const out = run([], d);
  assert.match(out, /suites=2 passed=1 failed=1 missing=0/);
  assert.match(out, /assertions: pass=13 fail=2 total=15 \(1000ms\)/);
  assert.match(out, /slowest: b\.sh 900ms/);
  const jsonPath = path.join(d, 'out.json');
  run(['--json', jsonPath], d);
  const s = JSON.parse(readFileSync(jsonPath, 'utf8'));
  assert.equal(s.totals.total, 15);
  assert.equal(s.suites.length, 2);
  assert.equal(s.suites[1].status, 'fail');
});

test('--check passes on a report with suites', () => {
  const d = dirWithTsv(['a.sh\tpass\t1\t0\t1\t5\tserial']);
  run(['--check'], d); // throws on failure
});

test('--check fails on header-only and missing reports', () => {
  const empty = dirWithTsv([]);
  const err1 = runFail(['--check'], empty);
  assert.match(err1, /zero suites/);
  const missing = path.join(tmpdir(), `no-such-dir-${Date.now()}`);
  const err2 = runFail(['--check'], missing);
  assert.match(err2, /missing/);
});

test('malformed rows fail with a clear message', () => {
  const d = dirWithTsv(['a.sh\tpass\t10\t0\t10\t100']); // 6 cols, want 7
  assert.match(runFail([], d), /malformed row/);
});

test('non-numeric counters fail', () => {
  const d = dirWithTsv(['a.sh\tpass\tten\t0\t10\t100\tserial']);
  assert.match(runFail([], d), /non-numeric/);
});

test('unknown status fails', () => {
  const d = dirWithTsv(['a.sh\tweird\t1\t0\t1\t5\tserial']);
  assert.match(runFail([], d), /unknown status/);
});

test('suite names with tabs are already sanitized upstream; parser is strict', () => {
  const d = dirWithTsv(['a\tb\tpass\t1\t0\t1\t5\tserial']); // 8 cols
  assert.match(runFail([], d), /malformed row/);
});
