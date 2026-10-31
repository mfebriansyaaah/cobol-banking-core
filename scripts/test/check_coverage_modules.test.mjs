// Unit tests for scripts/check_coverage_modules.mjs. No database, no build.
import { test, after } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, rmSync, writeFileSync, readFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const GATE = path.join(ROOT, 'scripts', 'check_coverage_modules.mjs');

const dirs = [];
after(() => {
  for (const d of dirs) rmSync(d, { recursive: true, force: true });
});

function makeRoot({ baseline, modules }) {
  const d = mkdtempSync(path.join(tmpdir(), 'covmod-'));
  dirs.push(d);
  writeFileSync(path.join(d, 'baseline.txt'), baseline);
  writeFileSync(path.join(d, 'cobol.json'), JSON.stringify({ modules }));
  return d;
}

function run(root, args) {
  return execFileSync(process.execPath, [GATE, '--json', path.join(root, 'cobol.json'),
    '--baseline', path.join(root, 'baseline.txt'), ...args],
  { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] });
}

function runFail(root, args) {
  try {
    run(root, args);
  } catch (e) {
    return String((e && e.stderr) || e);
  }
  assert.fail(`expected failure for ${args.join(' ')}`);
  return '';
}

const row = (module, percent, executable = 100, covered = 50) =>
  ({ module, executable, covered, percent });

test('matching baseline passes', () => {
  const d = makeRoot({
    baseline: '# floor\nwallet_core 67.60\ngl_core 32.13\n',
    modules: [row('wallet_core', 67.6), row('gl_core', 32.13)],
  });
  assert.match(run(d, []), /OK: 2 module\(s\) at or above baseline/);
});

test('drop beyond tolerance fails', () => {
  const d = makeRoot({
    baseline: 'wallet_core 67.60\n',
    modules: [row('wallet_core', 66.0)],
  });
  assert.match(runFail(d, []), /wallet_core: baseline=67.6% actual=66%/);
});

test('drop within tolerance passes', () => {
  const d = makeRoot({
    baseline: 'wallet_core 67.60\n',
    modules: [row('wallet_core', 67.0)],
  });
  run(d, []); // delta -0.6pp >= -1.0pp
});

test('improvement passes and is reported', () => {
  const d = makeRoot({
    baseline: 'wallet_core 67.60\n',
    modules: [row('wallet_core', 70.0)],
  });
  assert.match(run(d, []), /1 improved/);
});

test('unlisted module fails', () => {
  const d = makeRoot({
    baseline: 'wallet_core 67.60\n',
    modules: [row('wallet_core', 67.6), row('new_core', 10.0)],
  });
  assert.match(runFail(d, []), /new_core/);
});

test('missing measurement fails', () => {
  const d = makeRoot({
    baseline: 'wallet_core 67.60\ngone_core 10.00\n',
    modules: [row('wallet_core', 67.6)],
  });
  assert.match(runFail(d, []), /gone_core/);
});

test('--write updates drifted values and adds new keys', () => {
  const d = makeRoot({
    baseline: '# keep me\nwallet_core 67.60\n',
    modules: [row('wallet_core', 68.0), row('new_core', 10.0)],
  });
  run(d, ['--write']);
  const after = readFileSync(path.join(d, 'baseline.txt'), 'utf8');
  assert.match(after, /^wallet_core 68$/m);
  assert.match(after, /^new_core 10$/m);
  assert.match(after, /^# keep me$/m);
  run(d, []); // green after write
});

test('--write adds new keys to a non-empty baseline (review the diff)', () => {
  const d = makeRoot({ baseline: '# keep\nwallet_core 67.60\n', modules: [row('wallet_core', 67.6), row('new_core', 10.0)] });
  run(d, ['--write']);
  const after = readFileSync(path.join(d, 'baseline.txt'), 'utf8');
  assert.match(after, /^new_core 10$/m);
  run(d, []); // green after write
});

test('non-numeric baseline fails with usage error', () => {
  const d = makeRoot({ baseline: 'wallet_core abc\n', modules: [row('wallet_core', 1)] });
  try {
    run(d, []);
    assert.fail('expected failure');
  } catch (e) {
    assert.equal(e.status, 1);
  }
});
