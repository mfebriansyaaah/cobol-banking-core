// Unit tests for the coverage suite/module lists (PR-05).
//
// scripts/ci/coverage-suites.txt and scripts/ci/coverage-modules.txt are the
// single source of truth consumed by scripts/ci/coverage.sh (measurement),
// scripts/ci/coverage_trigger.mjs (PR gating), and scripts/ci/impact-plan.mjs
// (selective DB suites). This test pins the wiring: every suite must exist
// under tests/db/, every module under cobol/src/, and coverage.sh must read
// the files instead of a hardcoded copy.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');

function readList(rel) {
  return readFileSync(path.join(ROOT, rel), 'utf8')
    .split('\n')
    .map((s) => s.trim())
    .filter((s) => s && !s.startsWith('#'));
}

test('coverage suites resolve to real DB suite files', () => {
  const suites = readList('scripts/ci/coverage-suites.txt');
  assert.ok(suites.length > 20, 'expected a representative suite list');
  assert.deepEqual([...new Set(suites)], suites, 'no duplicate suites');
  for (const s of suites) {
    const direct = path.join(ROOT, 'tests', 'db', `${s}.sh`);
    const suffixed = path.join(ROOT, 'tests', 'db', `${s}_db_tests.sh`);
    assert.ok(existsSync(direct) || existsSync(suffixed), `suite file missing for ${s}`);
  }
});

test('coverage modules resolve to real COBOL sources', () => {
  const modules = readList('scripts/ci/coverage-modules.txt');
  assert.ok(modules.length > 20, 'expected a curated module list');
  assert.deepEqual([...new Set(modules)], modules, 'no duplicate modules');
  for (const m of modules) {
    assert.ok(existsSync(path.join(ROOT, 'cobol', 'src', `${m}.cob`)), `COBOL source missing for ${m}`);
  }
});

test('coverage.sh reads the lists instead of hardcoding them', () => {
  const src = readFileSync(path.join(ROOT, 'scripts', 'ci', 'coverage.sh'), 'utf8');
  assert.match(src, /coverage-suites\.txt/, 'coverage.sh must read coverage-suites.txt');
  assert.match(src, /coverage-modules\.txt/, 'coverage.sh must read coverage-modules.txt');
  assert.doesNotMatch(src, /CURATED=\(\n/, 'coverage.sh must not hardcode CURATED');
  assert.doesNotMatch(src, /SUITES=\(\n/, 'coverage.sh must not hardcode SUITES');
});
