// Unit tests for scripts/check_action_test_coverage.mjs. No database, no build.
import { test, after } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, rmSync, writeFileSync, readFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const GATE = path.join(ROOT, 'scripts', 'check_action_test_coverage.mjs');

const dirs = [];
after(() => {
  for (const d of dirs) rmSync(d, { recursive: true, force: true });
});

// Minimal repo tree: 2 route files (one per route-file + app.js), one suite,
// one case file. Route actions: COVERED (suite), TABLED (cases), MISSING,
// APP_ONLY (app.js, uncovered).
function makeRoot({ baselineExtra = [], suiteCalls = ['COVERED'], caseActions = ['TABLED'] } = {}) {
  const d = mkdtempSync(path.join(tmpdir(), 'actcov-'));
  dirs.push(d);
  const routes = path.join(d, 'middleware', 'src', 'routes');
  mkdirSync(routes, { recursive: true });
  writeFileSync(
    path.join(routes, 'demo.js'),
    [
      'export const DEMO_ROUTES = [',
      "  { method: 'get', path: '/demo', action: 'COVERED', fields: [] },",
      "  { method: 'post', path: '/demo', action: 'MISSING', fields: [] },",
      "  { method: 'get', path: '/demo/:id', action: 'TABLED', fields: [] },",
      '];',
      '',
    ].join('\n'),
  );
  writeFileSync(path.join(routes, 'index.js'), 'export const ALL_ROUTES = [];\n');
  writeFileSync(
    path.join(d, 'middleware', 'src', 'app.js'),
    ['export const ROUTES = [', "  { method: 'post', path: '/app', action: 'APP_ONLY', fields: [] },", '];', ''].join(
      '\n',
    ),
  );
  const db = path.join(d, 'tests', 'db');
  mkdirSync(db, { recursive: true });
  writeFileSync(
    path.join(db, 'demo_db_tests.sh'),
    [
      '#!/usr/bin/env bash',
      ...suiteCalls.map((a) => `run_cobol "${a}|x|||||admin@test.com"`),
      'run_cobol "$DYNAMIC"',
      '',
    ].join('\n'),
  );
  const cases = path.join(d, 'tests', 'cobol', 'cases');
  mkdirSync(cases, { recursive: true });
  writeFileSync(
    path.join(cases, 'demo.cases'),
    [...caseActions.map((a) => `name@@SUCCESS\\\\|ok@@${a}|x|||||admin@test.com`), ''].join('\n'),
  );
  writeFileSync(path.join(d, 'tests', 'action_test_coverage_baseline.txt'), [...baselineExtra].join('\n') + '\n');
  return d;
}

function run(root, extra = []) {
  return execFileSync(process.execPath, [GATE, '--root', root, ...extra], {
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'pipe'],
  });
}

function runFail(root, extra = []) {
  try {
    run(root, extra);
  } catch (e) {
    return String((e && e.stderr) || e);
  }
  assert.fail(`expected failure for ${extra.join(' ')}`);
  return '';
}

function runJson(root, extra = []) {
  try {
    const stdout = run(root, ['--json', ...extra]);
    return { json: JSON.parse(stdout), status: 0 };
  } catch (e) {
    return { json: JSON.parse(String((e && e.stdout) || '{}')), status: e?.status ?? 1 };
  }
}

// Baseline entries need owner/reason/expires/ticket metadata (T-021).
const META = 'owner=@tester reason="test entry" expires=2099-01-01 ticket=T-0';
const B = (a, meta = META) => `${a} ${meta}`;

test('matching baseline passes', () => {
  const d = makeRoot({ baselineExtra: [B('MISSING'), B('APP_ONLY')] });
  const out = run(d);
  assert.match(out, /OK: 2 of 4 route actions shell-covered/);
});

test('new untested action fails', () => {
  const d = makeRoot({ baselineExtra: [B('APP_ONLY')] });
  const err = runFail(d);
  assert.match(err, /MISSING/);
  assert.match(err, /demo\.js/);
});

test('stale entry fails', () => {
  const d = makeRoot({ baselineExtra: [B('MISSING'), B('APP_ONLY'), B('COVERED')] });
  assert.match(runFail(d), /now covered/i);
  assert.match(runFail(d), /COVERED/);
});

