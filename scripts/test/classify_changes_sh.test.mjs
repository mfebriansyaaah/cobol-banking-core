// Unit tests for scripts/ci/classify_changes.sh (Phase 2).
//
// The script always cds to the repo root, so git is faked via PATH: a stub
// `git` prints controlled file lists while the real
// scripts/ci/classify_changes.mjs does the classification.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync, execSync } from 'node:child_process';
import { mkdtempSync, readFileSync, writeFileSync, chmodSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';

const REPO_ROOT = path.resolve(path.dirname(new URL(import.meta.url).pathname), '..', '..');
const SCRIPT = path.join(REPO_ROOT, 'scripts', 'ci', 'classify_changes.sh');

function makeFakeGit(dir, { revOk = true, diff = '', untracked = '' } = {}) {
  const gitPath = path.join(dir, 'git');
  const body = [
    '#!/usr/bin/env bash',
    'if [ "$1" = "rev-parse" ]; then',
    `  if [ "${revOk ? '1' : '0'}" = "1" ]; then exit 0; else exit 1; fi`,
    'elif [ "$1" = "diff" ]; then',
    `  printf '%s\\n' ${JSON.stringify(diff)}`,
    'elif [ "$1" = "ls-files" ]; then',
    `  printf '%s\\n' ${JSON.stringify(untracked)}`,
    'else',
    '  exit 0',
    'fi',
    '',
  ].join('\n');
  writeFileSync(gitPath, body);
  chmodSync(gitPath, 0o755);
}

function runClassifier({
  event = 'pull_request',
  base = 'abc123',
  label = 'false',
  revOk = true,
  diff = '',
  untracked = '',
} = {}) {
  const bin = mkdtempSync(path.join(tmpdir(), 'fakebin-'));
  makeFakeGit(bin, { revOk, diff, untracked });
  const outDir = mkdtempSync(path.join(tmpdir(), 'ghout-'));
  const outFile = path.join(outDir, 'github_output');
  writeFileSync(outFile, '');
  execFileSync('bash', [SCRIPT], {
    cwd: REPO_ROOT,
    encoding: 'utf8',
    timeout: 60000,
    env: {
      ...process.env,
      PATH: `${bin}${path.delimiter}${process.env.PATH}`,
      EVENT_NAME: event,
      PR_BASE_SHA: event === 'pull_request' ? base : '',
      PUSH_BEFORE_SHA: event === 'pull_request' ? '' : base,
      HAS_CI_FULL_LABEL: label,
      GITHUB_OUTPUT: outFile,
    },
  });
  const content = readFileSync(outFile, 'utf8');
  const m = content.match(/docs_only=(true|false)/);
  assert.ok(m, `expected docs_only in GITHUB_OUTPUT, got: ${JSON.stringify(content)}`);
  return m[1];
}

test('docs-only change yields docs_only=true', () => {
  assert.equal(runClassifier({ diff: 'docs/CI.md' }), 'true');
});

test('code change yields docs_only=false', () => {
  assert.equal(runClassifier({ diff: 'middleware/src/routes/account.js' }), 'false');
});

test('ci:full label forces docs_only=false', () => {
  assert.equal(runClassifier({ diff: 'docs/CI.md', label: 'true' }), 'false');
});

test('invalid base fails safe to docs_only=false', () => {
  assert.equal(runClassifier({ diff: 'docs/CI.md', revOk: false, base: 'deadbeef' }), 'false');
});

test('untracked code file forces docs_only=false', () => {
  assert.equal(runClassifier({ diff: 'docs/CI.md', untracked: 'cobol/src/loan_core.cob' }), 'false');
});

test('push event uses PUSH_BEFORE_SHA', () => {
  execSync(`bash -n ${SCRIPT}`);
  assert.equal(runClassifier({ event: 'push', base: 'abc123', diff: 'docs/CI.md' }), 'true');
});
