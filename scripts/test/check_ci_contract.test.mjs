// Unit tests for scripts/check_ci_contract.mjs (T-006/T-011).
// Fixture repos live in tests/fixtures/ci-contract/ (committed, no DB/build).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import path from 'node:path';
import { runGate, REPO_ROOT } from './helpers.mjs';

const fix = (name) => path.join(REPO_ROOT, 'tests', 'fixtures', 'ci-contract', name);

test('ok fixture passes', () => {
  const r = runGate('scripts/check_ci_contract.mjs', [fix('ok')]);
  assert.equal(r.status, 0, r.stderr || r.stdout);
  assert.match(r.stdout, /OK: CI triggers/);
});

test('missing pull_request/push trigger fails', () => {
  const r = runGate('scripts/check_ci_contract.mjs', [fix('missing-trigger')]);
  assert.equal(r.status, 1);
  assert.match(r.stderr + r.stdout, /pull_request/);
});

test('missing required job fails', () => {
  const r = runGate('scripts/check_ci_contract.mjs', [fix('missing-job')]);
  assert.equal(r.status, 1);
  assert.match(r.stderr + r.stdout, /db-aggregate/);
});

test('expired parked file fails', () => {
  const r = runGate('scripts/check_ci_contract.mjs', [fix('expired-parked')]);
  assert.equal(r.status, 1);
  assert.match(r.stderr + r.stdout, /expired/);
});
