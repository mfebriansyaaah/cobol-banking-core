// Unit tests for scripts/select_tests.mjs (P1-9). No database, no build.
// Runs --files mode with cwd set to a temp copy of the committed mini repo,
// so existsSync-based mapping resolves against fixture files, not the repo.
import { test, after } from 'node:test';
import assert from 'node:assert/strict';
import { makeFixtureRoot, cleanupFixture, runGate, parseSelectOutput } from './helpers.mjs';

const roots = [];
after(() => {
  for (const d of roots) cleanupFixture(d);
});

function select(root, ...files) {
  const r = runGate('scripts/select_tests.mjs', ['--files', ...files], { cwd: root });
  assert.equal(r.status, 0, `select_tests failed: ${r.stderr}`);
  return parseSelectOutput(r.stdout);
}

test('COBOL domain module maps to its db suite and case file', () => {
  const root = makeFixtureRoot();
  roots.push(root);
  const s = select(root, 'cobol/src/account_core.cob');
  assert.equal(s.SELECT_MODE, 'selected');
  assert.equal(s.SELECT_DB_SUITES, 'tests/db/account_db_tests.sh');
  assert.equal(s.SELECT_CASE_FILES, 'tests/cobol/cases/account.cases');
});

test('changed db suite re-runs itself plus its domain cases', () => {
  const root = makeFixtureRoot();
  roots.push(root);
  const s = select(root, 'tests/db/loan_db_tests.sh');
  assert.equal(s.SELECT_MODE, 'selected');
  assert.equal(s.SELECT_DB_SUITES, 'tests/db/loan_db_tests.sh');
  assert.equal(s.SELECT_CASE_FILES, 'tests/cobol/cases/loan.cases');
});

test('changed case file re-runs itself plus its domain suite', () => {
  const root = makeFixtureRoot();
  roots.push(root);
  const s = select(root, 'tests/cobol/cases/account.cases');
  assert.equal(s.SELECT_MODE, 'selected');
  assert.equal(s.SELECT_CASE_FILES, 'tests/cobol/cases/account.cases');
  assert.equal(s.SELECT_DB_SUITES, 'tests/db/account_db_tests.sh');
});

test('route file selects the endpoints node suite', () => {
  const root = makeFixtureRoot();
  roots.push(root);
  const s = select(root, 'middleware/src/routes/loan.js');
  assert.equal(s.SELECT_MODE, 'selected');
  assert.equal(s.SELECT_NODE_SUITE, 'endpoints');
  assert.equal(s.SELECT_DB_SUITES, '');
});

test('shared test support escalates to the full node suite', () => {
  const root = makeFixtureRoot();
  roots.push(root);
  const s = select(root, 'middleware/test/support.js');
  assert.equal(s.SELECT_MODE, 'selected');
  assert.equal(s.SELECT_NODE_SUITE, 'full');
});

test('single middleware test file maps to itself as a node file', () => {
  const root = makeFixtureRoot();
  roots.push(root);
  const s = select(root, 'middleware/test/account.test.js');
  assert.equal(s.SELECT_MODE, 'selected');
  assert.equal(s.SELECT_NODE_FILES, 'middleware/test/account.test.js');
});

test('unknown file falls back to a full run with a reason', () => {
  const root = makeFixtureRoot();
  roots.push(root);
  const s = select(root, 'totally/unknown.xyz');
  assert.equal(s.SELECT_MODE, 'full');
  assert.match(s.SELECT_REASON, /no mapping/);
});

test('CI config change falls back to full with a reason', () => {
  const root = makeFixtureRoot();
  roots.push(root);
  const s = select(root, '.github/workflows/ci.yml');
  assert.equal(s.SELECT_MODE, 'full');
  assert.match(s.SELECT_REASON, /CI config/);
});

test('multiple files combine: db suite plus node suite', () => {
  const root = makeFixtureRoot();
  roots.push(root);
  const s = select(root, 'tests/db/account_db_tests.sh', 'middleware/src/routes/loan.js');
  assert.equal(s.SELECT_MODE, 'selected');
  assert.equal(s.SELECT_DB_SUITES, 'tests/db/account_db_tests.sh');
  assert.equal(s.SELECT_NODE_SUITE, 'endpoints');
});

test('empty file list selects nothing (static gates only)', () => {
  const root = makeFixtureRoot();
  roots.push(root);
  const s = select(root);
  assert.equal(s.SELECT_MODE, 'selected');
  assert.equal(s.SELECT_DB_SUITES, '');
  assert.equal(s.SELECT_CASE_FILES, '');
});