test('dead entry fails', () => {
  const d = makeRoot({ baselineExtra: [B('MISSING'), B('APP_ONLY'), `${'GONE_ACTION'} ${META}`] });
  assert.match(runFail(d), /GONE_ACTION/);
});

test('--write adds new and drops stale/dead, keeps comments and metadata', () => {
  const d = makeRoot({ baselineExtra: ['# group header', '', B('APP_ONLY'), 'GONE_ACTION', 'COVERED'] });
  run(d, ['--write']);
  const after = readFileSync(path.join(d, 'tests', 'action_test_coverage_baseline.txt'), 'utf8');
  assert.match(after, /^# group header$/m);
  assert.match(after, /^MISSING\s+owner=\?\s+reason=\?\s+expires=\?\s+ticket=\?$/m);
  assert.match(after, /^APP_ONLY owner=@tester/m);
  assert.ok(!after.split('\n').some((l) => l.trim() === 'GONE_ACTION'), 'dead entry removed');
  assert.ok(!after.split('\n').some((l) => l.trim() === 'COVERED'), 'stale entry removed');
  // Placeholders fail until a human fills them in.
  assert.match(runFail(d), /WITHOUT OWNER/);
});

test('dynamic run_cobol calls are ignored, not treated as coverage', () => {
  const d = makeRoot({ baselineExtra: [B('MISSING'), B('APP_ONLY')] });
  const out = run(d);
  assert.match(out, /OK: 2 of 4 route actions shell-covered/);
});

test('malformed baseline line fails', () => {
  const d = makeRoot({ baselineExtra: [B('MISSING'), B('APP_ONLY'), 'lowercase_bad'] });
  assert.match(runFail(d), /malformed/);
});

test('duplicate baseline entries fail', () => {
  const d = makeRoot({ baselineExtra: [B('MISSING'), B('APP_ONLY'), B('MISSING')] });
  assert.match(runFail(d), /duplicate/i);
});

test('entry without metadata fails', () => {
  const d = makeRoot({ baselineExtra: ['MISSING', B('APP_ONLY')] });
  const err = runFail(d);
  assert.match(err, /WITHOUT OWNER/);
  assert.match(err, /MISSING/);
});

test('entry with placeholder metadata fails until filled', () => {
  const d = makeRoot({ baselineExtra: ['MISSING  owner=? reason=? expires=? ticket=?', B('APP_ONLY')] });
  assert.match(runFail(d), /WITHOUT OWNER/);
});

test('expired entry fails', () => {
  const d = makeRoot({
    baselineExtra: ['MISSING  owner=@tester reason="old" expires=2000-01-01 ticket=T-0', B('APP_ONLY')],
  });
  const err = runFail(d);
  assert.match(err, /EXPIRED|past their/i);
  assert.match(err, /MISSING/);
});

test('unknown metadata key fails', () => {
  const d = makeRoot({
    baselineExtra: [`MISSING  owner=@tester reason="r" expires=2099-01-01 ticket=T-0 bogus=1`, B('APP_ONLY')],
  });
  assert.match(runFail(d), /unknown metadata key/);
});

test('--json reports totals and uncovered actions with metadata', () => {
  const d = makeRoot({ baselineExtra: [B('MISSING'), B('APP_ONLY')] });
  const { json, status } = runJson(d);
  assert.equal(status, 0);
  assert.equal(json.total, 4);
  assert.equal(json.covered, 2);
  assert.equal(json.baseline, 2);
  assert.equal(json.uncovered.length, 2);
  const byName = Object.fromEntries(json.uncovered.map((u) => [u.action, u]));
  assert.deepEqual(byName.MISSING.files, ['demo.js']);
  assert.equal(byName.MISSING.owner, '@tester');
  assert.equal(byName.MISSING.ticket, 'T-0');
  assert.equal(byName.APP_ONLY.category, 'ungrouped');
});

test('--json still prints on gate failure', () => {
  const d = makeRoot({ baselineExtra: [B('APP_ONLY')] });
  const { json, status } = runJson(d);
  assert.equal(status, 1);
  assert.equal(json.total, 4);
  assert.ok(json.uncovered.some((u) => u.action === 'MISSING' && u.files.includes('demo.js')));
});
