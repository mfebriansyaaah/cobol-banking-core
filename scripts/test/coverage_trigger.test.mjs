// Unit tests for scripts/ci/coverage_trigger.mjs (CI-004, PR-05 precision).
// Table-driven over both dimensions: every row pins whether a changed path
// requires the gateway coverage gate and whether it requires the curated
// COBOL measurement. No database, no build.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import {
  classifyCoverage,
  shouldMeasureCobol,
  shouldMeasureGateway,
  classifyFile,
  shouldMeasure,
} from '../ci/coverage_trigger.mjs';

const TRIGGER = new URL('../ci/coverage_trigger.mjs', import.meta.url).pathname;

const SUITES = new Set(['loan_db_tests']);
const MODULES = new Set(['loan_core']);
const CTX = { suites: SUITES, modules: MODULES };

// [path, expected gateway, expected cobol]
const CASES = [
  ['docs/CI.md', false, false],
  ['README.md', false, false],
  ['manifest/modules.json', false, false],
  ['manifest/actions.json', false, false],
  ['contracts/actions.yaml', false, false],
  ['contracts/errors.yaml', false, false],
  ['tests/baseline_counts.txt', false, false],
  ['tests/coverage_baseline.txt', false, true],
  ['tests/coverage_floor_backlog.txt', false, true],
  ['.github/workflows/ci.yml', false, false],
  ['.github/actions/db-bootstrap/action.yml', false, false],
  ['scripts/check_docs.mjs', false, false],
  ['scripts/test/select_tests.test.mjs', false, false],
  ['scripts/ci/classify_changes.sh', false, false],
  ['scripts/ci/impact-plan.mjs', false, false],
  ['tests/scripts/test_run_all_cli.sh', false, false],
  ['tests/probes/run_probes.sh', false, false],
  ['middleware/src/routes/account.js', true, true],
  ['middleware/src/app.js', true, false],
  ['middleware/spec/routes.yaml', true, false],
  ['middleware/test/gateway.test.js', true, false],
  ['middleware/test/support.js', true, false],
  ['middleware/package.json', false, false],
  ['tests/gateway/endpoint_smoke.sh', true, false],
  ['tests/lib/db.sh', true, false],
  ['cobol/src/loan_core.cob', false, true],
  ['cobol/src/main_logic.cob', false, true],
  ['cobol/copy/loan-copy.cpy', false, true],
  ['cobol/c_lib/hash_lib.c', false, true],
  ['cobol/src/sql_bridge.c', false, true],
  ['build.sh', false, true],
  ['cobol/Makefile', false, true],
  ['database/schema.sql', false, true],
  ['database/migrations/0999_x.sql', false, true],
  ['tests/cobol/cases/loan.cases', false, true],
  ['tests/cobol/table_runner.sh', false, true],
  ['tests/db/loan_db_tests.sh', false, true],
  ['tests/db/new_domain_db_tests.sh', false, false],
  ['scripts/ci/coverage.sh', false, true],
  ['scripts/ci/coverage_trigger.mjs', false, false],
  ['scripts/coverage/map_cobol.py', false, true],
  ['coverage/cobol.txt', false, false],
  ['input.txt', false, false],
];

for (const [file, gateway, cobol] of CASES) {
  test(`classifyCoverage(${file}) === {gateway:${gateway},cobol:${cobol}}`, () => {
    assert.deepEqual(classifyCoverage(file, CTX), { gateway, cobol });
  });
}

test('suite conditional resolves against the curated set', () => {
  assert.equal(classifyCoverage('tests/db/loan_db_tests.sh', CTX).cobol, true);
  assert.equal(classifyCoverage('tests/db/loan_db_tests.sh', { suites: new Set() }).cobol, false);
  assert.equal(classifyCoverage('tests/db/loan_db_tests.sh').cobol, true);
});

test('case conditional resolves against the curated modules', () => {
  assert.equal(classifyCoverage('tests/cobol/cases/loan.cases', CTX).cobol, true);
  assert.equal(classifyCoverage('tests/cobol/cases/loan.cases', { modules: new Set() }).cobol, false);
});

test('shouldMeasureCobol is true only when a curated input changed', () => {
  assert.equal(shouldMeasureCobol(['docs/CI.md', 'manifest/modules.json'], CTX), false);
  assert.equal(shouldMeasureCobol(['docs/CI.md', 'cobol/src/loan_core.cob'], CTX), true);
  assert.equal(shouldMeasureCobol([], CTX), false);
});

test('shouldMeasureGateway is true only when gateway behavior may change', () => {
  assert.equal(shouldMeasureGateway(['docs/CI.md', 'contracts/actions.yaml'], CTX), false);
  assert.equal(shouldMeasureGateway(['middleware/src/app.js'], CTX), true);
});

test('legacy classifyFile keeps the measure/skip contract', () => {
  assert.equal(classifyFile('cobol/src/loan_core.cob', CTX), 'cobol');
  assert.equal(classifyFile('middleware/src/app.js', CTX), 'gateway');
  assert.equal(classifyFile('docs/CI.md', CTX), null);
  assert.equal(classifyFile('manifest/modules.json', CTX), null);
  assert.equal(classifyFile('contracts/actions.yaml', CTX), null);
  assert.equal(classifyFile('.github/workflows/ci.yml', CTX), null);
  assert.equal(classifyFile('totally/unknown.xyz', CTX), 'unknown');
  // Legacy predicate still measures anything not known-safe.
  assert.equal(shouldMeasure(['middleware/src/app.js'], CTX), true);
  assert.equal(shouldMeasure(['docs/CI.md'], CTX), false);
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

test('CLI exits 0 when COBOL measurement is required, 1 when skipped', () => {
  assert.equal(runTrigger(['middleware/src/routes/account.js']), 0);
  assert.equal(runTrigger(['tests/db/loan_db_tests.sh']), 0);
  assert.equal(runTrigger(['middleware/src/app.js']), 1);
  assert.equal(runTrigger(['docs/CI.md', 'README.md']), 1);
  assert.equal(runTrigger(['manifest/modules.json']), 1);
  assert.equal(runTrigger([]), 1);
});
