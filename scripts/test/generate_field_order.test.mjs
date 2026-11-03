// Unit tests for scripts/generate_field_order.mjs (P1-9). No database, no build.
// Runs --write/--check against temp copies of the committed fixture repo so
// the real tests/contracts snapshot is never touched.
import { test, after } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { makeFixtureRoot, cleanupFixture, runGate } from './helpers.mjs';

const roots = [];
after(() => {
  for (const d of roots) cleanupFixture(d);
});

function snapPath(root) {
  return path.join(root, 'tests', 'contracts', 'route_field_order.json');
}

test('--write creates a snapshot with the fixture routes', () => {
  const root = makeFixtureRoot();
  roots.push(root);
  const r = runGate('scripts/generate_field_order.mjs', ['--write', root]);
  assert.equal(r.status, 0, `write failed: ${r.stderr}`);
  const snap = JSON.parse(readFileSync(snapPath(root), 'utf8'));
  const keys = Object.keys(snap);
  assert.ok(keys.some((k) => k.startsWith('account.js :: POST /accounts')), `has ACC_CREATE route, got: ${keys}`);
  assert.ok(keys.some((k) => k.startsWith('loan.js :: POST /loans')), `has LOAN_CREATE route, got: ${keys}`);
});

test('--check passes on a matching snapshot', () => {
  const root = makeFixtureRoot();
  roots.push(root);
  assert.equal(runGate('scripts/generate_field_order.mjs', ['--write', root]).status, 0);
  const r = runGate('scripts/generate_field_order.mjs', ['--check', root]);
  assert.equal(r.status, 0, `check failed: ${r.stderr}`);
  assert.match(r.stdout, /OK: \d+ route\(s\) match/);
});

test('--check fails on field-order drift with a clear message', () => {
  const root = makeFixtureRoot();
  roots.push(root);
  assert.equal(runGate('scripts/generate_field_order.mjs', ['--write', root]).status, 0);
  const routeFile = path.join(root, 'middleware', 'src', 'routes', 'loan.js');
  const src = readFileSync(routeFile, 'utf8');
  writeFileSync(routeFile, src.replace("'currency'", "'currencyCode'"));
  const r = runGate('scripts/generate_field_order.mjs', ['--check', root]);
  assert.equal(r.status, 1);
  assert.match(r.stderr, /FIELD DRIFT|field-order drift/);
});

test('--check fails when the snapshot is missing', () => {
  const root = makeFixtureRoot();
  roots.push(root);
  const r = runGate('scripts/generate_field_order.mjs', ['--check', root]);
  assert.equal(r.status, 1);
  assert.match(r.stderr, /missing snapshot/);
});


test('unknown flag exits 2 with usage', () => {
  const root = makeFixtureRoot();
  roots.push(root);
  const r = runGate('scripts/generate_field_order.mjs', ['--frobnicate', root]);
  assert.equal(r.status, 2);
  assert.match(r.stderr, /unknown argument/);
});

test('--write is idempotent: second write changes nothing', () => {
  const root = makeFixtureRoot();
  roots.push(root);
  assert.equal(runGate('scripts/generate_field_order.mjs', ['--write', root]).status, 0);
  const before = readFileSync(snapPath(root), 'utf8');
  assert.equal(runGate('scripts/generate_field_order.mjs', ['--write', root]).status, 0);
  assert.equal(readFileSync(snapPath(root), 'utf8'), before);
});
