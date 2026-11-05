// Unit tests for scripts/ci/coverage_trigger.mjs (CI-004).
// Table-driven: every row pins whether a changed path triggers the curated
// COBOL coverage measurement. No database, no build.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { classifyFile, shouldMeasure } from '../ci/coverage_trigger.mjs';

const TRIGGER = new URL('../ci/coverage_trigger.mjs', import.meta.url).pathname;

// [changed files, expected shouldMeasure]
const CASES = [
  [['docs/CI.md'], false],
  [['docs/CI.md', 'README.md', 'CHANGELOG.md'], false],
  [['middleware/src/routes/account.js'], true],
  [['middleware/src/app.js'], true],
  [['middleware/test/gateway.test.js'], true],
  [['tests/gateway/endpoint_smoke.sh'], true],
  [['tests/lib/db.sh'], true],
  [['cobol/src/loan_core.cob'], true],
  [['cobol/copy/loan-copy.cpy'], true],
  [['cobol/c_lib/hash_lib.c'], true],
  [['cobol/src/sql_bridge.c'], true],
  [['build.sh'], true],
  [['cobol/Makefile'], true],
  [['database/schema.sql'], true],
  [['database/migrations/0999_x.sql'], true],
  [['tests/cobol/cases/loan.cases'], true],
  [['tests/cobol/table_runner.sh'], true],
  [['tests/db/loan_db_tests.sh'], true],
  [['scripts/ci/coverage.sh'], true],
  [['scripts/ci/coverage_trigger.mjs'], true],
  [['scripts/coverage/map_cobol.py'], true],
  [['tests/coverage_baseline.txt'], true],
  [['coverage/cobol.txt'], false],
  [['coverage/foo'], false],
  [['artifacts/run-all.json'], false],
  [['input.txt'], false],
  [['manifest/modules.json'], false],
  [['scripts/foo.mjs'], true],
  [['.github/workflows/ci.yml'], true],
  [[], false],
  [['docs/CI.md', 'middleware/src/routes/account.js'], true],
];

for (const [files, expected] of CASES) {
  test(`shouldMeasure([${files.join(', ') || '<empty>'}]) === ${expected}`, () => {
    assert.equal(shouldMeasure(files), expected);
  });
}

test('classifyFile returns trigger groups', () => {
  assert.equal(classifyFile('cobol/src/loan_core.cob'), 'cobol');
  assert.equal(classifyFile('build.sh'), 'cobol');
  assert.equal(classifyFile('tests/db/loan_db_tests.sh'), 'data');
  assert.equal(classifyFile('database/schema.sql'), 'data');
  assert.equal(classifyFile('scripts/ci/coverage.sh'), 'measurement');
  assert.equal(classifyFile('middleware/src/routes/account.js'), 'gateway');
  assert.equal(classifyFile('middleware/test/gateway.test.js'), 'gateway');
  assert.equal(classifyFile('tests/lib/db.sh'), 'gateway');
});

test('classifyFile returns null for known-safe paths', () => {
  assert.equal(classifyFile('docs/CI.md'), null);
  assert.equal(classifyFile('README.md'), null);
  assert.equal(classifyFile('coverage/cobol.txt'), null);
  assert.equal(classifyFile('manifest/modules.json'), null);
});

test('classifyFile returns unknown for unrecognized paths (safe default: measure)', () => {
  assert.equal(classifyFile('scripts/foo.mjs'), 'unknown');
  assert.equal(classifyFile('.github/workflows/ci.yml'), 'unknown');
});

function runTrigger(files) {
  try {
    execFileSync(process.execPath, [TRIGGER, ...files], {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'pipe'],
      timeout: 30000,
    });
    return 0;
  } catch (e) {
    return typeof e?.status === 'number' ? e.status : 1;
  }
}

test('CLI exits 0 when triggered, 1 when skipped', () => {
  assert.equal(runTrigger(['middleware/src/routes/account.js']), 0);
  assert.equal(runTrigger(['docs/CI.md', 'README.md']), 1);
  assert.equal(runTrigger([]), 1);
});
