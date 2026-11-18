// Unit tests for scripts/check_pii_history.mjs.
import { test, after } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const GATE = path.join(ROOT, 'scripts', 'check_pii_history.mjs');

const dirs = [];
after(() => {
  for (const d of dirs) rmSync(d, { recursive: true, force: true });
});

function git(cwd, ...args) {
  return execFileSync('git', args, { cwd, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] });
}

function makeRepo({ historyEmail = null, leak = false } = {}) {
  const d = mkdtempSync(path.join(tmpdir(), 'piihist-'));
  dirs.push(d);
  git(d, 'init', '-q');
  git(d, 'config', 'user.email', 'test@example.com');
  git(d, 'config', 'user.name', 'Test');
  git(d, 'config', 'commit.gpgsign', 'false');
  writeFileSync(path.join(d, 'code.txt'), leak ? `contact ${historyEmail}\n` : 'no contact here\n');
  const env = {
    ...process.env,
    GIT_AUTHOR_NAME: 'T',
    GIT_AUTHOR_EMAIL: historyEmail || 'test@example.com',
    GIT_COMMITTER_NAME: 'T',
    GIT_COMMITTER_EMAIL: historyEmail || 'test@example.com',
  };
  execFileSync('git', ['-C', d, 'add', 'code.txt'], { encoding: 'utf8' });
  execFileSync('git', ['-C', d, 'commit', '-qm', 'init', '--no-gpg-sign'], { encoding: 'utf8', env });
  return d;
}

function runGate(dir) {
  try {
    execFileSync(process.execPath, [GATE, dir], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] });
    return { ok: true, out: '' };
  } catch (e) {
    return { ok: false, out: String((e && e.stdout) || '') + String((e && e.stderr) || '') };
  }
}

test('clean tree passes (history address absent from files)', () => {
  const r = runGate(makeRepo({ historyEmail: 'personal.1@gmail.com' }));
  assert.equal(r.ok, true);
});

test('leaked history address fails', () => {
  const r = runGate(makeRepo({ historyEmail: 'personal.2@gmail.com', leak: true }));
  assert.equal(r.ok, false);
  assert.match(r.out, /personal\.2@gmail\.com/);
});

test('noreply-only history passes', () => {
  const r = runGate(makeRepo({ historyEmail: '1+user@users.noreply.github.com' }));
  assert.equal(r.ok, true);
});
