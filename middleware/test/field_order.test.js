import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { ROUTES } from '../src/app.js';
import { collectRoutes } from '../../scripts/lib/route_fields.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, '..', '..');
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

// Full-surface version of the check_field_order gate: every registered route
// must match tests/contracts/route_field_order.json exactly. The 17-action
// contract above stays as the hand-reviewed core; this one is the generated
// anti-drift net over all 5k+ routes.
test('route field order matches the committed snapshot for every route', () => {
  const snapshot = JSON.parse(readFileSync(path.join(ROOT, 'tests', 'contracts', 'route_field_order.json'), 'utf8'));
  const live = collectRoutes(ROOT);
  const liveObj = {};
  for (const [k, v] of [...live.entries()].sort(([a], [b]) => (a < b ? -1 : 1))) liveObj[k] = v;
  const liveKeys = new Set(Object.keys(liveObj));
  const snapKeys = new Set(Object.keys(snapshot));
  const missing = [...snapKeys].filter((k) => !liveKeys.has(k));
  const extra = [...liveKeys].filter((k) => !snapKeys.has(k));
  assert.deepEqual(missing, [], `snapshot entries with no live route: ${missing.slice(0, 5).join(', ')}`);
  assert.deepEqual(extra, [], `live routes with no snapshot entry: ${extra.slice(0, 5).join(', ')}`);
  const drifted = Object.keys(snapshot).filter((k) => JSON.stringify(snapshot[k]) !== JSON.stringify(liveObj[k]));
  assert.deepEqual(
    drifted.slice(0, 10),
    [],
    `${drifted.length} route(s) drifted from the snapshot (regen with scripts/generate_field_order.mjs --write after review)`,
  );
});
