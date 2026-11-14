// Unit tests for scripts/ci/coverage_summary.mjs. No database, no build.
//
// The COBOL total is floor-only: tests/coverage_baseline.txt carries no
// cobol_total key (per-module ratchet in tests/coverage_module_baseline.txt
// is the binding check; the mapper cannot attribute copybook lines back to
// hosts, so a total-vs-baseline ratchet measures the mapper, not coverage).
import { test, after } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const GATE = path.join(ROOT, 'scripts', 'ci', 'coverage_summary.mjs');

const dirs = [];
after(() => {
  for (const d of dirs) rmSync(d, { recursive: true, force: true });
});

function makeRoot({ withTotal = false } = {}) {
  const d = mkdtempSync(path.join(tmpdir(), 'covsum-'));
  dirs.push(d);
  mkdirSync(path.join(d, 'tests'), { recursive: true });
  mkdirSync(path.join(d, 'coverage'), { recursive: true });
  const baseline = ['# header', 'gateway_lines 97.89', 'gateway_branches 82.75'];
  if (withTotal) baseline.push('cobol_total 54.92');
  writeFileSync(path.join(d, 'tests', 'coverage_baseline.txt'), `${baseline.join('\n')}\n`);
  writeFileSync(path.join(d, 'tests', 'coverage_module_baseline.txt'), 'mod_a 80.00\nmod_b 50.00\n');
  writeFileSync(
    path.join(d, 'coverage', 'cobol.json'),
    JSON.stringify({
      percent: 60.0,
      covered: 600,
      executable: 1000,
      modules: [
        { module: 'mod_a', percent: 80.0, covered: 80, executable: 100 },
        { module: 'mod_b', percent: 40.0, covered: 40, executable: 100 },
      ],
    }),
  );
  writeFileSync(
    path.join(d, 'coverage', 'summary.json'),
    JSON.stringify({
      cobol: { percent: 60.0, covered: 600, executable: 1000 },
      gateway: { lines: 99, branches: 85, functions: 90 },
    }),
  );
  return d;
}

function run(root) {
  // GITHUB_STEP_SUMMARY must not leak in: when set (as on CI runners) the
  // script writes there instead of stdout, which would make assertions on
  // captured output vacuous.
  const env = { ...process.env, COVERAGE_SUMMARY_JSON: 'coverage/summary.json' };
  delete env.GITHUB_STEP_SUMMARY;
  return execFileSync(process.execPath, [GATE], { cwd: root, encoding: 'utf8', env });
}

test('renders a floor-only COBOL row when the baseline has no total', () => {
  const out = run(makeRoot());
  assert.doesNotMatch(out, /NaN/, 'no NaN without a total baseline');
  assert.match(out, /floor 30%/, 'total row keeps the floor');
  assert.doesNotMatch(out, /baseline NaN/, 'no phantom baseline');
});

test('lists modules below their baseline', () => {
  const out = run(makeRoot());
  assert.match(out, /mod_b/, 'dropped module is named');
});
