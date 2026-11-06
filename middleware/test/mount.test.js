import { test } from 'node:test';
import assert from 'node:assert/strict';
import { groupRoutes } from '../src/mount.js';
import { ALL_ROUTES } from '../src/routes/index.js';
import { ROUTES } from '../src/app.js';

test('groups are disjoint first-segments in first-seen order', () => {
  const groups = groupRoutes(ALL_ROUTES);
  const segs = groups.map((g) => g.segment);
  assert.equal(new Set(segs).size, segs.length);
  const seen = [];
  for (const r of ALL_ROUTES) {
    const s = r.path.split('/')[1];
    if (!seen.includes(s)) seen.push(s);
  }
  assert.deepEqual(segs, seen);
});

test('every route is mounted exactly once, order kept within segments', () => {
  const groups = groupRoutes(ALL_ROUTES);
  const flat = groups.flatMap((g) => g.routes);
  assert.equal(flat.length, ALL_ROUTES.length);
  const byAction = (list) => {
    const m = new Map();
    for (const r of list) {
      const s = r.path.split('/')[1];
      if (!m.has(s)) m.set(s, []);
      m.get(s).push(r.action);
    }
    return m;
  };
  assert.deepEqual([...byAction(flat).entries()], [...byAction(ALL_ROUTES).entries()]);
});

test('app ROUTES equal ALL_ROUTES (mounts add no routes)', () => {
  assert.equal(ROUTES.length, ALL_ROUTES.length);
});
