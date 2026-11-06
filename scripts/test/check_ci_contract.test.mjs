// Unit tests for scripts/check_ci_contract.mjs (T-006/T-011, CI-001).
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

test('renamed db aggregate display name fails (CI-001)', () => {
  const r = runGate('scripts/check_ci_contract.mjs', [fix('renamed-db-aggregate')]);
  assert.equal(r.status, 1, r.stdout + r.stderr);
  assert.match(r.stderr + r.stdout, /db aggregate/);
});

test('floating action version fails (CI-001)', () => {
  const r = runGate('scripts/check_ci_contract.mjs', [fix('floating-action')]);
  assert.equal(r.status, 1, r.stdout + r.stderr);
  assert.match(r.stderr + r.stdout, /SHA|pinned|floating/i);
});

test('missing job timeout fails (CI-001)', () => {
  const r = runGate('scripts/check_ci_contract.mjs', [fix('missing-timeout')]);
  assert.equal(r.status, 1, r.stdout + r.stderr);
  assert.match(r.stderr + r.stdout, /timeout-minutes/);
});

test('missing permissions fails (CI-001)', () => {
  const r = runGate('scripts/check_ci_contract.mjs', [fix('missing-permissions')]);
  assert.equal(r.status, 1, r.stdout + r.stderr);
  assert.match(r.stderr + r.stdout, /permissions/);
});

test('branches-ignore main fails (CI-001)', () => {
  const r = runGate('scripts/check_ci_contract.mjs', [fix('branches-ignore-main')]);
  assert.equal(r.status, 1, r.stdout + r.stderr);
  assert.match(r.stderr + r.stdout, /branches-ignore|push branches must include main/);
});

test('shard matrix mismatch fails (CI-001)', () => {
  const r = runGate('scripts/check_ci_contract.mjs', [fix('matrix-mismatch')]);
  assert.equal(r.status, 1, r.stdout + r.stderr);
  assert.match(r.stderr + r.stdout, /shard|matrix|aggregate/i);
});

test('shard matrix vs env count mismatch fails (CI-010)', () => {
  const r = runGate('scripts/check_ci_contract.mjs', [fix('matrix-env-mismatch')]);
  assert.equal(r.status, 1, r.stdout + r.stderr);
  assert.match(r.stderr + r.stdout, /matrix 3, DB_SHARD_COUNT 2, aggregate 2/);
});

test('missing coverage-pr job fails (CI-002)', () => {
  const r = runGate('scripts/check_ci_contract.mjs', [fix('missing-coverage-pr')]);
  assert.equal(r.status, 1, r.stdout + r.stderr);
  assert.match(r.stderr + r.stdout, /coverage-pr/);
});
