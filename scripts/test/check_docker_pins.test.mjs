// Unit tests for scripts/check_docker_pins.mjs.
import { test, after } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const GATE = path.join(ROOT, 'scripts', 'check_docker_pins.mjs');

const dirs = [];
after(() => {
  for (const d of dirs) rmSync(d, { recursive: true, force: true });
});

function makeTree(froms) {
  const d = mkdtempSync(path.join(tmpdir(), 'dockerpins-'));
  dirs.push(d);
  writeFileSync(path.join(d, 'Dockerfile'), `${froms.map((f) => `FROM ${f} AS x`).join('\n')}\n`);
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

test('pinned tags pass', () => {
  const r = runGate(makeTree(['debian:bookworm-slim', 'node:24-bookworm-slim']));
  assert.equal(r.ok, true);
});

test(':latest fails', () => {
  const r = runGate(makeTree(['debian:bookworm-slim', 'quay.io/minio/minio:latest']));
  assert.equal(r.ok, false);
  assert.match(r.out, /floating tag/);
});

test('untagged image fails', () => {
  const r = runGate(makeTree(['debian']));
  assert.equal(r.ok, false);
  assert.match(r.out, /floating tag/);
});

test('missing Dockerfile fails', () => {
  const d = mkdtempSync(path.join(tmpdir(), 'dockerpins-empty-'));
  dirs.push(d);
  const r = runGate(d);
  assert.equal(r.ok, false);
  assert.match(r.out, /Dockerfile missing/);
});
