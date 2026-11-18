// Unit tests for scripts/ci/check_ci_docs.mjs.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import path from 'node:path';
import { runGate, REPO_ROOT } from './helpers.mjs';

const fix = (name) => path.join(REPO_ROOT, 'tests', 'fixtures', 'ci-docs', name);

test('ok fixture passes', () => {
  const r = runGate('scripts/ci/check_ci_docs.mjs', ['--root', fix('ok')]);
  assert.equal(r.status, 0, r.stderr || r.stdout);
  assert.match(r.stdout, /OK: docs\/CI\.md matches workflows/);
});

test('missing job id fails', () => {
  const r = runGate('scripts/ci/check_ci_docs.mjs', ['--root', fix('missing-job')]);
  assert.equal(r.status, 1, r.stdout + r.stderr);
  assert.match(r.stderr + r.stdout, /my-job/);
});

test('missing display name fails', () => {
  const r = runGate('scripts/ci/check_ci_docs.mjs', ['--root', fix('missing-display')]);
  assert.equal(r.status, 1, r.stdout + r.stderr);
  assert.match(r.stderr + r.stdout, /my display/);
});

test('real tree passes', () => {
  const r = runGate('scripts/ci/check_ci_docs.mjs', ['.']);
  assert.equal(r.status, 0, r.stderr || r.stdout);
});
