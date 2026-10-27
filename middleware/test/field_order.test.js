import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { ROUTES } from '../src/app.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const contract = JSON.parse(readFileSync(path.join(__dirname, 'fixtures', 'field_order_contract.json'), 'utf8'));

test('contracted actions exist in the route table', () => {
  const byAction = new Map(ROUTES.map((r) => [r.action, r]));
  for (const action of Object.keys(contract)) {
    assert.ok(byAction.has(action), `missing route for ${action}`);
  }
});

test('route field order matches the golden contract (auth + wallet/transfer)', () => {
  const byAction = new Map(ROUTES.map((r) => [r.action, r]));
  for (const [action, expected] of Object.entries(contract)) {
    const route = byAction.get(action);
    const actual = (route.fields ?? []).map((f) => f.name ?? '');
    assert.deepEqual(actual, expected, `${action}: field order drift`);
  }
});