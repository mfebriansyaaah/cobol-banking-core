// Unit tests for the contract registry gate (ADR-0006 follow-up).
// No database, no build: static checks only.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const CHECK = path.join(ROOT, 'scripts', 'check_contract.mjs');
const BUILD = path.join(ROOT, 'scripts', 'build_contract.mjs');

test('contract registry holds on the real tree', () => {
  const out = execFileSync('node', [CHECK, ROOT], { encoding: 'utf8' });
  assert.match(out, /OK: contract holds/);
});

test('contract file exists with expected shape', async () => {
  const { readFileSync, existsSync } = await import('node:fs');
  const p = path.join(ROOT, 'contracts', 'actions.yaml');
  assert.equal(existsSync(p), true);
  const src = readFileSync(p, 'utf8');
  assert.match(src, /version: 1/);
  assert.match(src, /- action: ACC_AUDIT/);
  assert.match(src, /pattern: LIMIT/);
  assert.match(src, /module: account_core/);
});

test('builder check mode passes when in sync', () => {
  const out = execFileSync('node', [BUILD, ROOT], { encoding: 'utf8' });
  assert.match(out, /OK: contract in sync/);
});

test('contract covers every route action exactly once per route', async () => {
  const { collectRouteContracts } = await import('../lib/contract.mjs');
  const actions = collectRouteContracts(ROOT);
  assert.ok(actions.length >= 570, `expected 570+ route entries, got ${actions.length}`);
  for (const a of actions) {
    assert.equal(a.fields.length, 6, `${a.action} must have 6 slots`);
    assert.ok(a.module && a.prefix, `${a.action} must resolve dispatch`);
  }
  const key = (a) => `${a.method} ${a.path} ${a.action}`;
  assert.equal(new Set(actions.map(key)).size, actions.length, 'no duplicate route entries');
});
